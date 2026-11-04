from contextlib import asynccontextmanager

from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import inspect, text

from app import models  # noqa: F401  (register tables)
from app.api.v1.router import api_router
from app.core.config import settings
from app.core.security import hash_password
from app.db.session import Base, SessionLocal, engine
from app.ml.predictor import load_model
from app.models import Item, User, infer_category


def _ensure_category_column():
    insp = inspect(engine)
    if "items" in insp.get_table_names():
        cols = {c["name"] for c in insp.get_columns("items")}
        if "category" not in cols:
            with engine.begin() as conn:
                conn.execute(text("ALTER TABLE items ADD COLUMN category VARCHAR(50) DEFAULT 'Lainnya'"))


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    _ensure_category_column()
    db = SessionLocal()
    try:
        if db.query(User).count() == 0:
            db.add(
                User(
                    username=settings.FIRST_ADMIN_USERNAME,
                    full_name="Administrator",
                    password_hash=hash_password(settings.FIRST_ADMIN_PASSWORD),
                    role="admin",
                )
            )
            db.commit()
        for it in db.query(Item).all():
            if not it.category or it.category == "Lainnya":
                inferred = infer_category(it.sku, it.name)
                if inferred != it.category:
                    it.category = inferred
        db.commit()
    finally:
        db.close()
    app.state.rf_model = load_model(settings.MODEL_PATH)
    app.state.model_version = settings.MODEL_VERSION
    yield


app = FastAPI(title="UzinStock API", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.include_router(api_router, prefix="/api/v1")


@app.get("/", tags=["System"])
def root():
    return {
        "name": "UzinStock API",
        "version": "1.0.0",
        "status": "running",
        "docs_url": "/docs",
        "health_url": "/health",
    }


@app.get("/favicon.ico", include_in_schema=False)
def favicon():
    return Response(status_code=204)


@app.get("/health", tags=["System"])
def health():
    return {"status": "ok", "model_loaded": app.state.rf_model is not None}
