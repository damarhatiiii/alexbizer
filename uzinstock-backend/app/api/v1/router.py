from fastapi import APIRouter

from app.api.v1 import auth, items, predictions, transactions

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(items.router)
api_router.include_router(transactions.router)
api_router.include_router(predictions.router)
