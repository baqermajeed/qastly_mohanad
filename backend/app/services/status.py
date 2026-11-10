from datetime import date, datetime

from app.schemas.customer import CustomerStatus
from app.services.plan import remaining_months as plan_remaining_months


def remaining_months(
    remaining_amount: float,
    month_payment: float,
    *,
    months_count: int | None = None,
    payments_count: int | None = None,
) -> int:
    return plan_remaining_months(
        remaining_amount,
        month_payment,
        months_count=months_count,
        payments_count=payments_count,
    )


def normalize_status(value: str | None) -> CustomerStatus:
    """يدعم القيم القديمة paid/late للتوافق مع البيانات السابقة."""
    if value == CustomerStatus.pending.value:
        return CustomerStatus.pending
    if value == CustomerStatus.rejected.value:
        return CustomerStatus.rejected
    if value in (CustomerStatus.active.value, "paid", "late"):
        # late القديمة = متأخرة وليست ملغاة
        return CustomerStatus.active
    if value in (CustomerStatus.inactive.value, "canceled", "cancelled"):
        return CustomerStatus.inactive
    if value == CustomerStatus.completed.value:
        return CustomerStatus.completed
    return CustomerStatus.active


def resolve_status(
    *,
    remaining_amount: float,
    stored_status: str | None,
) -> CustomerStatus:
    """
    - الطلبات المعلقة/المرفوضة تبقى كما هي (لا احتساب)
    - إذا اكتمل السداد → مكتملة دائماً
    - إذا كانت ملغاة/غير نشطة → تبقى كذلك
    - غير ذلك → نشطة
    """
    current = normalize_status(stored_status)
    if current in (CustomerStatus.pending, CustomerStatus.rejected):
        return current
    if remaining_amount <= 0:
        return CustomerStatus.completed
    if current == CustomerStatus.inactive:
        return CustomerStatus.inactive
    return CustomerStatus.active


def whatsapp_url(phone: str) -> str:
    digits = "".join(ch for ch in phone if ch.isdigit() or ch == "+")
    if digits.startswith("0"):
        digits = "964" + digits[1:]
    digits = digits.lstrip("+")
    return f"https://wa.me/{digits}"


def as_date(value: date | datetime) -> date:
    if isinstance(value, datetime):
        return value.date()
    return value
