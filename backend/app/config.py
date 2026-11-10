from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    mongodb_uri: str = "mongodb://localhost:27017"
    mongodb_db: str = "qasatly_mohanad"
    app_host: str = "0.0.0.0"
    app_port: int = 8000
    # الجلسة على الفرونت غير دائمة؛ التوكن قصير العمر كطبقة أمان إضافية
    auth_token_ttl_hours: int = 12
    default_admin_username: str = "admin"
    default_admin_password: str = "admin123"
    default_admin_name: str = "مهند"


settings = Settings()
