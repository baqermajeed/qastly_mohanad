from datetime import date, datetime
from enum import Enum

from pydantic import BaseModel, Field, field_validator


class CustomerStatus(str, Enum):
    pending = "pending"
    active = "active"
    inactive = "inactive"
    completed = "completed"
    rejected = "rejected"


def _normalize_digits(value: str) -> str:
    return value.strip().replace(" ", "").replace("-", "")


class CustomerCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=120)
    phone: str = Field(..., min_length=7, max_length=20)
    governorate: str = Field(..., min_length=2, max_length=80)
    total_amount: float = Field(..., gt=0)
    months_count: int = Field(..., gt=0, le=120)
    registration_date: date | None = None
    mastercard_number: str | None = Field(default=None, max_length=32)
    national_id: str | None = Field(default=None, max_length=32)

    @field_validator("phone")
    @classmethod
    def normalize_phone(cls, value: str) -> str:
        cleaned = _normalize_digits(value)
        if not cleaned:
            raise ValueError("رقم الهاتف غير صالح")
        return cleaned

    @field_validator("mastercard_number", "national_id")
    @classmethod
    def normalize_optional_id(cls, value: str | None) -> str:
        if value is None:
            return ""
        return _normalize_digits(value)


class CustomerUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    phone: str | None = Field(default=None, min_length=7, max_length=20)
    governorate: str | None = Field(default=None, min_length=2, max_length=80)
    mastercard_number: str | None = Field(default=None, max_length=32)
    national_id: str | None = Field(default=None, max_length=32)
    status: CustomerStatus | None = None
    confirm_password: str | None = Field(default=None, min_length=4, max_length=128)

    @field_validator("phone")
    @classmethod
    def normalize_phone(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = _normalize_digits(value)
        if not cleaned:
            raise ValueError("رقم الهاتف غير صالح")
        return cleaned

    @field_validator("mastercard_number", "national_id")
    @classmethod
    def normalize_optional_id(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _normalize_digits(value)


class PaymentOut(BaseModel):
    id: str
    amount: float
    payment_date: date
    note: str | None = None
    method: str = "auto"
    installment_no: int | None = None
    created_at: datetime


class CustomerOut(BaseModel):
    id: str
    merchant_id: str
    merchant_name: str | None = None
    name: str
    phone: str
    governorate: str
    mastercard_number: str = ""
    national_id: str = ""
    total_amount: float
    months_count: int
    registration_date: date
    bank_percent: float
    platform_percent: float
    investor_percent: float = 0
    bank_amount: float
    platform_amount: float
    investor_amount: float = 0
    financed_amount: float
    monthly_payment: float
    paid_amount: float
    remaining_amount: float
    remaining_months: int
    payments_count: int
    first_due_date: date
    next_due_date: date | None = None
    last_payment_date: date | None = None  # تاريخ القسط الأخير في جدول الخطة (ثابت)
    status: CustomerStatus
    whatsapp_url: str
    created_at: datetime


class CustomerDetailOut(CustomerOut):
    payments: list[PaymentOut] = []
