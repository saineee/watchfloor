from pydantic import SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
env_file = BASE_DIR / ".env"


class Settings(BaseSettings):
    database_url: str
    secret_key: str
    cookie_secure: bool = True
    anthropic_api_key: SecretStr | None = None
    anthropic_workspace_id: str | None = None
    anthropic_federation_rule_id: str | None = None
    anthropic_organization_id: str | None = None
    anthropic_service_account_id: str | None = None

    model_config = SettingsConfigDict(
        env_file=env_file,
        env_file_encoding="utf-8",
        case_sensitive=False
    )

    @model_validator(mode="after")
    def check_auth_configured(self):
        if self.anthropic_api_key or (self.anthropic_federation_rule_id and
                                      self.anthropic_organization_id and self.anthropic_service_account_id):
            return self
        raise ValueError("Missing api key, or organization_id, service_account_id, federation_rule_id")


settings = Settings()
