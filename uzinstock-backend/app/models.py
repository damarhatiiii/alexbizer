from datetime import date, datetime
from typing import Optional

from sqlalchemy import JSON, Boolean, Date, DateTime, ForeignKey, Index, Integer, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base

ROLES = ("admin", "manager", "staff", "viewer")

CATEGORIES = (
    "Pasir",
    "Semen",
    "Kalsium & Filler",
    "Aditif & Bahan Kimia",
    "Kemasan & Karung",
    "Bahan Bakar",
    "Mortar & Perekat",
    "Self Leveling & Pelapis",
    "Lainnya",
)


def default_unit_for_category(category: str) -> str:
    if category in ("Mortar & Perekat", "Self Leveling & Pelapis"):
        return "sak"
    return "kg"


def infer_category(sku: str, name: str) -> str:

    s = (sku or "").upper().strip()
    n = (name or "").upper().strip()

    # 1. Pasir
    if s.startswith("BB-PSR") or "PASIR" in n:
        return "Pasir"

    # 2. Semen (OPC, Putih, PCC/GGBFS, Aluminate/Secar)
    if (
        s.startswith(("BB-OPC", "BB-PCC", "BB-ALU"))
        or "SEMEN" in n
        or "GGBFS" in n
        or "SECAR" in n
    ):
        return "Semen"

    # 3. Kalsium & Filler (CaCO3, Omya Carb, Pealite, Bata)
    if (
        s.startswith(("BB-CCO", "BB-BTB", "BB-BTR"))
        or "CACO3" in n
        or "OMYA" in n
        or "PEALITE" in n
        or "BATA" in n
    ):
        return "Kalsium & Filler"

    # 4. Bahan Bakar (Solar)
    if s.startswith("BB-SLR") or "SOLAR" in n or "DIESEL" in n:
        return "Bahan Bakar"

    # 5. Kemasan & Karung (Karung, Zak, Inner Plastik, Benang Jahit Karung, Jerigen, Pail)
    if (
        s.startswith(("BB-KRG", "BB-ZAK", "BB-INN", "BB-JRG", "BB-PAL", "BB-BNG01"))
        or "KARUNG" in n
        or "JERIGEN" in n
        or "PAIL " in n
        or "KANTONG PLASTIK" in n
        or "INNER HDPE" in n
    ):
        return "Kemasan & Karung"

    # 6. Aditif & Bahan Kimia (MC, FLO, ADD, RDP, PWD, BIN, WTR, Fiber, Maleki)
    if (
        s.startswith(
            (
                "BB-MC",
                "BB-FLO",
                "BB-ADD",
                "BB-RDP",
                "BB-PWD",
                "BB-BIN",
                "BB-WTR",
                "BB-BNG02",
                "RM-",
                "BB-",
            )
        )
    ):
        return "Aditif & Bahan Kimia"

    # 7. Produk Jadi: Self Leveling, Tile Grout & Pelapis (SL, LS, Primer, PE)
    if (
        s.startswith(("US-", "LS-", "UW-", "UC-", "FG-LS"))
        or "SL " in n
        or "LS " in n
        or "PRIMER" in n
        or "PE 360" in n
        or "SELF LEVEL" in n
    ):
        return "Self Leveling & Pelapis"

    # 8. Produk Jadi: Mortar & Perekat (UM, FG-TB, FG-B, FG-SC, MRT)
    if (
        s.startswith(("UM-", "FG-", "MRT-"))
        or "MORTAR" in n
        or "PLASTER" in n
        or "SCREED" in n
        or "BOND" in n
        or "UZIN SC" in n
    ):
        return "Mortar & Perekat"

    return "Lainnya"



class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    full_name: Mapped[str] = mapped_column(String(100))
    password_hash: Mapped[str] = mapped_column(Text)
    role: Mapped[str] = mapped_column(String(20), default="viewer")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())


class Item(Base):
    __tablename__ = "items"

    id: Mapped[int] = mapped_column(primary_key=True)
    sku: Mapped[str] = mapped_column(String(30), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(150))
    category: Mapped[str] = mapped_column(String(50), default="Lainnya", index=True)
    unit: Mapped[str] = mapped_column(String(20), default="sak")
    current_stock: Mapped[int] = mapped_column(Integer, default=0)
    lead_time_days: Mapped[int] = mapped_column(Integer, default=7)
    safety_stock: Mapped[int] = mapped_column(Integer, default=0)
    reorder_point: Mapped[int] = mapped_column(Integer, default=0)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), onupdate=func.now())


class Transaction(Base):
    """Append-only: IN, OUT, OPNAME_ADJ."""

    __tablename__ = "transactions"
    __table_args__ = (Index("idx_trx_item_date", "item_id", "trx_date"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    item_id: Mapped[int] = mapped_column(ForeignKey("items.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    type: Mapped[str] = mapped_column(String(12))
    quantity: Mapped[int] = mapped_column(Integer)
    stock_before: Mapped[int] = mapped_column(Integer)
    stock_after: Mapped[int] = mapped_column(Integer)
    reference_no: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    trx_date: Mapped[date] = mapped_column(Date, default=date.today)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    item: Mapped[Item] = relationship()
    user: Mapped[User] = relationship()

    @property
    def item_name(self) -> str:
        return self.item.name

    @property
    def item_category(self) -> str:
        return self.item.category

    @property
    def item_unit(self) -> str:
        return self.item.unit

    @property
    def user_name(self) -> str:
        return self.user.full_name


class StockOpname(Base):
    __tablename__ = "stock_opnames"

    id: Mapped[int] = mapped_column(primary_key=True)
    item_id: Mapped[int] = mapped_column(ForeignKey("items.id"))
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    system_stock: Mapped[int] = mapped_column(Integer)
    physical_stock: Mapped[int] = mapped_column(Integer)
    opname_date: Mapped[date] = mapped_column(Date, default=date.today)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    item: Mapped[Item] = relationship()

    @property
    def difference(self) -> int:
        return self.physical_stock - self.system_stock

    @property
    def item_name(self) -> str:
        return self.item.name


class PredictionLog(Base):
    __tablename__ = "prediction_logs"

    id: Mapped[int] = mapped_column(primary_key=True)
    item_id: Mapped[int] = mapped_column(ForeignKey("items.id"), index=True)
    requested_by: Mapped[Optional[int]] = mapped_column(ForeignKey("users.id"), nullable=True)
    model_version: Mapped[str] = mapped_column(String(30))
    input_features: Mapped[dict] = mapped_column(JSON)
    predicted_demand: Mapped[float] = mapped_column(Numeric(12, 2))
    safety_stock: Mapped[int] = mapped_column(Integer)
    reorder_point: Mapped[int] = mapped_column(Integer)
    stock_at_prediction: Mapped[int] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(10))  # REORDER / AMAN
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    item: Mapped[Item] = relationship()

    @property
    def item_name(self) -> str:
        return self.item.name

    @property
    def item_category(self) -> str:
        return self.item.category

    @property
    def item_unit(self) -> str:
        return self.item.unit
