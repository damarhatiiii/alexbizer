# UzinStock / UzinCast

Aplikasi mobile inventory semen mortar + prediksi Reorder Point (Random Forest) – studi kasus PT Uzin Utz Indonesia.

```
uzinstock-backend/   FastAPI + SQLAlchemy + Scikit-Learn (Joblib)
uzinstock_app/       Flutter (Android/iOS), Riverpod + Dio
```

## Backend

```bash
cd uzinstock-backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env                 # ganti DATABASE_URL ke PostgreSQL/MySQL bila perlu

python -m ml_training.seed_demo      # data SIMULASI (ganti dengan data riil untuk jurnal)
python -m ml_training.train_rf       # latih RF -> app/ml/artifacts/rf_model.joblib (+ _metrics.json)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
pytest -q                            # tes RBAC + prediksi
```
Dokumentasi API: http://localhost:8000/docs

Akun demo: `admin/admin123`, `manager/manager123`, `staff/staff123`, `viewer/viewer123`.

| Role | Lihat | Tambah/Ubah/Hapus | Prediksi |
|---|---|---|---|
| viewer | ✅ | ❌ | ❌ |
| staff | ✅ | ❌ | ✅ |
| manager, admin | ✅ | ✅ | ✅ |

## Flutter

Platform folder (android/ios) belum ada; generate dulu di dalam folder app:

```bash
cd uzinstock_app
flutter create . --project-name uzinstock_app --org id.co.uzinutz
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1   # Android emulator
# iOS simulator: http://localhost:8000/api/v1 ; device fisik: http://<IP-LAN>:8000/api/v1
```
Android: tambahkan `android:usesCleartextTraffic="true"` di AndroidManifest untuk HTTP saat development; gunakan HTTPS di produksi.

## Logika Prediksi
RF Regressor memprediksi permintaan harian besok dari fitur lag, rolling mean/std, hari, bulan, lead time.
`safety = Z·σ·√L`, `ROP = d̂·L + safety`, status `REORDER` bila stok ≤ ROP.
