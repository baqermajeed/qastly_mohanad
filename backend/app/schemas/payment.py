from datetime import date
from typing import Literal

from pydantic import BaseModel, Field

PaymentMethod = Literal["cash", "card"]


class PaymentCreate(BaseModel):
    customer_id: str
    amount: float | None = Field(default=None, gt=0)
    payment_date: date | None = None
    note: str | None = Field(default=None, max_length=300)
    method: PaymentMethod | None = None


class PaymentUpdate(BaseModel):
    amount: float | None = Field(default=None, gt=0)
    payment_date: date | None = None
    note: str | None = Field(default=None, max_length=300)
    method: PaymentMethod | None = None
