import os

import joblib


def load_model(path: str):
    """Load model Random Forest dari Joblib. Return None jika belum ada (belum training)."""
    if not os.path.exists(path):
        return None
    return joblib.load(path)
