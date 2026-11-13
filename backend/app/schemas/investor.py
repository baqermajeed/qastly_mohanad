from datetime import datetime

from pydantic import BaseModel, Field, field_validator


def _normalize_phone(value: str) -> str:
    cleaned = value.strip().replace(" ", "").replace("-", "")
    if not cleaned:
        raise ValueError("رقم الهاتف غير صالح")
    return cleaned


class InvestorCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=64)
    password: str = Field(..., min_length=4, max_length=128)
    full_name: str = Field(..., min_length=2, max_length=120)
    phone: str = Field(..., min_length=7, max_length=20)
    note: str = Field(default="", max_length=300)

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, value: str) -> str:
        return _normalize_phone(value)


class InvestorUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=120)
    phone: str | None = Field(default=None, min_length=7, max_length=20)
    password: str | None = Field(default=None, min_length=4, max_length=128)
    note: str | None = Field(default=None, max_length=300)
    active: bool | None = None

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, value: str | None) -> str | None:
        if value is None:
            return value
        return _normalize_phone(value)


class InvestorOut(BaseModel):
    id: str
    username: str
    full_name: str
    phone: str = ""
    note: str = ""
    role: str = "investor"
    active: bool = True
    investments_count: int = 0
    principal_total: float = 0
    interest_total: float = 0
    total_with_interest: float = 0
    paid_amount: float = 0
    remaining_amount: float = 0
    due_this_month_amount: float = 0
    monthly_payout_total: float = 0
    created_at: datetime
