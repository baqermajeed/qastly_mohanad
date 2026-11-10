from datetime import date, datetime, timezone

from motor.motor_asyncio import AsyncIOMotorDatabase
from pymongo.errors import DuplicateKeyError

from app.schemas.customer import CustomerStatus
from app.services.plan import as_date, due_date_for, installment_amount


async def apply_due_payments(
    db: AsyncIOMotorDatabase,
    *,
    today: date | None = None,
) -> int:
    """يضيف الدفعات المستحقة حتى اليوم للخطط النشطة فقط."""
    today = today or date.today()
    created = 0
    cursor = db.customers.find(
        {
            "status": {
                "$nin": [
                    CustomerStatus.completed.value,
                    CustomerStatus.inactive.value,
                ]
            }
        }
    )
    async for customer in cursor:
        created += await apply_due_payments_for_customer(db, customer, today=today)
    return created


async def apply_due_payments_for_customer(
    db: AsyncIOMotorDatabase,
    customer: dict,
    *,
    today: date | None = None,
) -> int:
    today = today or date.today()
    status = customer.get("status")
    if status in (
        CustomerStatus.completed.value,
        CustomerStatus.inactive.value,
    ):
        return 0
    if not customer.get("first_due_date") or customer.get("financed_amount") is None:
        return 0
    months = int(customer["months_count"])
    first_due = as_date(customer["first_due_date"])
    financed = float(customer["financed_amount"])
    monthly = float(customer["monthly_payment"])

    existing = await db.payments.find({"customer_id": customer["_id"]}).to_list(None)
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
            financed_amount=financed,
            months_count=months,
            monthly_payment=monthly,
            installment_no=installment_no,
        )
        if amount <= 0:
            continue

        try:
            await db.payments.insert_one(
                {
                    "customer_id": customer["_id"],
                    "amount": amount,
                    "payment_date": datetime.combine(due, datetime.min.time()),
                    "due_date": datetime.combine(due, datetime.min.time()),
                    "installment_no": installment_no,
                    "method": "auto",
                    "note": f"دفعة شهرية تلقائية — القسط {installment_no} من {months}",
                    "created_at": now,
                }
            )
            created += 1
        except DuplicateKeyError:
            continue

    if created:
        paid_docs = await db.payments.find({"customer_id": customer["_id"]}).to_list(None)
        paid = round(sum(float(p["amount"]) for p in paid_docs), 2)
        status = (
            CustomerStatus.completed.value
            if paid + 0.01 >= financed
            else CustomerStatus.active.value
        )
        await db.customers.update_one(
            {"_id": customer["_id"]},
            {"$set": {"status": status, "updated_at": now}},
        )

    return created
