"""Impor kartu stok Excel (BARANG JADI & BAHAN BAKU) ke database.

Jalankan:
  python -m ml_training.import_excel --jadi "~/Downloads/BARANG JADI 2026.xlsx" \
         --baku "~/Downloads/BAHAN BAKU 2026.xlsx" --dry-run     # cek dulu, tidak menulis DB
  python -m ml_training.import_excel --jadi ... --baku ... --reset  # hapus data lama lalu impor

Satu sheet = satu barang. Hanya kolom Masuk/Keluar/Saldo yang dipakai; Keluar -> transaksi OUT
(dasar prediksi permintaan), Masuk -> transaksi IN.
"""
import argparse
import os
import re
import shutil
from datetime import date, datetime

import pandas as pd

MONTHS = {
    "JAN": 1, "JANUARI": 1, "FEB": 2, "FEBRUARI": 2, "MAR": 3, "MARET": 3, "APR": 4, "APRIL": 4,
    "MEI": 5, "JUN": 6, "JUNI": 6, "JUL": 7, "JULI": 7, "AGU": 8, "AGT": 8, "AGS": 8, "AGUSTUS": 8,
    "SEP": 9, "SEPT": 9, "SEPTEMBER": 9, "OKT": 10, "OKTOBER": 10, "NOV": 11, "NOPEMBER": 11,
    "NOVEMBER": 11, "DES": 12, "DESEMBER": 12,
}


def num(v):
    x = pd.to_numeric(v, errors="coerce")
    return None if pd.isna(x) else float(x)


def parse_month_label(v):
    """'JUNI 2025' / 'AGUSTUS 25' -> (2025, 6); selain itu None."""
    if not isinstance(v, str):
        return None
    m = re.match(r"^\s*([A-Za-z]+)\s*[-.]?\s*(\d{2,4})\s*$", v)
    if m and m.group(1).upper() in MONTHS:
        y = int(m.group(2))
        return (y + 2000 if y < 100 else y, MONTHS[m.group(1).upper()])
    return None


def parse_full_date(v):
    """datetime / '19 JUNI 25' / '2025-06-19' -> date; selain itu None."""
    if isinstance(v, (datetime, pd.Timestamp)):
        return v.date()
    if isinstance(v, str):
        m = re.match(r"^\s*(\d{1,2})\s+([A-Za-z]+)\.?\s+(\d{2,4})\s*$", v)
        if m and m.group(2).upper() in MONTHS:
            y = int(m.group(3))
            return date(y + 2000 if y < 100 else y, MONTHS[m.group(2).upper()], int(m.group(1)))
        try:
            return pd.to_datetime(v, dayfirst=True).date()
        except Exception:
            return None
    return None


def find_label(df, label):
    """Cari baris dengan kolom-0 diawali `label`, ambil nilai teks pertama di kolom sesudahnya."""
    for i in range(min(len(df), 15)):
        c0 = df.iat[i, 0]
        if isinstance(c0, str) and c0.strip().lower().startswith(label.lower()):
            for j in range(1, min(df.shape[1], 5)):
                v = df.iat[i, j]
                if isinstance(v, str) and v.strip() not in ("", ":"):
                    return v.strip()
    return None


def read_card(df, kind, start_year):
    """Kembalikan (nama, kode, baris) dengan baris = [(tanggal, masuk, keluar, saldo)]."""
    header = next((i for i in range(min(len(df), 20))
                   if isinstance(df.iat[i, 0], str) and df.iat[i, 0].strip().lower() == "tanggal"), None)
    if header is None:
        return None
    if kind == "jadi":
        name, code = find_label(df, "Nama Prodak"), find_label(df, "Kode Prodak")
        c_in, c_out, c_bal, first = 2, 4, 6, header + 2
        month_col = 1
    else:
        name, code = find_label(df, "Nama Barang"), find_label(df, "Kode Barang")
        first = header + 3
        month_col = None
        # pilih set kolom: Kg (4,6,8) atau Kemasan (3,5,7), mana yang lebih banyak terisi
        body = df.iloc[first:]
        n_kg = body[[4, 6]].apply(pd.to_numeric, errors="coerce").notna().sum().sum()
        n_pk = body[[3, 5]].apply(pd.to_numeric, errors="coerce").notna().sum().sum()
        c_in, c_out, c_bal = (4, 6, 8) if n_kg >= n_pk else (3, 5, 7)

    rows, ctx, last_day, last_date = [], None, 0, None
    if kind == "baku":
        ctx = (start_year, 1)
    for i in range(first, len(df)):
        raw = df.iat[i, 0]
        if month_col is not None:
            lab = parse_month_label(df.iat[i, month_col])
            if lab:
                ctx, last_day = lab, 0
        d = parse_full_date(raw) if not isinstance(raw, (int, float)) or pd.isna(raw) else None
        if d is None and isinstance(raw, str):
            lab = parse_month_label(raw)
            if lab:
                ctx, last_day = lab, 0
        if d is not None:
            ctx, last_day, last_date = (d.year, d.month), d.day, d
        elif isinstance(raw, (int, float)) and not pd.isna(raw) and ctx:
            day = int(raw)
            if day < last_day:  # hari mundur => pindah bulan
                ctx = (ctx[0] + (ctx[1] == 12), ctx[1] % 12 + 1)
            last_day = day
            try:
                last_date = date(ctx[0], ctx[1], day)
            except ValueError:
                continue
        qin, qout, bal = num(df.iat[i, c_in]), num(df.iat[i, c_out]), num(df.iat[i, c_bal])
        if (qin or qout) and last_date:
            rows.append((last_date, qin or 0.0, qout or 0.0, bal))
    return name, code, rows


