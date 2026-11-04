from datetime import date
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.deps import get_current_user, get_db, require_write
from app.models import Item, StockOpname, Transaction, User
from app.schemas import OpnameCreate, OpnameOut, TransactionCreate, TransactionOut

router = APIRouter(tags=["Transactions"])


@router.get("/transactions", response_model=List[TransactionOut])
def list_transactions(
    item_id: Optional[int] = None,
    limit: int = 100,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = db.query(Transaction)
    if item_id:
        q = q.filter(Transaction.item_id == item_id)
    return q.order_by(Transaction.trx_date.desc(), Transaction.id.desc()).limit(min(limit, 500)).all()


@router.post("/transactions", response_model=TransactionOut, status_code=201)
def create_transaction(body: TransactionCreate, db: Session = Depends(get_db), user: User = Depends(require_write)):
    item = db.query(Item).filter(Item.id == body.item_id, Item.is_deleted.is_(False)).with_for_update().first()
    if not item:
        raise HTTPException(404, "Barang tidak ditemukan")
    before = item.current_stock
    after = before + body.quantity if body.type == "IN" else before - body.quantity
    if after < 0:
        raise HTTPException(400, f"Stok tidak mencukupi (tersedia {before})")
    item.current_stock = after
    trx = Transaction(
        item_id=item.id, user_id=user.id, type=body.type, quantity=body.quantity,
        stock_before=before, stock_after=after, reference_no=body.reference_no,
        notes=body.notes, trx_date=body.trx_date or date.today(),
    )
    db.add(trx)
    db.commit()
    db.refresh(trx)
    return trx


@router.get("/stock-opname", response_model=List[OpnameOut])
def list_opname(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    return db.query(StockOpname).order_by(StockOpname.id.desc()).limit(100).all()


@router.post("/stock-opname", response_model=OpnameOut, status_code=201)
def create_opname(body: OpnameCreate, db: Session = Depends(get_db), user: User = Depends(require_write)):
    item = db.query(Item).filter(Item.id == body.item_id, Item.is_deleted.is_(False)).with_for_update().first()
    if not item:
        raise HTTPException(404, "Barang tidak ditemukan")
    before = item.current_stock
    diff = body.physical_stock - before
    opname = StockOpname(
        item_id=item.id, user_id=user.id, system_stock=before,
        physical_stock=body.physical_stock, notes=body.notes,
    )
    db.add(opname)
    if diff != 0:  # penyesuaian dicatat sebagai transaksi (audit trail)
        item.current_stock = body.physical_stock
        db.add(
            Transaction(
                item_id=item.id, user_id=user.id, type="OPNAME_ADJ", quantity=diff,
                stock_before=before, stock_after=body.physical_stock, notes=body.notes or "Stok opname",
            )
        )
    db.commit()
    db.refresh(opname)
    return opname
