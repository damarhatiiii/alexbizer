"""Feature engineering - dipakai bersama oleh training & inference agar konsisten."""
import pandas as pd

FEATURE_COLS = [
    "lag_0",
    "lag_6",
    "lag_13",
    "roll_mean_7",
    "roll_mean_30",
    "roll_std_7",
    "next_dow",
    "next_month",
    "lead_time",
]


def _frame(series: pd.Series, lead_time: int) -> pd.DataFrame:
    """series: permintaan harian (index DatetimeIndex harian kontinu).
    Fitur di baris t dipakai untuk memprediksi permintaan hari t+1."""
    s = series.astype(float)
    df = pd.DataFrame({"qty": s})
    df["lag_0"] = s
    df["lag_6"] = s.shift(6)
    df["lag_13"] = s.shift(13)
    df["roll_mean_7"] = s.rolling(7, min_periods=1).mean()
    df["roll_mean_30"] = s.rolling(30, min_periods=1).mean()
    df["roll_std_7"] = s.rolling(7, min_periods=2).std().fillna(0.0)
    nxt = df.index + pd.Timedelta(days=1)
    df["next_dow"] = nxt.dayofweek
    df["next_month"] = nxt.month
    df["lead_time"] = lead_time
    df["target"] = s.rolling(7, min_periods=1).mean().shift(-7)
    return df


def build_training_frame(series: pd.Series, lead_time: int) -> pd.DataFrame:
    df = _frame(series, lead_time)
    return df[FEATURE_COLS + ["target"]].dropna()


def build_latest_features(series: pd.Series, lead_time: int) -> pd.DataFrame:
    """Satu baris fitur untuk memprediksi permintaan besok."""
    df = _frame(series, lead_time)
    return df.iloc[[-1]][FEATURE_COLS].fillna(0.0)
