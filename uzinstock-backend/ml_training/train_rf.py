"""Training Random Forest Regressor (prediksi permintaan harian) dari data transaksi OUT.
Jalankan: python -m ml_training.train_rf
Evaluasi memakai split kronologis (bukan random) + pembanding baseline moving average 7 hari."""
import json
import os

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

from app import models  # noqa: F401
from app.core.config import settings
from app.db.session import SessionLocal
from app.ml.features import FEATURE_COLS, build_training_frame
from app.models import Item, Transaction
from app.services.prediction_service import get_daily_demand
from sqlalchemy import func


def main():
    db = SessionLocal()
    train_parts, test_parts = [], []
    for item in db.query(Item).filter(Item.is_deleted.is_(False)).all():
        last = db.query(func.max(Transaction.trx_date)).filter(
            Transaction.item_id == item.id, Transaction.type == "OUT").scalar()
        series = get_daily_demand(db, item.id, end=last)  # berhenti di OUT terakhir (data historis)
        if len(series) < 60:
            continue
        series = series / (float(series.mean()) or 1.0)  # normalisasi per barang (satuan berbeda-beda)
        df = build_training_frame(series, item.lead_time_days)
        cut = int(len(df) * 0.8)
        train_parts.append(df.iloc[:cut])
        test_parts.append(df.iloc[cut:])
    if not train_parts:
        raise SystemExit("Data transaksi OUT belum cukup. Jalankan seed_demo atau impor data historis.")

    train, test = pd.concat(train_parts), pd.concat(test_parts)
    model = RandomForestRegressor(
        n_estimators=300, max_depth=12, min_samples_leaf=3, random_state=42, n_jobs=-1
    )
    model.fit(train[FEATURE_COLS], train["target"])

    pred = model.predict(test[FEATURE_COLS])
    base = test["roll_mean_7"].values  # baseline moving average 7 hari
    y = test["target"].values
    metrics = {
        "n_train": int(len(train)),
        "n_test": int(len(test)),
        "rf": {
            "MAE": float(mean_absolute_error(y, pred)),
            "RMSE": float(np.sqrt(mean_squared_error(y, pred))),
            "R2": float(r2_score(y, pred)),
        },
        "baseline_ma7": {
            "MAE": float(mean_absolute_error(y, base)),
            "RMSE": float(np.sqrt(mean_squared_error(y, base))),
            "R2": float(r2_score(y, base)),
        },
        "feature_importance": dict(zip(FEATURE_COLS, map(float, model.feature_importances_))),
    }
    os.makedirs(os.path.dirname(settings.MODEL_PATH), exist_ok=True)
    joblib.dump(model, settings.MODEL_PATH)
    with open(settings.MODEL_PATH.replace(".joblib", "_metrics.json"), "w") as f:
        json.dump(metrics, f, indent=2)
    print(json.dumps(metrics, indent=2))
    print(f"Model disimpan: {settings.MODEL_PATH}")


if __name__ == "__main__":
    main()
