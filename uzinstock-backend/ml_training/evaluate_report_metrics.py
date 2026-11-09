"""Menghasilkan seluruh metrik laporan, simulasi keputusan ROP (stockout & fill rate),
dan benchmark latensi API (p50/p95/p99, throughput, error rate) untuk laporan akhir.

Jalankan:
  .venv/bin/python -m ml_training.evaluate_report_metrics
"""
import json
import math
import os
import resource
import time
from concurrent.futures import ThreadPoolExecutor

import joblib
import numpy as np
import pandas as pd
from fastapi.testclient import TestClient
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sqlalchemy import func

from app.core.config import settings
from app.db.session import SessionLocal
from app.main import app
from app.ml.features import FEATURE_COLS, build_training_frame
from app.models import Item, Transaction
from app.services.prediction_service import get_daily_demand


def smape(y_true: np.ndarray, y_pred: np.ndarray) -> float:
    denom = (np.abs(y_true) + np.abs(y_pred)) / 2.0
    mask = denom > 1e-6
    if not np.any(mask):
        return 0.0
    return float(np.mean(np.abs(y_true[mask] - y_pred[mask]) / denom[mask]) * 100.0)


def evaluate_model_and_rop_simulation():
    db = SessionLocal()
    model = joblib.load(settings.MODEL_PATH)

    train_parts, test_parts = [], []
    sim_records = []

    for item in db.query(Item).filter(Item.is_deleted.is_(False)).all():
        last = (
            db.query(func.max(Transaction.trx_date))
            .filter(Transaction.item_id == item.id, Transaction.type == "OUT")
            .scalar()
        )
        series = get_daily_demand(db, item.id, end=last)
        if len(series) < 60:
            continue
        scale = float(series.mean()) or 1.0
        norm_series = series / scale
        df = build_training_frame(norm_series, item.lead_time_days)
        cut = int(len(df) * 0.8)
        train_df = df.iloc[:cut]
        test_df = df.iloc[cut:]
        train_parts.append(train_df)
        test_parts.append(test_df)

        # Simulasi keputusan ROP pada periode uji (20% akhir tiap SKU)
        raw_test_demands = series.loc[test_df.index].values
        pred_norm = np.maximum(0.0, model.predict(test_df[FEATURE_COLS]))
        pred_daily = pred_norm * scale
        base_daily = np.maximum(0.0, test_df["roll_mean_7"].values * scale)

        sigma_train = float(series.iloc[:cut].tail(90).std(ddof=0))
        L = item.lead_time_days
        safety_rf = math.ceil(settings.SERVICE_LEVEL_Z * sigma_train * math.sqrt(L))

        def simulate_policy(daily_forecasts, safety_stock_val):
            # Mulai dengan stok sebesar ROP awal
            order_qty = max(1.0, math.ceil(float(series.iloc[:cut].mean()) * L * 2))
            init_rop = math.ceil((daily_forecasts[0] if len(daily_forecasts) else 0) * L + safety_stock_val)
            inv = float(max(init_rop + order_qty * 0.5, scale * L))
            pending_orders = []  # list of (arrival_day_idx, qty)
            stockout_days = 0
            total_demand = 0.0
            fulfilled_demand = 0.0

            for t_idx, actual_d in enumerate(raw_test_demands):
                # Terima pesanan yang tiba hari ini
                arrived = sum(q for arr_t, q in pending_orders if arr_t == t_idx)
                inv += arrived
                pending_orders = [(arr_t, q) for arr_t, q in pending_orders if arr_t > t_idx]

                # Penuhi permintaan hari ini
                total_demand += actual_d
                if inv >= actual_d:
                    fulfilled_demand += actual_d
                    inv -= actual_d
                else:
                    fulfilled_demand += max(0.0, inv)
                    inv = 0.0
                    stockout_days += 1

                # Cek apakah perlu pesan ulang (jika belum ada pesanan on-order)
                rop_t = math.ceil(daily_forecasts[t_idx] * L + safety_stock_val)
                on_order = sum(q for _, q in pending_orders)
                if inv + on_order <= rop_t:
                    q_order = max(order_qty, rop_t * 1.5 - (inv + on_order))
                    pending_orders.append((t_idx + L, math.ceil(q_order)))

            return stockout_days, total_demand, fulfilled_demand, len(raw_test_demands)

        so_rf, dem_rf, ful_rf, n_days = simulate_policy(pred_daily, safety_rf)
        so_base, dem_base, ful_base, _ = simulate_policy(base_daily, 0)
        sim_records.append(
            {
                "sku": item.sku,
                "days": n_days,
                "rf_stockout_days": so_rf,
                "rf_demand": dem_rf,
                "rf_fulfilled": ful_rf,
                "base_stockout_days": so_base,
                "base_demand": dem_base,
                "base_fulfilled": ful_base,
            }
        )

    db.close()

    train = pd.concat(train_parts)
    test = pd.concat(test_parts)

    y_train = train["target"].values
    pred_train = model.predict(train[FEATURE_COLS])
    residuals_train = y_train - pred_train
    sigma_residual = float(np.std(residuals_train, ddof=1))

    y_test = test["target"].values
    pred_test = model.predict(test[FEATURE_COLS])
    base_test = test["roll_mean_7"].values

    # Cakupan rentang prediksi (prediction interval coverage) dengan +- 1.28 * sigma_residual (80%) dan +- 1.65 * sigma_residual (90%)
    cov_80 = float(np.mean((y_test >= pred_test - 1.2816 * sigma_residual) & (y_test <= pred_test + 1.2816 * sigma_residual)) * 100.0)
    cov_90 = float(np.mean((y_test >= pred_test - 1.6449 * sigma_residual) & (y_test <= pred_test + 1.6449 * sigma_residual)) * 100.0)

    total_test_days = sum(r["days"] for r in sim_records)
    rf_stockouts = sum(r["rf_stockout_days"] for r in sim_records)
    base_stockouts = sum(r["base_stockout_days"] for r in sim_records)
    rf_fill_rate = (sum(r["rf_fulfilled"] for r in sim_records) / max(1.0, sum(r["rf_demand"] for r in sim_records))) * 100.0
    base_fill_rate = (sum(r["base_fulfilled"] for r in sim_records) / max(1.0, sum(r["base_demand"] for r in sim_records))) * 100.0

    return {
        "n_skus_modeled": len(sim_records),
        "n_train": int(len(train)),
        "n_test": int(len(test)),
        "sigma_residual": round(sigma_residual, 4),
        "hyperparameters": {
            "n_estimators": 300,
            "max_depth": 5,
            "min_samples_leaf": 25,
            "random_state": 42,
            "service_level_z": settings.SERVICE_LEVEL_Z,
        },
        "metrics_rf": {
            "MAE": round(float(mean_absolute_error(y_test, pred_test)), 4),
            "RMSE": round(float(np.sqrt(mean_squared_error(y_test, pred_test))), 4),
            "sMAPE_pct": round(smape(y_test, pred_test), 2),
            "R2": round(float(r2_score(y_test, pred_test)), 4),
            "coverage_80_pct": round(cov_80, 2),
            "coverage_90_pct": round(cov_90, 2),
        },
        "metrics_baseline_ma7": {
            "MAE": round(float(mean_absolute_error(y_test, base_test)), 4),
            "RMSE": round(float(np.sqrt(mean_squared_error(y_test, base_test))), 4),
            "sMAPE_pct": round(smape(y_test, base_test), 2),
            "R2": round(float(r2_score(y_test, base_test)), 4),
        },
        "rop_simulation": {
            "total_sku_test_days": total_test_days,
            "rf_with_safety_stock": {
                "stockout_days": rf_stockouts,
                "stockout_rate_pct": round(rf_stockouts / total_test_days * 100.0, 2),
                "fill_rate_pct": round(rf_fill_rate, 2),
            },
            "baseline_ma7_no_safety": {
                "stockout_days": base_stockouts,
                "stockout_rate_pct": round(base_stockouts / total_test_days * 100.0, 2),
                "fill_rate_pct": round(base_fill_rate, 2),
            },
        },
    }


