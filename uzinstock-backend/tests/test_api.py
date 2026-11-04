"""Smoke test RBAC & prediksi. Jalankan setelah seed + training: pytest -q"""
from fastapi.testclient import TestClient

from app.main import app


def _login(c, u, p):
    r = c.post("/api/v1/auth/login", data={"username": u, "password": p})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_rbac_and_prediction():
    with TestClient(app) as c:
        admin = _login(c, "admin", "admin123")
        viewer = _login(c, "viewer", "viewer123")

        items = c.get("/api/v1/items", headers=viewer).json()
        assert len(items) > 0  # viewer boleh baca

        body = {"item_id": items[0]["id"], "type": "IN", "quantity": 1}
        assert c.post("/api/v1/transactions", json=body, headers=viewer).status_code == 403
        assert c.post("/api/v1/transactions", json=body, headers=admin).status_code == 201

        assert c.post(f"/api/v1/predictions/reorder-point/{items[0]['id']}", headers=viewer).status_code == 403
        r = c.post(f"/api/v1/predictions/reorder-point/{items[0]['id']}", headers=admin)
        assert r.status_code == 200, r.text
        assert r.json()["status"] in ("AMAN", "REORDER")
