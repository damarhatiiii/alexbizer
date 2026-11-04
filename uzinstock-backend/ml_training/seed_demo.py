"""Data demo sintetis: user, barang semen mortar, dan ~240 hari transaksi.
Jalankan: python -m ml_training.seed_demo
Catatan: ini data SIMULASI untuk uji sistem. Untuk jurnal, ganti dengan data historis riil PT Uzin Utz Indonesia."""
from datetime import date, timedelta

import numpy as np

from app import models  # noqa: F401
from app.core.security import hash_password
from app.db.session import Base, SessionLocal, engine
from app.models import Item, Transaction, User, infer_category

DAYS = 240
ITEMS = [
    # sku, nama, rata-rata permintaan/hari, lead time
    ("MRT-001", "Mortar Perekat Keramik 25kg", 40, 7),
    ("MRT-002", "Mortar Instan Plester 40kg", 65, 10),
    ("MRT-003", "Self Levelling Mortar 25kg", 25, 14),
    ("MRT-004", "Grouting Mortar 5kg", 90, 5),
    ("MRT-005", "Mortar Waterproofing 20kg", 18, 12),
]
USERS = [
    ("admin", "Administrator", "admin123", "admin"),
    ("manager", "Manajer Gudang", "manager123", "manager"),
    ("staff", "Staf Logistik", "staff123", "staff"),
    ("viewer", "Pihak Terkait", "viewer123", "viewer"),
]


def main():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    if db.query(Item).count() > 0:
        print("Data sudah ada, seed dilewati.")
        return
    rng = np.random.default_rng(42)

    for u, name, pw, role in USERS:
        if not db.query(User).filter(User.username == u).first():
            db.add(User(username=u, full_name=name, password_hash=hash_password(pw), role=role))
    db.flush()
    admin = db.query(User).filter(User.username == "admin").one()

    start = date.today() - timedelta(days=DAYS)
    for sku, name, mean, lead in ITEMS:
        item = Item(
            sku=sku,
            name=name,
            category=infer_category(sku, name),
            unit="sak",
            lead_time_days=lead,
            current_stock=0,
        )
        db.add(item)
        db.flush()
        stock = mean * 25
        db.add(Transaction(item_id=item.id, user_id=admin.id, type="IN", quantity=stock, stock_before=0,
                           stock_after=stock, notes="Stok awal", trx_date=start))
        for d in range(DAYS):
            day = start + timedelta(days=d + 1)
            if day.weekday() == 6:  # Minggu libur
                continue
            season = 1 + 0.25 * np.sin(2 * np.pi * day.timetuple().tm_yday / 365)
            dow = 1.2 if day.weekday() in (0, 1) else 1.0
            qty = int(max(0, rng.normal(mean * season * dow, mean * 0.2)))
            if qty > stock:  # restock dulu bila stok kurang
                restock = mean * 20
                db.add(Transaction(item_id=item.id, user_id=admin.id, type="IN", quantity=restock,
                                   stock_before=stock, stock_after=stock + restock,
                                   reference_no=f"PO-{sku}-{d}", trx_date=day))
                stock += restock
            if qty > 0:
                db.add(Transaction(item_id=item.id, user_id=admin.id, type="OUT", quantity=qty,
                                   stock_before=stock, stock_after=stock - qty, trx_date=day))
                stock -= qty
        item.current_stock = stock
    db.commit()
    print("Seed selesai. Login: admin/admin123, manager/manager123, staff/staff123, viewer/viewer123")


if __name__ == "__main__":
    main()
