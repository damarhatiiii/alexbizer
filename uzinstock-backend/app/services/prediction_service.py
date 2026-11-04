import math
from datetime import date, timedelta

import pandas as pd
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.config import settings
from app.ml.features import FEATURE_COLS, build_latest_features
from app.models import Item, PredictionLog, Transaction, User


def get_daily_demand(db: Session, item_id: int, end: date = None) -> pd.Series:
    """Permintaan harian (total transaksi OUT per hari), hari kosong diisi 0.
    `end` opsional (default hari ini); dipakai training agar data historis tidak dipadati nol sampai hari ini."""
    rows = (
        db.query(Transaction.trx_date, func.sum(Transaction.quantity))
        .filter(Transaction.item_id == item_id, Transaction.type == "OUT")
        .group_by(Transaction.trx_date)
        .all()
    )
    if not rows:
        return pd.Series(dtype=float)
    s = pd.Series({pd.Timestamp(d): float(q) for d, q in rows}).sort_index()
    idx = pd.date_range(s.index.min(), pd.Timestamp(end or date.today()), freq="D")
    return s.reindex(idx, fill_value=0.0)


class InsufficientHistory(Exception):
    pass


def run_prediction(db: Session, model, model_version: str, item: Item, user: User) -> PredictionLog:
    series = get_daily_demand(db, item.id)
    if len(series) < settings.MIN_HISTORY_DAYS:
        raise InsufficientHistory(
            f"Data historis belum cukup (min. {settings.MIN_HISTORY_DAYS} hari, tersedia {len(series)})"
        )

    scale = float(series.mean()) or 1.0  # normalisasi per barang (konsisten dgn training)
    features = build_latest_features(series / scale, item.lead_time_days)
    demand_hat = max(0.0, float(model.predict(features[FEATURE_COLS])[0])) * scale  # permintaan/hari

    sigma = float(series.tail(90).std(ddof=0))
    safety = math.ceil(settings.SERVICE_LEVEL_Z * sigma * math.sqrt(item.lead_time_days))
    rop = math.ceil(demand_hat * item.lead_time_days + safety)
    status = "REORDER" if item.current_stock <= rop else "AMAN"

    log = PredictionLog(
        item_id=item.id,
        requested_by=user.id,
        model_version=model_version,
        input_features={k: float(v) for k, v in features.iloc[0].items()},
        predicted_demand=round(demand_hat, 2),
        safety_stock=safety,
        reorder_point=rop,
        stock_at_prediction=item.current_stock,
        status=status,
    )
    item.safety_stock = safety
    item.reorder_point = rop
    db.add(log)
    db.commit()
    db.refresh(log)
    return log