TON_SHEETS = {"SEMEN W", "SEMEN OPC", "GGBFS"}


def build_items(path, kind, start_year):
    xl = pd.ExcelFile(os.path.expanduser(path))
    items, used = [], set()
    for sheet in xl.sheet_names:
        df = xl.parse(sheet, header=None)
        card = read_card(df, kind, start_year)
        if not card or not card[2]:
            print(f"  [lewati] {kind}:{sheet.strip()} (tidak ada transaksi)")
            continue
        name, code, rows = card
        rows.sort(key=lambda r: r[0])
        base = (code or f"{'FG' if kind == 'jadi' else 'RM'}-{sheet.strip()}").replace(" ", "")[:26]
        sku, k = base, 2
        while sku in used:
            sku, k = f"{base}#{k}", k + 1
        used.add(sku)
        # Di Excel Bahan Baku, SEMEN W / SEMEN OPC / GGBFS dicatat dalam Ton (1 Ton = 1000 kg),
        # sedangkan bahan baku lainnya sudah dalam satuan Kg dan Barang Jadi dalam satuan Sak.
        scale = 1000 if (kind == "baku" and sheet.strip().upper() in TON_SHEETS) else 1
        items.append({
            "sku": sku, "name": (name or sheet.strip())[:150], "sheet": sheet.strip(),
            "kind": kind, "rows": rows, "scale": scale,
            "unit": "sak" if kind == "jadi" else "kg",
        })
    return items


def to_transactions(it):
    """Susun transaksi dengan stok sebelum/sesudah mengikuti kolom Saldo di Excel."""
    s = it["scale"]
    out, rows = [], it["rows"]
    first_d, fin, fout, fbal = rows[0]
    opening = (fbal - fin + fout) if fbal is not None else 0.0
    stock = max(0, round(opening * s))
    if stock > 0:
        out.append(("IN", stock, 0, stock, "Saldo awal (impor Excel)", first_d))
    for d, qin, qout, bal in rows:
        for typ, raw_q in (("IN", qin), ("OUT", qout)):
            if not raw_q or raw_q <= 0:
                continue
            q = max(1, round(raw_q * s))
            after = stock + q if typ == "IN" else max(0, stock - q)
            out.append((typ, q, stock, after, None, d))
            stock = after
        if bal is not None:
            stock = max(0, round(bal * s))  # sinkron dengan saldo Excel
    return out, stock


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--jadi", required=True)
    ap.add_argument("--baku", required=True)
    ap.add_argument("--baku-year", type=int, default=2026, help="tahun awal kartu bahan baku")
    ap.add_argument("--reset", action="store_true", help="hapus item/transaksi lama (user dipertahankan)")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--lead-time", type=int, default=7)
    a = ap.parse_args()

    items = build_items(a.jadi, "jadi", 2025) + build_items(a.baku, "baku", a.baku_year)
    print(f"\n{'SKU':28}{'Sheet':18}{'Brs':>5}{'OUT hari':>9}{'Awal':>12}{'Akhir':>12}  Unit")
    for it in items:
        ds = [r[0] for r in it["rows"]]
        outd = len({r[0] for r in it["rows"] if r[2]})
        print(f"{it['sku']:28}{it['sheet'][:17]:18}{len(it['rows']):5}{outd:9}{str(min(ds)):>12}{str(max(ds)):>12}  {it['unit']}")
    print(f"\nTotal item: {len(items)}")
    if a.dry_run:
        return

    from app import models  # noqa: F401
    from app.core.config import settings
    from app.db.session import Base, SessionLocal, engine
    from app.models import Item, PredictionLog, StockOpname, Transaction, User, infer_category

    Base.metadata.create_all(bind=engine)
    if engine.url.drivername.startswith("sqlite") and engine.url.database:
        shutil.copy(engine.url.database, engine.url.database + ".bak")
        print(f"Backup DB: {engine.url.database}.bak")
    db = SessionLocal()
    if a.reset:
        for m in (PredictionLog, StockOpname, Transaction, Item):
            db.query(m).delete()
        db.flush()
    admin = db.query(User).filter(User.username == "admin").one()
    for it in items:
        trx, final = to_transactions(it)
        item = Item(
            sku=it["sku"],
            name=it["name"],
            category=infer_category(it["sku"], it["name"]),
            unit=it["unit"],
            lead_time_days=a.lead_time,
            current_stock=final,
        )
        db.add(item)
        db.flush()
        db.add_all([Transaction(item_id=item.id, user_id=admin.id, type=t, quantity=q, stock_before=b, stock_after=af,
                                notes=n, trx_date=d) for t, q, b, af, n, d in trx])
    db.commit()
    print("Impor selesai.")


if __name__ == "__main__":
    main()
