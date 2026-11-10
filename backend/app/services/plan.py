from datetime import date, datetime
from math import ceil


def as_date(value: date | datetime) -> date:
    if isinstance(value, datetime):
        return value.date()
    return value


def add_months(start: date, months: int) -> date:
    month_index = start.month - 1 + months
    year = start.year + month_index // 12
    month = month_index % 12 + 1
    return date(year, month, 1)


def month_key(value: date | datetime) -> str:
    d = as_date(value)
    return f"{d.year:04d}-{d.month:02d}"


def iter_months(start: date, end: date):
    """يولد أول يوم من كل شهر من start إلى end inclusive."""
    current = date(start.year, start.month, 1)
    last = date(end.year, end.month, 1)
    while current <= last:
        yield current
        current = add_months(current, 1)


def first_due_date(registration_date: date) -> date:
    """أول دفعة دائماً يوم 1 من الشهر التالي لتاريخ التسجيل."""
    return add_months(date(registration_date.year, registration_date.month, 1), 1)


def split_plan(
    *,
    total_amount: float,
    months_count: int,
    bank_percent: float,
    platform_percent: float,
) -> dict[str, float]:
    total = round(float(total_amount), 2)
    bank_amount = round(total * float(bank_percent) / 100.0, 2)
    platform_amount = round(total * float(platform_percent) / 100.0, 2)
    financed_amount = round(total - bank_amount - platform_amount, 2)
    monthly_payment = round(financed_amount / months_count, 2)
    return {
        "bank_amount": bank_amount,
        "platform_amount": platform_amount,
        "financed_amount": financed_amount,
        "monthly_payment": monthly_payment,
    }


def installment_amount(
    *,
    financed_amount: float,
    months_count: int,
    monthly_payment: float,
    installment_no: int,
) -> float:
    if installment_no < months_count:
        return round(monthly_payment, 2)
    return round(financed_amount - monthly_payment * (months_count - 1), 2)


def remaining_months(remaining_amount: float, month_payment: float) -> int:
    if remaining_amount <= 0 or month_payment <= 0:
        return 0
    return int(ceil(remaining_amount / month_payment))


def due_date_for(first_due: date, installment_no: int) -> date:
    return add_months(first_due, installment_no - 1)


def installment_due_in_month(
    *,
    first_due: date,
    months_count: int,
    monthly_payment: float,
    financed_amount: float,
    month: date | None = None,
) -> float:
    """مبلغ القسط المستحق في شهر معيّن (افتراضياً الشهر الحالي)."""
    if months_count <= 0:
        return 0.0
    month = month or date.today()
    target = date(month.year, month.month, 1)
    start = date(first_due.year, first_due.month, 1)
    months_diff = (target.year - start.year) * 12 + (target.month - start.month)
    if months_diff < 0 or months_diff >= months_count:
        return 0.0
    installment_no = months_diff + 1
    return installment_amount(
        financed_amount=financed_amount,
        months_count=months_count,
        monthly_payment=monthly_payment,
        installment_no=installment_no,
    )
