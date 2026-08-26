from pydantic_settings import BaseSettings, SettingsConfigDict
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
env_file = BASE_DIR / ".env"

class Settings(BaseSettings):
    database_url: str
    secret_key: str
    cookie_secure: bool = True

    model_config = SettingsConfigDict(
        env_file=env_file,
        env_file_encoding="utf-8",
        case_sensitive=False
    )

settings = Settings()
