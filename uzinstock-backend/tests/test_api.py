"""Unit & Integration Test Suite (T-01 s.d. T-11) untuk UzinStock Backend API.
Jalankan: .venv/bin/pytest -v
"""
from fastapi.testclient import TestClient

from app.db.session import SessionLocal
from app.main import app
from app.models import Item, PredictionLog, Transaction


def _login(c: TestClient, u: str, p: str) -> dict:
    r = c.post("/api/v1/auth/login", data={"username": u, "password": p})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_t01_health_and_root():
    """T-01: Cek endpoint / dan /health serta status model Random Forest."""
    with TestClient(app) as c:
        r_root = c.get("/")
        assert r_root.status_code == 200
        assert r_root.json()["status"] == "running"

        r_health = c.get("/health")
        assert r_health.status_code == 200
        assert r_health.json() == {"status": "ok", "model_loaded": True}


def test_t02_auth_login_valid():
    """T-02: Login valid menghasilkan JWT access_token dan profil user."""
    with TestClient(app) as c:
        r = c.post("/api/v1/auth/login", data={"username": "admin", "password": "admin123"})
        assert r.status_code == 200
        body = r.json()
        assert "access_token" in body and len(body["access_token"]) > 20
        assert body["user"]["username"] == "admin"
        assert body["user"]["role"] == "admin"


def test_t03_auth_invalid_and_unauthenticated():
    """T-03: Login password salah dan akses endpoint terproteksi tanpa token menghasilkan 401."""
    with TestClient(app) as c:
        r_bad = c.post("/api/v1/auth/login", data={"username": "admin", "password": "wrongpassword"})
        assert r_bad.status_code == 401

        r_no_token = c.get("/api/v1/items")
        assert r_no_token.status_code == 401


def test_t04_list_items_categories_and_units():
    """T-04: Ambil daftar SKU aktif beserta kategori dan kesesuaian satuan (sak/kg)."""
    with TestClient(app) as c:
        admin = _login(c, "admin", "admin123")
        r = c.get("/api/v1/items", headers=admin)
        assert r.status_code == 200
        items = r.json()
        assert len(items) >= 89
        units = {it["unit"] for it in items}
        assert units == {"sak", "kg"}
        categories = {it["category"] for it in items}
        assert "Pasir" in categories and "Semen" in categories and "Mortar & Perekat" in categories


def test_t05_t06_t07_t08_t11_crud_and_validation():
    """T-05, T-06, T-07, T-08, T-11: CRUD barang, duplikat SKU, transaksi IN/OUT, stok kurang, & histori kurang."""
    with TestClient(app) as c:
        admin = _login(c, "admin", "admin123")
        test_sku = "BB-PASIR-TEST99"

        # Bersihkan jika ada sisa pengujian sebelumnya
        db = SessionLocal()
        old = db.query(Item).filter(Item.sku == test_sku).first()
        if old:
            db.query(PredictionLog).filter(PredictionLog.item_id == old.id).delete()
            db.query(Transaction).filter(Transaction.item_id == old.id).delete()
            db.delete(old)
            db.commit()
        db.close()

        try:
            # T-05: Buat barang baru & update lead_time_days
            r_create = c.post(
                "/api/v1/items",
                json={"sku": test_sku, "name": "Pasir Silika Uji T05", "current_stock": 100, "lead_time_days": 7},
                headers=admin,
            )
            assert r_create.status_code == 201, r_create.text
            created = r_create.json()
            item_id = created["id"]
            assert created["category"] == "Pasir"
            assert created["unit"] == "kg"
            assert created["current_stock"] == 100

            r_upd = c.put(f"/api/v1/items/{item_id}", json={"lead_time_days": 5}, headers=admin)
            assert r_upd.status_code == 200
            assert r_upd.json()["lead_time_days"] == 5

            # T-06: Duplikat SKU ditolak dengan 409 Conflict
            r_dup = c.post(
                "/api/v1/items",
                json={"sku": test_sku, "name": "Duplikat", "current_stock": 10},
                headers=admin,
            )
            assert r_dup.status_code == 409

            # T-07: Transaksi IN (+50) dan OUT (-30) memperbarui current_stock (100 -> 150 -> 120)
            r_in = c.post(
                "/api/v1/transactions",
                json={"item_id": item_id, "type": "IN", "quantity": 50, "notes": "Uji IN"},
                headers=admin,
            )
            assert r_in.status_code == 201
            assert r_in.json()["stock_after"] == 150

            r_out = c.post(
                "/api/v1/transactions",
                json={"item_id": item_id, "type": "OUT", "quantity": 30, "notes": "Uji OUT"},
                headers=admin,
            )
            assert r_out.status_code == 201
            assert r_out.json()["stock_after"] == 120

            # T-08: Transaksi OUT melebihi stok (minta 500 dari 120) ditolak dengan 400 Bad Request
            r_over = c.post(
                "/api/v1/transactions",
                json={"item_id": item_id, "type": "OUT", "quantity": 500},
                headers=admin,
            )
            assert r_over.status_code == 400

            # T-11: Prediksi pada barang baru dengan histori < 30 hari menghasilkan 422, & ID tidak ada -> 404
            r_insufficient = c.post(f"/api/v1/predictions/reorder-point/{item_id}", headers=admin)
            assert r_insufficient.status_code == 422

            r_notfound = c.post("/api/v1/predictions/reorder-point/999999", headers=admin)
            assert r_notfound.status_code == 404
        finally:
            db = SessionLocal()
            rm = db.query(Item).filter(Item.sku == test_sku).first()
            if rm:
                db.query(PredictionLog).filter(PredictionLog.item_id == rm.id).delete()
                db.query(Transaction).filter(Transaction.item_id == rm.id).delete()
                db.delete(rm)
                db.commit()
            db.close()


def test_t09_t10_rbac_and_prediction():
    """T-09 & T-10: RBAC (viewer vs admin) dan inferensi prediksi ROP Random Forest pada SKU riil."""
    with TestClient(app) as c:
        admin = _login(c, "admin", "admin123")
        viewer = _login(c, "viewer", "viewer123")

        items = c.get("/api/v1/items", headers=viewer).json()
        assert len(items) > 0
        target_id = items[0]["id"]
        orig_stock = items[0]["current_stock"]

        # T-09: Viewer ditolak saat menulis transaksi atau memicu prediksi (403 Forbidden)
        body = {"item_id": target_id, "type": "IN", "quantity": 1, "notes": "TEST_RBAC_TEMP"}
        assert c.post("/api/v1/transactions", json=body, headers=viewer).status_code == 403
        assert c.post(f"/api/v1/predictions/reorder-point/{target_id}", headers=viewer).status_code == 403

        r_tx = c.post("/api/v1/transactions", json=body, headers=admin)
        assert r_tx.status_code == 201
        tx_id = r_tx.json()["id"]

        try:
            # T-10: Admin berhasil memicu prediksi Random Forest dan mendapatkan output lengkap
            r = c.post(f"/api/v1/predictions/reorder-point/{target_id}", headers=admin)
            assert r.status_code == 200, r.text
            pred = r.json()
            assert pred["status"] in ("AMAN", "REORDER")
            assert pred["predicted_demand"] >= 0
            assert pred["safety_stock"] >= 0
            assert pred["reorder_point"] >= pred["safety_stock"]
            assert "roll_mean_7" in pred["input_features"]
        finally:
            db = SessionLocal()
            db.query(Transaction).filter(Transaction.id == tx_id).delete()
            it = db.get(Item, target_id)
            if it:
                it.current_stock = orig_stock
            db.commit()
            db.close()
