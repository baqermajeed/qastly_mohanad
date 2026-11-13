from datetime import date, datetime
from enum import Enum

from pydantic import BaseModel, Field


class InvestmentStatus(str, Enum):
    active = "active"
    completed = "completed"
    cancelled = "cancelled"


class InvestmentCreate(BaseModel):
    investor_id: str = Field(..., min_length=1)
    principal: float = Field(..., gt=0)
    interest_percent: float = Field(..., ge=0, le=100)
    months_count: int = Field(..., gt=0, le=120)
    start_date: date | None = None
    note: str = Field(default="", max_length=300)


class InvestmentUpdate(BaseModel):
    note: str | None = Field(default=None, max_length=300)
    status: InvestmentStatus | None = None


class PayoutOut(BaseModel):
    id: str
    investment_id: str
    investor_id: str
    amount: float
    installment_no: int
    due_date: date
    paid: bool = False
    paid_at: datetime | None = None
    note: str | None = None
    created_at: datetime


class InvestmentOut(BaseModel):
    id: str
    investor_id: str
    investor_name: str | None = None
    principal: float
    interest_percent: float
    interest_amount: float
    total_with_interest: float
    months_count: int
    monthly_payout: float
    start_date: date
    first_due_date: date
    status: InvestmentStatus
    note: str = ""
    paid_amount: float = 0
    remaining_amount: float = 0
    remaining_months: int = 0
    due_this_month_amount: float = 0
    payouts: list[PayoutOut] = []
    created_at: datetime
    updated_at: datetime | None = None
