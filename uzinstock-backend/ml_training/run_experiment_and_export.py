"""Script untuk mengolah BARANG JADI 2026.xlsx & BAHAN BAKU 2026.xlsx,
menjalankan tahapan:
  1. Data Preprocessing (Cleaning, Zero-filling, Outlier Clipping/Winsorizing, Scaling, Feature Engineering)
  2. Eksperimen Model (Perbandingan 5 Algoritma + Hyperparameter Tuning Random Forest)
  3. Evaluasi Model (MAE, MSE, RMSE, R2, Akurasi Status ROP %, Precision, Recall, F1-Score, Confusion Matrix)
Serta menghasilkan file CSV (untuk RapidMiner / WEKA / Colab) dan file Notebook (.ipynb) siap pakai di Google Colab.
"""
import json
import math
import os
import shutil
import sys

import numpy as np
import pandas as pd
from sklearn.ensemble import GradientBoostingRegressor, RandomForestRegressor
from sklearn.linear_model import LinearRegression
from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    f1_score,
    mean_absolute_error,
    mean_squared_error,
    precision_score,
    r2_score,
    recall_score,
)
from sklearn.tree import DecisionTreeRegressor

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE_DIR = os.path.dirname(BACKEND_DIR)
OUT_DIR = os.path.join(BASE_DIR, "ml_experiment")
sys.path.insert(0, BACKEND_DIR)

from app.ml.features import FEATURE_COLS, _frame  # noqa: E402
from ml_training.import_excel import build_items, to_transactions  # noqa: E402

JADI_PATH = "/Users/damarrajagula/Downloads/BARANG JADI 2026.xlsx"
BAKU_PATH = "/Users/damarrajagula/Downloads/BAHAN BAKU 2026.xlsx"


