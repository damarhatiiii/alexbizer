from typing import List

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_db, require_predict
from app.models import Item, PredictionLog, User
from app.schemas import PredictionOut
from app.services.prediction_service import InsufficientHistory, run_prediction

router = APIRouter(prefix="/predictions", tags=["Prediction"])


def _predict(request: Request, db: Session, item: Item, user: User) -> PredictionLog:
    model = request.app.state.rf_model
    if model is None:
        raise HTTPException(503, "Model belum tersedia. Jalankan: python -m ml_training.train_rf")
    try:
        return run_prediction(db, model, request.app.state.model_version, item, user)
    except InsufficientHistory as e:
        raise HTTPException(422, str(e))


def _item_or_404(db: Session, item_id: int) -> Item:
    item = db.get(Item, item_id)
    if not item or item.is_deleted:
        raise HTTPException(404, "Barang tidak ditemukan")
    return item


@router.post("/reorder-point/{item_id}", response_model=PredictionOut)
def predict_reorder_point(
    item_id: int, request: Request, db: Session = Depends(get_db), user: User = Depends(require_predict)
):
    return _predict(request, db, _item_or_404(db, item_id), user)


@router.post("/reorder-point", response_model=List[PredictionOut])
def predict_all(request: Request, db: Session = Depends(get_db), user: User = Depends(require_predict)):
    """Prediksi semua barang yang punya histori cukup; yang kurang data dilewati."""
    out = []
    for item in db.query(Item).filter(Item.is_deleted.is_(False)).all():
        try:
            out.append(_predict(request, db, item, user))
        except HTTPException as e:
            if e.status_code == 503:
                raise
    return out


@router.get("/history/{item_id}", response_model=List[PredictionOut])
def prediction_history(item_id: int, db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    return (
        db.query(PredictionLog).filter(PredictionLog.item_id == item_id)
        .order_by(PredictionLog.id.desc()).limit(50).all()
    )


@router.get("/latest", response_model=List[PredictionOut])
def latest_predictions(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    """Prediksi terbaru per barang (status AMAN/REORDER)."""
    latest = {}
    for log in db.query(PredictionLog).order_by(PredictionLog.id.asc()).all():
        latest[log.item_id] = log
    return sorted(latest.values(), key=lambda x: (x.status != "REORDER", x.item_name))


@router.get("/alerts", response_model=List[PredictionOut])
def reorder_alerts(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    return [p for p in latest_predictions(db, user) if p.status == "REORDER"]
