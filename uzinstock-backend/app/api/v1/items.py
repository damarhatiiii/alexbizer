from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_db, require_write
from app.models import Item, Transaction, User, default_unit_for_category, infer_category
from app.schemas import ItemCreate, ItemOut, ItemUpdate

router = APIRouter(prefix="/items", tags=["Items"])


def _get_or_404(db: Session, item_id: int) -> Item:
    item = db.get(Item, item_id)
    if not item or item.is_deleted:
        raise HTTPException(404, "Barang tidak ditemukan")
    return item


@router.get("", response_model=List[ItemOut])
def list_items(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    return db.query(Item).filter(Item.is_deleted.is_(False)).order_by(Item.name).all()


@router.get("/{item_id}", response_model=ItemOut)
def get_item(item_id: int, db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    return _get_or_404(db, item_id)


@router.post("", response_model=ItemOut, status_code=201)
def create_item(body: ItemCreate, db: Session = Depends(get_db), user: User = Depends(require_write)):
    if db.query(Item).filter(Item.sku == body.sku).first():
        raise HTTPException(409, "SKU sudah ada")
    data = body.model_dump()
    if not data.get("category") or not data["category"].strip():
        data["category"] = infer_category(body.sku, body.name)
    if not data.get("unit") or not data["unit"].strip():
        data["unit"] = default_unit_for_category(data["category"])
    item = Item(**data)
    db.add(item)
    db.flush()
    if item.current_stock > 0:  # catat stok awal sebagai transaksi masuk
        db.add(
            Transaction(
                item_id=item.id, user_id=user.id, type="IN", quantity=item.current_stock,
                stock_before=0, stock_after=item.current_stock, notes="Stok awal",
            )
        )
    db.commit()
    db.refresh(item)
    return item


@router.put("/{item_id}", response_model=ItemOut)
def update_item(item_id: int, body: ItemUpdate, db: Session = Depends(get_db), _: User = Depends(require_write)):
    item = _get_or_404(db, item_id)
    for k, v in body.model_dump(exclude_unset=True).items():
        if v is not None:
            setattr(item, k, v)
    db.commit()
    db.refresh(item)
    return item


@router.delete("/{item_id}", status_code=204)
def delete_item(item_id: int, db: Session = Depends(get_db), _: User = Depends(require_write)):
    item = _get_or_404(db, item_id)
    item.is_deleted = True  # soft delete, riwayat transaksi tetap utuh
    db.commit()