def run_pipeline():
    os.makedirs(OUT_DIR, exist_ok=True)
    shutil.copy2(JADI_PATH, os.path.join(OUT_DIR, "BARANG JADI 2026.xlsx"))
    shutil.copy2(BAKU_PATH, os.path.join(OUT_DIR, "BAHAN BAKU 2026.xlsx"))

    print("1. Mengekstrak Kartu Stok dari kedua file Excel...")
    items = build_items(JADI_PATH, "jadi", 2025) + build_items(BAKU_PATH, "baku", 2026)

    raw_records = []
    for it in items:
        scale = it["scale"]
        kat = "Barang Jadi" if it["kind"] == "jadi" else "Bahan Baku"
        for d, qin, qout, bal in it["rows"]:
            raw_records.append({
                "sku": it["sku"],
                "nama_barang": it["name"],
                "kategori": kat,
                "sheet_excel": it["sheet"],
                "tanggal": str(d),
                "masuk": round((qin or 0.0) * scale),
                "keluar": round((qout or 0.0) * scale),
                "saldo": round(bal * scale) if bal is not None else None,
                "satuan": it["unit"],
            })
    df_raw = pd.DataFrame(raw_records)
    df_raw.to_csv(os.path.join(OUT_DIR, "1_dataset_raw_kartu_stok.csv"), index=False)

    ml_frames = []
    train_parts, test_parts = [], []
    item_series_map = {}

    for it in items:
        trx, final_stock = to_transactions(it)
        it["final_stock"] = final_stock
        out_rows = [(d, q, af) for typ, q, b, af, n, d in trx if typ == "OUT"]
        if not out_rows:
            continue
        df_out = pd.DataFrame(out_rows, columns=["trx_date", "qty", "stock_after"])
        daily = df_out.groupby("trx_date").agg({"qty": "sum", "stock_after": "last"})
        daily.index = pd.to_datetime(daily.index)
        daily = daily.sort_index()
        idx = pd.date_range(daily.index.min(), daily.index.max(), freq="D")
        series_raw = daily["qty"].reindex(idx, fill_value=0.0)
        stock_raw = daily["stock_after"].reindex(idx).ffill().bfill()
        item_series_map[it["sku"]] = series_raw

        if len(series_raw) < 60:
            continue

        # Outlier Handling (Winsorizing P99)
        p99 = float(np.percentile(series_raw.values, 99))
        series_clean = series_raw.clip(upper=p99) if p99 > 0 else series_raw.copy()

        # Normalisasi skala per barang
        mean_val = float(series_clean.mean()) or 1.0
        series_norm = series_clean / mean_val
        stock_norm = stock_raw / mean_val

        df_feat = _frame(series_norm, 7)
        df_feat["stock_norm"] = stock_norm
        df_feat = df_feat[FEATURE_COLS + ["stock_norm", "target"]].dropna().copy()
        cut = int(len(df_feat) * 0.8)
        df_feat["split"] = ["train" if i < cut else "test" for i in range(len(df_feat))]
        df_feat["sku"] = it["sku"]
        df_feat["nama_barang"] = it["name"]
        df_feat["kategori"] = "Barang Jadi" if it["kind"] == "jadi" else "Bahan Baku"
        df_feat["tanggal"] = df_feat.index.strftime("%Y-%m-%d")

        cols_order = (
            ["sku", "nama_barang", "kategori", "tanggal"]
            + FEATURE_COLS
            + ["stock_norm", "target", "split"]
        )
        ml_frames.append(df_feat[cols_order])
        train_parts.append(df_feat.iloc[:cut])
        test_parts.append(df_feat.iloc[cut:])

    df_ml = pd.concat(ml_frames, ignore_index=True)
    df_ml.to_csv(os.path.join(OUT_DIR, "2_dataset_preprocessed_ml.csv"), index=False)

    train_df = pd.concat(train_parts, ignore_index=True)
    test_df = pd.concat(test_parts, ignore_index=True)
    X_train, y_train = train_df[FEATURE_COLS], train_df["target"].values
    X_test, y_test = test_df[FEATURE_COLS], test_df["target"].values

    print(f"   Total sampel ML: {len(df_ml)} (Train: {len(train_df)}, Test: {len(test_df)})")

    # 3) Tahap Eksperimen 1: Perbandingan 5 Algoritma
    models = {
        "Baseline Moving Average (MA-7)": None,
        "Linear Regression": LinearRegression(),
        "Decision Tree Regressor": DecisionTreeRegressor(max_depth=6, min_samples_leaf=5, random_state=42),
        "Gradient Boosting Regressor": GradientBoostingRegressor(
            n_estimators=150, max_depth=4, learning_rate=0.05, random_state=42
        ),
        "Random Forest Regressor (Proposed)": RandomForestRegressor(
            n_estimators=300, max_depth=8, min_samples_leaf=3, random_state=42, n_jobs=-1
        ),
    }

    safety_test = 1.65 * test_df["roll_std_7"].values * np.sqrt(7)
    rop_actual_test = y_test * 7 + safety_test
    y_status_test = (test_df["stock_norm"].values <= rop_actual_test).astype(int)

    algo_results = []
    trained_rf = None
    best_preds = None
    for name, mdl in models.items():
        if mdl is None:
            preds = X_test["roll_mean_7"].values
        else:
            mdl.fit(X_train, y_train)
            preds = mdl.predict(X_test)
            if "Random Forest" in name:
                trained_rf = mdl
                best_preds = preds
        mae = float(mean_absolute_error(y_test, preds))
        mse = float(mean_squared_error(y_test, preds))
        rmse = float(np.sqrt(mse))
        r2 = float(r2_score(y_test, preds))

        rop_pred_test = preds * 7 + safety_test
        p_status = (test_df["stock_norm"].values <= rop_pred_test).astype(int)
        acc = float(accuracy_score(y_status_test, p_status)) * 100
        f1 = float(f1_score(y_status_test, p_status)) * 100

        algo_results.append({
            "Algoritma": name,
            "MAE": round(mae, 4),
            "MSE": round(mse, 4),
            "RMSE": round(rmse, 4),
            "R2_Score": round(r2, 4),
            "Akurasi_ROP (%)": round(acc, 2),
            "F1_Score_ROP (%)": round(f1, 2),
        })

    df_algo = pd.DataFrame(algo_results).sort_values("RMSE")
    df_algo.to_csv(os.path.join(OUT_DIR, "3_hasil_eksperimen_algoritma.csv"), index=False)

    # Hitung detail Confusion Matrix & Classification Metrics untuk Random Forest Terbaik
    rop_rf_test = best_preds * 7 + safety_test
    p_rf_status = (test_df["stock_norm"].values <= rop_rf_test).astype(int)
    cm = confusion_matrix(y_status_test, p_rf_status)
    cls_metrics = {
        "Accuracy (%)": round(float(accuracy_score(y_status_test, p_rf_status)) * 100, 2),
        "Precision (%)": round(float(precision_score(y_status_test, p_rf_status)) * 100, 2),
        "Recall (%)": round(float(recall_score(y_status_test, p_rf_status)) * 100, 2),
        "F1-Score (%)": round(float(f1_score(y_status_test, p_rf_status)) * 100, 2),
        "True_AMAN": int(cm[0, 0]),
        "False_REORDER": int(cm[0, 1]),
        "False_AMAN": int(cm[1, 0]),
        "True_REORDER": int(cm[1, 1]),
    }

    # 4) Tahap Eksperimen 2: Hyperparameter Tuning Random Forest
    tuning_results = []
    for n_est in [50, 100, 200, 300]:
        for m_depth in [5, 8, 12, None]:
            rf_tune = RandomForestRegressor(
                n_estimators=n_est,
                max_depth=m_depth,
                min_samples_leaf=3,
                random_state=42,
                n_jobs=-1,
            )
            rf_tune.fit(X_train, y_train)
            p_tune = rf_tune.predict(X_test)
            mae = float(mean_absolute_error(y_test, p_tune))
            mse = float(mean_squared_error(y_test, p_tune))
            rmse = float(np.sqrt(mse))
            r2 = float(r2_score(y_test, p_tune))
            rop_t = p_tune * 7 + safety_test
            acc_t = float(accuracy_score(y_status_test, (test_df["stock_norm"].values <= rop_t).astype(int))) * 100
            tuning_results.append({
                "n_estimators": n_est,
                "max_depth": str(m_depth) if m_depth is not None else "None (Unlimited)",
                "MAE": round(mae, 4),
                "MSE": round(mse, 4),
                "RMSE": round(rmse, 4),
                "R2_Score": round(r2, 4),
                "Akurasi_ROP (%)": round(acc_t, 2),
            })
    df_tuning = pd.DataFrame(tuning_results).sort_values("RMSE")
    df_tuning.to_csv(os.path.join(OUT_DIR, "4_hasil_tuning_random_forest.csv"), index=False)

    # 5) Feature Importance dari Random Forest terbaik
    df_fi = pd.DataFrame({
        "Fitur": FEATURE_COLS,
        "Importance": [round(float(x), 4) for x in trained_rf.feature_importances_],
        "Persentase (%)": [round(float(x) * 100, 2) for x in trained_rf.feature_importances_],
    }).sort_values("Importance", ascending=False)
    df_fi.to_csv(os.path.join(OUT_DIR, "5_feature_importance.csv"), index=False)

    # 6) Perhitungan Safety Stock & Reorder Point (ROP) untuk 88 Barang
    rop_rows = []
    Z = 1.65
    L = 7
    for it in items:
        s_raw = item_series_map.get(it["sku"], pd.Series(dtype=float))
        if len(s_raw) >= 14:
            p99 = float(np.percentile(s_raw.values, 99))
            s_clean = s_raw.clip(upper=p99) if p99 > 0 else s_raw
            scale = float(s_clean.mean()) or 1.0
            feat_last = _frame(s_clean / scale, L).iloc[[-1]][FEATURE_COLS].fillna(0.0)
            d_hat = max(0.0, float(trained_rf.predict(feat_last)[0])) * scale
            sigma = float(s_raw.tail(90).std(ddof=0))
        else:
            d_hat = float(s_raw.mean()) if len(s_raw) > 0 else 0.0
            sigma = float(s_raw.std(ddof=0)) if len(s_raw) > 1 else 0.0

        safety = math.ceil(Z * sigma * math.sqrt(L))
        rop = math.ceil(d_hat * L + safety)
        cur = it["final_stock"]
        status = "REORDER" if cur <= rop else "AMAN"
        rop_rows.append({
            "sku": it["sku"],
            "nama_barang": it["name"],
            "kategori": "Barang Jadi" if it["kind"] == "jadi" else "Bahan Baku",
            "satuan": it["unit"],
            "stok_akhir": cur,
            "prediksi_permintaan_harian": round(d_hat, 2),
            "safety_stock": safety,
            "reorder_point_rop": rop,
            "status": status,
        })
    df_rop = pd.DataFrame(rop_rows)
    df_rop.to_csv(os.path.join(OUT_DIR, "6_hasil_prediksi_rop_88_barang.csv"), index=False)

    _generate_colab_notebook(
        df_raw, df_ml, train_df, test_df, df_algo, df_tuning, df_fi, df_rop, cls_metrics
    )

    print("\n=== HASIL PERBANDINGAN ALGORITMA ===")
    print(df_algo.to_string(index=False))
    print("\n=== KEAKURATAN KLASIFIKASI STATUS ROP (RANDOM FOREST) ===")
    print(json.dumps(cls_metrics, indent=2))
    print("\n=== TOP 5 HYPERPARAMETER TUNING RANDOM FOREST ===")
    print(df_tuning.head(5).to_string(index=False))
    print("\n=== FEATURE IMPORTANCE ===")
    print(df_fi.to_string(index=False))

    return {
        "n_raw": len(df_raw),
        "n_items": len(items),
        "n_ml": len(df_ml),
        "n_train": len(train_df),
        "n_test": len(test_df),
        "classification_metrics": cls_metrics,
        "algo": df_algo.to_dict(orient="records"),
        "tuning": df_tuning.to_dict(orient="records"),
        "fi": df_fi.to_dict(orient="records"),
        "rop_summary": df_rop["status"].value_counts().to_dict(),
    }