def benchmark_api_latency():
    with TestClient(app) as c:
        r_login = c.post("/api/v1/auth/login", data={"username": "admin", "password": "admin123"})
        headers = {"Authorization": f"Bearer {r_login.json()['access_token']}"}
        items = c.get("/api/v1/items", headers=headers).json()
        sample_id = items[0]["id"]

        scenarios = [
            ("GET /health", lambda: c.get("/health")),
            ("GET /api/v1/items", lambda: c.get("/api/v1/items", headers=headers)),
            ("GET /api/v1/transactions", lambda: c.get("/api/v1/transactions?limit=100", headers=headers)),
            ("GET /api/v1/predictions/latest", lambda: c.get("/api/v1/predictions/latest", headers=headers)),
            (
                f"POST /api/v1/predictions/reorder-point/{sample_id}",
                lambda: c.post(f"/api/v1/predictions/reorder-point/{sample_id}", headers=headers),
            ),
        ]

        results = {}
        all_latencies = []
        total_errors = 0
        total_reqs = 0
        t_start_all = time.perf_counter()

        for label, fn in scenarios:
            n_iter = 60 if "POST" not in label else 30
            latencies = []
            errors = 0
            t0 = time.perf_counter()
            for _ in range(n_iter):
                s = time.perf_counter()
                resp = fn()
                el_ms = (time.perf_counter() - s) * 1000.0
                latencies.append(el_ms)
                if resp.status_code >= 400:
                    errors += 1
            elapsed = time.perf_counter() - t0
            arr = np.array(latencies)
            all_latencies.extend(latencies)
            total_errors += errors
            total_reqs += n_iter
            results[label] = {
                "requests": n_iter,
                "p50_ms": round(float(np.percentile(arr, 50)), 2),
                "p95_ms": round(float(np.percentile(arr, 95)), 2),
                "p99_ms": round(float(np.percentile(arr, 99)), 2),
                "mean_ms": round(float(np.mean(arr)), 2),
                "throughput_rps": round(n_iter / elapsed, 2),
                "error_rate_pct": round(errors / n_iter * 100.0, 2),
            }

        # Uji beban konkuren (10 worker paralel x 100 request campuran)
        def _worker(i: int):
            s = time.perf_counter()
            if i % 5 == 0:
                resp = c.post(f"/api/v1/predictions/reorder-point/{sample_id}", headers=headers)
            elif i % 2 == 0:
                resp = c.get("/api/v1/items", headers=headers)
            else:
                resp = c.get("/api/v1/predictions/latest", headers=headers)
            return (time.perf_counter() - s) * 1000.0, resp.status_code

        t_conc_start = time.perf_counter()
        with ThreadPoolExecutor(max_workers=10) as ex:
            conc_out = list(ex.map(_worker, range(100)))
        t_conc_elapsed = time.perf_counter() - t_conc_start
        conc_lat = np.array([x[0] for x in conc_out])
        conc_err = sum(1 for _, code in conc_out if code >= 400)

        total_elapsed = time.perf_counter() - t_start_all
        # macOS ru_maxrss is in bytes
        rss_mb = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / (1024 * 1024), 2)

        all_arr = np.array(all_latencies)
        return {
            "per_endpoint": results,
            "overall_sequential": {
                "total_requests": total_reqs,
                "p50_ms": round(float(np.percentile(all_arr, 50)), 2),
                "p95_ms": round(float(np.percentile(all_arr, 95)), 2),
                "p99_ms": round(float(np.percentile(all_arr, 99)), 2),
                "throughput_rps": round(total_reqs / total_elapsed, 2),
                "error_rate_pct": round(total_errors / total_reqs * 100.0, 2),
            },
            "concurrent_stress_10_workers": {
                "total_requests": 100,
                "p50_ms": round(float(np.percentile(conc_lat, 50)), 2),
                "p95_ms": round(float(np.percentile(conc_lat, 95)), 2),
                "p99_ms": round(float(np.percentile(conc_lat, 99)), 2),
                "throughput_rps": round(100.0 / t_conc_elapsed, 2),
                "error_rate_pct": round(conc_err / 100.0 * 100.0, 2),
                "peak_memory_mb": rss_mb,
            },
        }


def main():
    eval_data = evaluate_model_and_rop_simulation()
    bench_data = benchmark_api_latency()
    full_report = {
        "model_and_simulation": eval_data,
        "latency_and_stress_test": bench_data,
    }
    artifact_dir = os.path.dirname(settings.MODEL_PATH)
    meta_path = settings.MODEL_PATH.replace(".joblib", ".meta.json")
    report_path = os.path.join(artifact_dir, "report_evaluation.json")

    with open(meta_path, "w") as f:
        json.dump(eval_data, f, indent=2)
    with open(report_path, "w") as f:
        json.dump(full_report, f, indent=2)

    print(json.dumps(full_report, indent=2))


if __name__ == "__main__":
    main()

