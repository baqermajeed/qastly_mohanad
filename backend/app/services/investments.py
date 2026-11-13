from datetime import date, datetime, timezone

from bson import ObjectId
from fastapi import HTTPException
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.schemas.auth import UserOut
from app.schemas.investment import (
    InvestmentCreate,
    InvestmentOut,
    InvestmentStatus,
    InvestmentUpdate,
    PayoutOut,
)
from app.schemas.pagination import Page
from app.services.auto_payouts import (
    apply_due_payouts,
    apply_due_payouts_for_investment,
    refresh_investment_status,
)
from app.services.plan import (
    as_date,
    first_due_date,
    installment_due_in_month,
    remaining_months,
    split_investment,
)


def _oid(value: str) -> ObjectId:
    if not ObjectId.is_valid(value):
        raise HTTPException(status_code=400, detail="معرّف غير صالح")
    return ObjectId(value)


def _assert_access(user: UserOut, investment: dict) -> None:
    if user.role == "admin":
        return
    if user.role == "investor" and str(investment.get("investor_id")) == user.id:
        return
    raise HTTPException(status_code=404, detail="عقد الاستثمار غير موجود")


def _payout_out(doc: dict) -> PayoutOut:
    due = as_date(doc["due_date"])
    return PayoutOut(
        id=str(doc["_id"]),
        investment_id=str(doc["investment_id"]),
        investor_id=str(doc["investor_id"]),
        amount=float(doc["amount"]),
        installment_no=int(doc["installment_no"]),
        due_date=due,
        paid=bool(doc.get("paid")),
        paid_at=doc.get("paid_at"),
        note=doc.get("note"),
        created_at=doc.get("created_at", datetime.now(timezone.utc)),
    )


async def serialize_investment(
    db: AsyncIOMotorDatabase,
    doc: dict,
    *,
    include_payouts: bool = True,
) -> InvestmentOut:
    payouts_docs = await db.investor_payouts.find(
        {"investment_id": doc["_id"]}
    ).sort("installment_no", 1).to_list(None)
    paid_amount = round(
        sum(float(p["amount"]) for p in payouts_docs if p.get("paid")),
        2,
    )
    total = float(doc.get("total_with_interest") or 0)
    monthly = float(doc.get("monthly_payout") or 0)
    months = int(doc.get("months_count") or 0)
    paid_count = sum(1 for p in payouts_docs if p.get("paid"))
    rem_months = remaining_months(
        max(total - paid_amount, 0),
        monthly,
        months_count=months,
        payments_count=paid_count,
    )

    today = date.today()
    due_this_month = 0.0
    if doc.get("status") == InvestmentStatus.active.value and doc.get("first_due_date"):
        due_this_month = installment_due_in_month(
            first_due=as_date(doc["first_due_date"]),
            months_count=months,
            monthly_payment=monthly,
            financed_amount=total if total > 0 else monthly * months,
            month=today,
        )
        # إذا القسط لهذا الشهر مدفوع مسبقاً لا نعرضه كمستحق
        current = date(today.year, today.month, 1)
        for p in payouts_docs:
            if not p.get("paid"):
                continue
            due = as_date(p["due_date"])
            if date(due.year, due.month, 1) == current:
                due_this_month = 0.0
                break

    investor_name = None
    investor = await db.users.find_one({"_id": doc["investor_id"]})
    if investor:
        investor_name = investor.get("full_name")

    return InvestmentOut(
        id=str(doc["_id"]),
        investor_id=str(doc["investor_id"]),
        investor_name=investor_name,
        principal=float(doc["principal"]),
        interest_percent=float(doc["interest_percent"]),
        interest_amount=float(doc["interest_amount"]),
        total_with_interest=total,
        months_count=months,
        monthly_payout=monthly,
        start_date=as_date(doc["start_date"]),
        first_due_date=as_date(doc["first_due_date"]),
        status=InvestmentStatus(doc.get("status", InvestmentStatus.active.value)),
        note=doc.get("note") or "",
        paid_amount=paid_amount,
        remaining_amount=round(max(total - paid_amount, 0), 2),
        remaining_months=rem_months,
        due_this_month_amount=round(due_this_month, 2),
        payouts=[_payout_out(p) for p in payouts_docs] if include_payouts else [],
        created_at=doc.get("created_at", datetime.now(timezone.utc)),
        updated_at=doc.get("updated_at"),
    )


async def list_investments(
    db: AsyncIOMotorDatabase,
    user: UserOut,
    *,
    investor_id: str | None = None,
    status: InvestmentStatus | None = None,
    page: int = 1,
    page_size: int = 20,
) -> Page[InvestmentOut]:
    await apply_due_payouts(db)
    safe_page = max(1, int(page or 1))
    safe_size = min(max(1, int(page_size or 20)), 100)

    query: dict = {}
    if user.role == "investor":
        query["investor_id"] = _oid(user.id)
    elif investor_id:
        query["investor_id"] = _oid(investor_id)
    elif user.role != "admin":
        raise HTTPException(status_code=403, detail="غير مصرح")

    if status is not None:
        query["status"] = status.value

    total = int(await db.investments.count_documents(query))
    cursor = (
        db.investments.find(query)
        .sort("created_at", -1)
        .skip((safe_page - 1) * safe_size)
        .limit(safe_size)
    )
    items: list[InvestmentOut] = []
    async for doc in cursor:
        items.append(await serialize_investment(db, doc, include_payouts=False))
    return Page.from_items(items, total=total, page=safe_page, page_size=safe_size)


