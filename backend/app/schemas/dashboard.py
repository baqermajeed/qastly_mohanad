from pydantic import BaseModel

from app.schemas.customer import CustomerOut
from app.schemas.merchant import MerchantOut


class DashboardStats(BaseModel):
    total_customers: int
    completed_count: int
    remaining_count: int
    late_count: int = 0
    pending_count: int = 0
    total_amounts: float
    paid_amounts: float
    remaining_amounts: float
    bank_amounts: float = 0
    platform_amounts: float = 0
    financed_amounts: float = 0
    merchants_count: int = 0
    due_this_month_amount: float = 0
    due_this_month_count: int = 0
    investors_count: int = 0
    investments_count: int = 0
    investor_principal_total: float = 0
    investor_total_with_interest: float = 0
    investor_paid_amount: float = 0
    investor_remaining_amount: float = 0
    investor_due_this_month_amount: float = 0


class DashboardResponse(BaseModel):
    stats: DashboardStats
    customers: list[CustomerOut]
    merchants: list[MerchantOut] = []
    role: str
