from datetime import datetime

from pydantic import BaseModel, Field, field_validator, model_validator


def _normalize_phone(value: str) -> str:
    cleaned = value.strip().replace(" ", "").replace("-", "")
    if not cleaned:
        raise ValueError("رقم الهاتف غير صالح")
    return cleaned


def _normalize_master(value: str) -> str:
    cleaned = value.strip().replace(" ", "").replace("-", "")
    if not cleaned:
        raise ValueError("رقم الماستر غير صالح")
    if not cleaned.isdigit():
        raise ValueError("رقم الماستر يجب أن يحتوي على أرقام فقط")
    if len(cleaned) < 8 or len(cleaned) > 19:
        raise ValueError("رقم الماستر غير صالح")
    return cleaned


class MerchantCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=64)
    password: str = Field(..., min_length=4, max_length=128)
    full_name: str = Field(..., min_length=2, max_length=120)
    phone: str = Field(..., min_length=7, max_length=20)
    governorate: str = Field(..., min_length=2, max_length=80)
    address: str = Field(..., min_length=2, max_length=200)
    master_card: str = Field(..., min_length=8, max_length=19)
    bank_percent: float = Field(..., ge=0, lt=100)
    platform_percent: float = Field(..., ge=0, lt=100)

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, value: str) -> str:
        return _normalize_phone(value)

    @field_validator("master_card")
    @classmethod
    def validate_master(cls, value: str) -> str:
        return _normalize_master(value)

    @model_validator(mode="after")
    def percents_must_leave_remainder(self) -> "MerchantCreate":
        if self.bank_percent + self.platform_percent >= 100:
            raise ValueError("مجموع نسبة المصرف ونسبة المنصة يجب أن يكون أقل من 100")
        return self


class MerchantUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=120)
    phone: str | None = Field(default=None, min_length=7, max_length=20)
    governorate: str | None = Field(default=None, min_length=2, max_length=80)
    address: str | None = Field(default=None, min_length=2, max_length=200)
    master_card: str | None = Field(default=None, min_length=8, max_length=19)
    password: str | None = Field(default=None, min_length=4, max_length=128)
    bank_percent: float | None = Field(default=None, ge=0, lt=100)
    platform_percent: float | None = Field(default=None, ge=0, lt=100)
    active: bool | None = None

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, value: str | None) -> str | None:
        if value is None:
            return value
        return _normalize_phone(value)

    @field_validator("master_card")
    @classmethod
    def validate_master(cls, value: str | None) -> str | None:
        if value is None:
            return value
        return _normalize_master(value)

    @model_validator(mode="after")
    def percents_must_leave_remainder(self) -> "MerchantUpdate":
        if (
            self.bank_percent is not None
            and self.platform_percent is not None
            and self.bank_percent + self.platform_percent >= 100
        ):
            raise ValueError("مجموع نسبة المصرف ونسبة المنصة يجب أن يكون أقل من 100")
        return self


class MerchantOut(BaseModel):
    id: str
    username: str
    full_name: str
    phone: str = ""
    governorate: str = ""
    address: str = ""
    master_card: str = ""
    role: str = "merchant"
    bank_percent: float
    platform_percent: float
    active: bool = True
    customers_count: int = 0
    total_amounts: float = 0
    bank_amounts: float = 0
    platform_amounts: float = 0
    financed_amounts: float = 0
    paid_amounts: float = 0
    remaining_amounts: float = 0
    due_this_month_amount: float = 0
    due_this_month_count: int = 0
    due_confirmed_this_month: bool = False
    due_carried_amount: float = 0
    created_at: datetime