async def get_investment(
    db: AsyncIOMotorDatabase,
    user: UserOut,
    investment_id: str,
) -> InvestmentOut:
    await apply_due_payouts(db)
    doc = await db.investments.find_one({"_id": _oid(investment_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="عقد الاستثمار غير موجود")
    _assert_access(user, doc)
    await apply_due_payouts_for_investment(db, doc)
    fresh = await db.investments.find_one({"_id": doc["_id"]}) or doc
    return await serialize_investment(db, fresh)


async def create_investment(
    db: AsyncIOMotorDatabase,
    user: UserOut,
    payload: InvestmentCreate,
) -> InvestmentOut:
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="إنشاء العقود متاح للمدير فقط")

    investor_oid = _oid(payload.investor_id)
    investor = await db.users.find_one({"_id": investor_oid, "role": "investor"})
    if not investor:
        raise HTTPException(status_code=404, detail="المستثمر غير موجود")
    if not investor.get("active", True):
        raise HTTPException(status_code=400, detail="حساب المستثمر موقوف")

    start = payload.start_date or date.today()
    split = split_investment(
        principal=payload.principal,
        interest_percent=payload.interest_percent,
        months_count=payload.months_count,
    )
    now = datetime.now(timezone.utc)
    doc = {
        "investor_id": investor_oid,
        "principal": split["principal"],
        "interest_percent": float(payload.interest_percent),
        "interest_amount": split["interest_amount"],
        "total_with_interest": split["total_with_interest"],
        "months_count": int(payload.months_count),
        "monthly_payout": split["monthly_payout"],
        "start_date": datetime.combine(start, datetime.min.time()),
        "first_due_date": datetime.combine(first_due_date(start), datetime.min.time()),
        "status": InvestmentStatus.active.value,
        "note": (payload.note or "").strip(),
        "created_by": _oid(user.id),
        "created_at": now,
        "updated_at": now,
    }
    result = await db.investments.insert_one(doc)
    doc["_id"] = result.inserted_id
    await apply_due_payouts_for_investment(db, doc)
    fresh = await db.investments.find_one({"_id": doc["_id"]}) or doc
    return await serialize_investment(db, fresh)


async def update_investment(
    db: AsyncIOMotorDatabase,
    user: UserOut,
    investment_id: str,
    payload: InvestmentUpdate,
) -> InvestmentOut:
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="تعديل العقود متاح للمدير فقط")

    oid = _oid(investment_id)
    existing = await db.investments.find_one({"_id": oid})
    if not existing:
        raise HTTPException(status_code=404, detail="عقد الاستثمار غير موجود")

    raw = payload.model_dump(exclude_unset=True)
    updates: dict = {}
    if "note" in raw and raw["note"] is not None:
        updates["note"] = str(raw["note"]).strip()
    if "status" in raw and raw["status"] is not None:
        status = raw["status"]
        if isinstance(status, InvestmentStatus):
            updates["status"] = status.value
        else:
            updates["status"] = str(status)

    if updates:
        updates["updated_at"] = datetime.now(timezone.utc)
        existing = await db.investments.find_one_and_update(
            {"_id": oid},
            {"$set": updates},
            return_document=True,
        )
    return await serialize_investment(db, existing)


async def confirm_payout(
    db: AsyncIOMotorDatabase,
    user: UserOut,
    payout_id: str,
) -> InvestmentOut:
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="تأكيد الصرف متاح للمدير فقط")

    payout = await db.investor_payouts.find_one({"_id": _oid(payout_id)})
    if not payout:
        raise HTTPException(status_code=404, detail="القسط غير موجود")
    if payout.get("paid"):
        raise HTTPException(status_code=400, detail="تم تأكيد صرف هذا القسط مسبقاً")

    now = datetime.now(timezone.utc)
    await db.investor_payouts.update_one(
        {"_id": payout["_id"]},
        {
            "$set": {
                "paid": True,
                "paid_at": now,
                "paid_by": _oid(user.id),
            }
        },
    )
    await refresh_investment_status(db, payout["investment_id"])
    investment = await db.investments.find_one({"_id": payout["investment_id"]})
    if not investment:
        raise HTTPException(status_code=404, detail="عقد الاستثمار غير موجود")
    return await serialize_investment(db, investment)


async def confirm_due_payouts(
    db: AsyncIOMotorDatabase,
    user: UserOut,
    investment_id: str,
) -> InvestmentOut:
    """يؤكد كل الأقساط المستحقة غير المدفوعة لعقد واحد."""
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="تأكيد الصرف متاح للمدير فقط")

    await apply_due_payouts(db)
    oid = _oid(investment_id)
    investment = await db.investments.find_one({"_id": oid})
    if not investment:
        raise HTTPException(status_code=404, detail="عقد الاستثمار غير موجود")

    now = datetime.now(timezone.utc)
    result = await db.investor_payouts.update_many(
        {"investment_id": oid, "paid": False},
        {
            "$set": {
                "paid": True,
                "paid_at": now,
                "paid_by": _oid(user.id),
            }
        },
    )
    if result.modified_count == 0:
        raise HTTPException(status_code=400, detail="لا توجد أقساط مستحقة للتأكيد")

    await refresh_investment_status(db, oid)
    fresh = await db.investments.find_one({"_id": oid}) or investment
    return await serialize_investment(db, fresh)
