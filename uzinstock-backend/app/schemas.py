from datetime import date, datetime
from typing import Any, Dict, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field


class ORM(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ---------- Auth / User ----------
class UserOut(ORM):
    id: int
    username: str
    full_name: str
    role: str
    is_active: bool


class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    full_name: str
    password: str = Field(min_length=6)
    role: Literal["admin", "manager", "staff", "viewer"] = "viewer"


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


# ---------- Item ----------
class ItemBase(BaseModel):
    sku: str = Field(max_length=30)
    name: str = Field(max_length=150)
    category: Optional[str] = Field(default=None, max_length=50)
    unit: str = "sak"
    lead_time_days: int = Field(default=7, ge=1)


class ItemCreate(ItemBase):
    current_stock: int = Field(default=0, ge=0)


class ItemUpdate(BaseModel):
    name: Optional[str] = None
    category: Optional[str] = None
    unit: Optional[str] = None
    lead_time_days: Optional[int] = Field(default=None, ge=1)


class ItemOut(ORM):
    id: int
    sku: str
    name: str
    category: str
    unit: str
    current_stock: int
    lead_time_days: int
    safety_stock: int
    reorder_point: int


# ---------- Transaction ----------
class TransactionCreate(BaseModel):
    item_id: int
    type: Literal["IN", "OUT"]
    quantity: int = Field(gt=0)
    reference_no: Optional[str] = None
    notes: Optional[str] = None
    trx_date: Optional[date] = None


class TransactionOut(ORM):
    id: int
    item_id: int
    item_name: str
    item_category: str = "Lainnya"
    item_unit: str = "kg"
    user_name: str
    type: str
    quantity: int
    stock_before: int
    stock_after: int
    reference_no: Optional[str]
    notes: Optional[str]
    trx_date: date
    created_at: datetime


# ---------- Stock opname ----------
class OpnameCreate(BaseModel):
    item_id: int
    physical_stock: int = Field(ge=0)
    notes: Optional[str] = None


class OpnameOut(ORM):
    id: int
    item_id: int
    item_name: str
    system_stock: int
    physical_stock: int
    difference: int
    opname_date: date
    notes: Optional[str]


# ---------- Prediction ----------
class PredictionOut(ORM):
    id: int
    item_id: int
    item_name: str
    item_category: str = "Lainnya"
    item_unit: str = "kg"
    model_version: str
    input_features: Dict[str, Any]
    predicted_demand: float
    safety_stock: int
    reorder_point: int
    stock_at_prediction: int
    status: str
    created_at: datetime