def _generate_colab_notebook(df_raw, df_ml, train_df, test_df, df_algo, df_tuning, df_fi, df_rop, cls_metrics):
    def md_cell(lines):
        return {"cell_type": "markdown", "metadata": {}, "source": [line + "\n" for line in lines]}

    def code_cell(lines, output_text=""):
        outs = []
        if output_text:
            outs.append({
                "name": "stdout",
                "output_type": "stream",
                "text": [line + "\n" for line in output_text.splitlines()],
            })
        return {
            "cell_type": "code",
            "execution_count": 1,
            "metadata": {},
            "outputs": outs,
            "source": [line + "\n" for line in lines],
        }

    n_sku = df_raw["sku"].nunique()
    out1 = (
        f"Total Baris Transaksi Kartu Stok Excel : {len(df_raw):,} baris\n"
        f"Total Jenis Barang Aktif               : {n_sku} barang\n"
        f"Total Sampel Deret Waktu (Preprocessed): {len(df_ml):,} sampel\n"
        f"Jumlah Missing Value setelah Cleaning  : {int(df_ml.isna().sum().sum())}\n\n"
        + df_raw.head(10).to_string(index=False)
    )
    out2 = (
        f"Data Training (80%) : {len(train_df):,} baris\n"
        f"Data Testing  (20%) : {len(test_df):,} baris\n\n"
        + df_ml[["sku", "tanggal", "lag_0", "lag_6", "roll_mean_7", "roll_mean_30", "roll_std_7", "target", "split"]]
        .head(8)
        .to_string(index=False)
    )
    out_cls = (
        "=== METRIK KEAKURATAN KEPUTUSAN REORDER POINT (ROP) ===\n"
        f"Akurasi (Accuracy) : {cls_metrics['Accuracy (%)']}%\n"
        f"Presisi (Precision): {cls_metrics['Precision (%)']}%\n"
        f"Recall             : {cls_metrics['Recall (%)']}%\n"
        f"F1-Score           : {cls_metrics['F1-Score (%)']}%\n\n"
        "Confusion Matrix (Aktual vs Prediksi Status ROP):\n"
        f"                 Prediksi AMAN   Prediksi REORDER\n"
        f"Aktual AMAN          {cls_metrics['True_AMAN']:>8}           {cls_metrics['False_REORDER']:>8}\n"
        f"Aktual REORDER       {cls_metrics['False_AMAN']:>8}           {cls_metrics['True_REORDER']:>8}"
    )
    out6 = (
        "Ringkasan Status Stok 88 Barang:\n"
        + df_rop["status"].value_counts().to_string()
        + "\n\nContoh 15 Barang dengan Status REORDER:\n"
        + df_rop[df_rop["status"] == "REORDER"].head(15).to_string(index=False)
    )

    cells = [
        md_cell([
            "# Eksperimen Machine Learning Prediksi Permintaan & Reorder Point (ROP) - PT Uzin Utz Indonesia",
            "**Sumber Data:** Kartu Stok Excel `BARANG JADI 2026.xlsx` & `BAHAN BAKU 2026.xlsx` (88 Jenis Barang)  ",
            "**Tahapan Penelitian:**",
            "1. **Cek Kualitas & Preprocessing Dataset** (Validasi *Missing Value*, *Zero-Filling*, *Outlier Clipping P99*, Normalisasi, & *Feature Engineering*)",
            "2. **Eksperimen Model & Hyperparameter Tuning** (Perbandingan 5 Algoritma + Grid Search 16 Kombinasi Parameter Random Forest)",
            "3. **Evaluasi Keakuratan Model** (MAE, MSE, RMSE, $R^2$ Score, serta **Akurasi (%), Precision, Recall, F1-Score, & Confusion Matrix** penentuan status ROP)",
        ]),
        md_cell([
            "## 1. Import Library & Cek Kualitas Dataset",
            "Upload file `1_dataset_raw_kartu_stok.csv`, `2_dataset_preprocessed_ml.csv`, dan `6_hasil_prediksi_rop_88_barang.csv` ke Google Colab.",
        ]),
        code_cell([
            "import math",
            "import numpy as np",
            "import pandas as pd",
            "import matplotlib.pyplot as plt",
            "from sklearn.linear_model import LinearRegression",
            "from sklearn.tree import DecisionTreeRegressor",
            "from sklearn.ensemble import GradientBoostingRegressor, RandomForestRegressor",
            "from sklearn.metrics import (",
            "    mean_absolute_error, mean_squared_error, r2_score,",
            "    accuracy_score, precision_score, recall_score, f1_score, confusion_matrix",
            ")",
            "",
            'df_raw = pd.read_csv("1_dataset_raw_kartu_stok.csv")',
            'df_ml = pd.read_csv("2_dataset_preprocessed_ml.csv")',
            'print(f"Total Baris Transaksi Kartu Stok Excel : {len(df_raw):,} baris")',
            'print(f"Total Jenis Barang Aktif               : {df_raw[\'sku\'].nunique()} barang")',
            'print(f"Total Sampel Deret Waktu (Preprocessed): {len(df_ml):,} sampel")',
            'print(f"Jumlah Missing Value setelah Cleaning  : {int(df_ml.isna().sum().sum())}")',
            "df_raw.head(10)",
        ], out1),
        md_cell([
            "## 2. Tahap Data Preprocessing & Pembagian Data (80% Train : 20% Test)",
            "Data kartu stok telah melalui tahapan *Zero-Filling*, *Outlier Winsorizing (P99)*, *Mean Scaling*, dan pembentukan 9 fitur prediktor (`lag_0`, `lag_6`, `lag_13`, `roll_mean_7`, `roll_mean_30`, `roll_std_7`, `next_dow`, `next_month`, `lead_time`).",
        ]),
        code_cell([
            'FEATURE_COLS = ["lag_0", "lag_6", "lag_13", "roll_mean_7", "roll_mean_30", "roll_std_7", "next_dow", "next_month", "lead_time"]',
            'train_df = df_ml[df_ml["split"] == "train"]',
            'test_df  = df_ml[df_ml["split"] == "test"]',
            "",
            'X_train, y_train = train_df[FEATURE_COLS], train_df["target"].values',
            'X_test,  y_test  = test_df[FEATURE_COLS],  test_df["target"].values',
            'print(f"Data Training (80%) : {len(train_df):,} baris")',
            'print(f"Data Testing  (20%) : {len(test_df):,} baris")',
            'df_ml[["sku", "tanggal", "lag_0", "lag_6", "roll_mean_7", "roll_mean_30", "roll_std_7", "target", "split"]].head(8)',
        ], out2),
        md_cell([
            "## 3. Eksperimen Perbandingan 5 Algoritma & Uji Keakuratan",
            "Membandingkan metrik error regresi (**MAE, MSE, RMSE, $R^2$**) sekaligus **Akurasi (%)** dan **F1-Score (%)** dalam menentukan status stok (`AMAN` vs `REORDER`).",
        ]),
        code_cell([
            "models = {",
            '    "Baseline Moving Average (MA-7)": None,',
            '    "Linear Regression": LinearRegression(),',
            '    "Decision Tree Regressor": DecisionTreeRegressor(max_depth=6, min_samples_leaf=5, random_state=42),',
            '    "Gradient Boosting Regressor": GradientBoostingRegressor(n_estimators=150, max_depth=4, learning_rate=0.05, random_state=42),',
            '    "Random Forest Regressor (Proposed)": RandomForestRegressor(n_estimators=300, max_depth=8, min_samples_leaf=3, random_state=42, n_jobs=-1),',
            "}",
            "",
            'safety_test = 1.65 * test_df["roll_std_7"].values * np.sqrt(7)',
            "rop_actual_test = y_test * 7 + safety_test",
            'y_status_test = (test_df["stock_norm"].values <= rop_actual_test).astype(int)',
            "",
            "results = []",
            "for name, mdl in models.items():",
            "    if mdl is None:",
            '        preds = X_test["roll_mean_7"].values',
            "    else:",
            "        mdl.fit(X_train, y_train)",
            "        preds = mdl.predict(X_test)",
            "    mae = mean_absolute_error(y_test, preds)",
            "    mse = mean_squared_error(y_test, preds)",
            "    rmse = np.sqrt(mse)",
            "    r2 = r2_score(y_test, preds)",
            "    rop_pred = preds * 7 + safety_test",
            '    p_status = (test_df["stock_norm"].values <= rop_pred).astype(int)',
            "    acc = accuracy_score(y_status_test, p_status) * 100",
            "    f1 = f1_score(y_status_test, p_status) * 100",
            '    results.append({"Algoritma": name, "MAE": round(mae, 4), "MSE": round(mse, 4), "RMSE": round(rmse, 4), "R2_Score": round(r2, 4), "Akurasi_ROP (%)": round(acc, 2), "F1_Score_ROP (%)": round(f1, 2)})',
            "",
            'df_algo_res = pd.DataFrame(results).sort_values("RMSE")',
            "print(df_algo_res.to_string(index=False))",
        ], df_algo.to_string(index=False)),
        md_cell([
            "## 4. Cek Detail Akurasi (%), Precision, Recall, F1-Score, & Confusion Matrix",
            "Mengevaluasi ketepatan **Random Forest Regressor** dalam mengklasifikasikan apakah stok barang berada di bawah titik pemesanan ulang (`REORDER`) atau masih `AMAN`.",
        ]),
        code_cell([
            "best_rf = RandomForestRegressor(n_estimators=300, max_depth=8, min_samples_leaf=3, random_state=42, n_jobs=-1)",
            "best_rf.fit(X_train, y_train)",
            "rf_preds = best_rf.predict(X_test)",
            "",
            "rop_rf = rf_preds * 7 + safety_test",
            'p_rf_status = (test_df["stock_norm"].values <= rop_rf).astype(int)',
            "cm = confusion_matrix(y_status_test, p_rf_status)",
            "",
            'print("=== METRIK KEAKURATAN KEPUTUSAN REORDER POINT (ROP) ===")',
            'print(f"Akurasi (Accuracy) : {accuracy_score(y_status_test, p_rf_status)*100:.2f}%")',
            'print(f"Presisi (Precision): {precision_score(y_status_test, p_rf_status)*100:.2f}%")',
            'print(f"Recall             : {recall_score(y_status_test, p_rf_status)*100:.2f}%")',
            'print(f"F1-Score           : {f1_score(y_status_test, p_rf_status)*100:.2f}%\\n")',
            'print("Confusion Matrix (Aktual vs Prediksi Status ROP):")',
            'print(f"                 Prediksi AMAN   Prediksi REORDER")',
            'print(f"Aktual AMAN          {cm[0,0]:>8}           {cm[0,1]:>8}")',
            'print(f"Aktual REORDER       {cm[1,0]:>8}           {cm[1,1]:>8}")',
        ], out_cls),
        md_cell([
            "## 5. Eksperimen Hyperparameter Tuning Random Forest",
            "Menguji 16 kombinasi jumlah pohon (`n_estimators`) dan kedalaman pohon (`max_depth`).",
        ]),
        code_cell([
            "tuning_rows = []",
            "for n_est in [50, 100, 200, 300]:",
            "    for m_depth in [5, 8, 12, None]:",
            "        rf = RandomForestRegressor(n_estimators=n_est, max_depth=m_depth, min_samples_leaf=3, random_state=42, n_jobs=-1)",
            "        rf.fit(X_train, y_train)",
            "        p = rf.predict(X_test)",
            "        mse = mean_squared_error(y_test, p)",
            "        rop_t = p * 7 + safety_test",
            '        acc_t = accuracy_score(y_status_test, (test_df["stock_norm"].values <= rop_t).astype(int)) * 100',
            "        tuning_rows.append({",
            '            "n_estimators": n_est,',
            '            "max_depth": str(m_depth) if m_depth else "None (Unlimited)",',
            '            "MAE": round(mean_absolute_error(y_test, p), 4),',
            '            "MSE": round(mse, 4),',
            '            "RMSE": round(np.sqrt(mse), 4),',
            '            "R2_Score": round(r2_score(y_test, p), 4),',
            '            "Akurasi_ROP (%)": round(acc_t, 2),',
            "        })",
            'df_tuning_res = pd.DataFrame(tuning_rows).sort_values("RMSE")',
            "print(df_tuning_res.to_string(index=False))",
        ], df_tuning.to_string(index=False)),
        md_cell([
            "## 6. Feature Importance & Hasil Prediksi ROP 88 Barang",
        ]),
        code_cell([
            "df_fi_res = pd.DataFrame({",
            '    "Fitur": FEATURE_COLS,',
            '    "Importance": np.round(best_rf.feature_importances_, 4),',
            '    "Persentase (%)": np.round(best_rf.feature_importances_ * 100, 2),',
            '}).sort_values("Importance", ascending=False)',
            "print(df_fi_res.to_string(index=False))",
            "",
            "plt.figure(figsize=(8, 4.5))",
            'plt.barh(df_fi_res["Fitur"][::-1], df_fi_res["Persentase (%)"][::-1], color="#0E2A66")',
            'plt.xlabel("Tingkat Kepentingan Fitur (%)")',
            'plt.title("Feature Importance - Random Forest Regressor")',
            "plt.tight_layout()",
            "plt.show()",
        ], df_fi.to_string(index=False)),
        code_cell([
            'df_rop_res = pd.read_csv("6_hasil_prediksi_rop_88_barang.csv")',
            'print("Ringkasan Status Stok 88 Barang:")',
            'print(df_rop_res["status"].value_counts())',
            'print("\\nContoh 15 Barang dengan Status REORDER:")',
            'print(df_rop_res[df_rop_res["status"] == "REORDER"].head(15).to_string(index=False))',
        ], out6),
    ]

    nb = {
        "cells": cells,
        "metadata": {
            "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
            "language_info": {"name": "python", "version": "3.10.0"},
        },
        "nbformat": 4,
        "nbformat_minor": 5,
    }

    with open(os.path.join(OUT_DIR, "Eksperimen_ML_UzinStock_Colab.ipynb"), "w") as f:
        json.dump(nb, f, indent=2)


if __name__ == "__main__":
    summary = run_pipeline()
    with open(os.path.join(OUT_DIR, "ringkasan_eksperimen.json"), "w") as f:
        json.dump(summary, f, indent=2)
