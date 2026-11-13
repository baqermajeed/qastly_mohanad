from datetime import date, datetime, timezone

from motor.motor_asyncio import AsyncIOMotorDatabase
from pymongo.errors import DuplicateKeyError

from app.schemas.investment import InvestmentStatus
from app.services.plan import as_date, due_date_for, installment_amount


async def apply_due_payouts(
    db: AsyncIOMotorDatabase,
    *,
    today: date | None = None,
) -> int:
    """يضيف أقساط المستثمرين المستحقة حتى اليوم للعقود النشطة."""
    today = today or date.today()
    created = 0
    cursor = db.investments.find(
        {
            "status": {
                "$nin": [
                    InvestmentStatus.completed.value,
                    InvestmentStatus.cancelled.value,
                ]
            }
        }
    )
    async for investment in cursor:
        created += await apply_due_payouts_for_investment(
            db, investment, today=today
        )
    return created


async def apply_due_payouts_for_investment(
    db: AsyncIOMotorDatabase,
    investment: dict,
    *,
    today: date | None = None,
) -> int:
    today = today or date.today()
    if investment.get("status") in (
        InvestmentStatus.completed.value,
        InvestmentStatus.cancelled.value,
    ):
        return 0
    if not investment.get("first_due_date") or investment.get("total_with_interest") is None:
        return 0

    months = int(investment["months_count"])
    first_due = as_date(investment["first_due_date"])
    total = float(investment["total_with_interest"])
    monthly = float(investment["monthly_payout"])

    existing = await db.investor_payouts.find(
        {"investment_id": investment["_id"]}
    ).to_list(None)
    existing_nos = {
        int(p["installment_no"])
        for p in existing
        if p.get("installment_no") is not None
    }

    created = 0
    now = datetime.now(timezone.utc)
    for installment_no in range(1, months + 1):
        due = due_date_for(first_due, installment_no)
        if due > today:
            break
        if installment_no in existing_nos:
            continue

        amount = installment_amount(
            financed_amount=total,
            months_count=months,
            monthly_payment=monthly,
            installment_no=installment_no,
        )
        if amount <= 0:
            continue

        try:
            await db.investor_payouts.insert_one(
                {
                    "investment_id": investment["_id"],
                    "investor_id": investment["investor_id"],
                    "amount": amount,
                    "due_date": datetime.combine(due, datetime.min.time()),
                    "installment_no": installment_no,
                    "paid": False,
                    "paid_at": None,
                    "paid_by": None,
                    "note": f"قسط استثماري — {installment_no} من {months}",
                    "created_at": now,
                }
            )
            created += 1
        except DuplicateKeyError:
            continue

    if created:
        await refresh_investment_status(db, investment["_id"])

    return created


async def refresh_investment_status(db: AsyncIOMotorDatabase, investment_id) -> None:
    investment = await db.investments.find_one({"_id": investment_id})
    if not investment:
        return
    if investment.get("status") == InvestmentStatus.cancelled.value:
        return

    months = int(investment.get("months_count") or 0)
    payouts = await db.investor_payouts.find(
        {"investment_id": investment_id}
    ).to_list(None)
    paid_count = sum(1 for p in payouts if p.get("paid"))
    now = datetime.now(timezone.utc)
    if months > 0 and paid_count >= months:
        await db.investments.update_one(
            {"_id": investment_id},
            {
                "$set": {
                    "status": InvestmentStatus.completed.value,
                    "updated_at": now,
                }
            },
        )
    elif investment.get("status") == InvestmentStatus.completed.value:
        await db.investments.update_one(
            {"_id": investment_id},
            {
                "$set": {
                    "status": InvestmentStatus.active.value,
                    "updated_at": now,
                }
            },
        )
