from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    DATABASE_URL: str = "sqlite:///./uzinstock.db"
    SECRET_KEY: str = "dev-secret-change-me"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 480

    MODEL_PATH: str = str(BASE_DIR / "app" / "ml" / "artifacts" / "rf_model.joblib")
    MODEL_VERSION: str = "rf-v1.0"
    SERVICE_LEVEL_Z: float = 1.65  # service level 95%
    MIN_HISTORY_DAYS: int = 30

    FIRST_ADMIN_USERNAME: str = "admin"
    FIRST_ADMIN_PASSWORD: str = "admin123"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
