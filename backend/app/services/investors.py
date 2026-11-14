from datetime import date, datetime, timezone
import re
import secrets

from bson import ObjectId
from fastapi import HTTPException
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.schemas.investment import InvestmentStatus
from app.schemas.investor import (
    InvestorConfirmDues,
    InvestorCreate,
    InvestorOut,
    InvestorUpdate,
)
from app.schemas.pagination import Page
from app.services.auth import hash_password
from app.services.auto_payouts import apply_due_payouts, refresh_investment_status
from app.services.plan import as_date, installment_due_in_month, month_key


def _oid(value: str) -> ObjectId:
    if not ObjectId.is_valid(value):
        raise HTTPException(status_code=400, detail="معرّف غير صالح")
    return ObjectId(value)


def _investment_due_in_month(doc: dict, month: date) -> float:
    if doc.get("status") != InvestmentStatus.active.value:
        return 0.0
    months = int(doc.get("months_count") or 0)
    monthly = float(doc.get("monthly_payout") or 0)
    first_due_raw = doc.get("first_due_date")
    if first_due_raw is None or months <= 0:
        return 0.0
    total = float(doc.get("total_with_interest") or 0)
    return installment_due_in_month(
        first_due=as_date(first_due_raw),
        months_count=months,
        monthly_payment=monthly,
        financed_amount=total if total > 0 else monthly * months,
        month=month,
    )


async def _settled_in_month(
    db: AsyncIOMotorDatabase,
    investor_id: ObjectId,
    month: date,
) -> float:
    key = month_key(month)
    doc = await db.investor_settlements.find_one(
        {"investor_id": investor_id, "year_month": key}
    )
    return float((doc or {}).get("amount") or 0)


async def _investor_stats(db: AsyncIOMotorDatabase, investor_id: ObjectId) -> dict:
    empty = {
        "investments_count": 0,
        "principal_total": 0.0,
        "interest_total": 0.0,
        "total_with_interest": 0.0,
        "paid_amount": 0.0,
        "remaining_amount": 0.0,
        "due_this_month_amount": 0.0,
        "monthly_payout_total": 0.0,
    }

    await apply_due_payouts(db)
    investments = await db.investments.find(
        {
            "investor_id": investor_id,
            "status": {"$ne": InvestmentStatus.cancelled.value},
        }
    ).to_list(None)
    if not investments:
        return empty

    principal_total = 0.0
    interest_total = 0.0
    total_with_interest = 0.0
    monthly_payout_total = 0.0
    due_this_month = 0.0
    today = date.today()
    current = date(today.year, today.month, 1)

    for doc in investments:
        principal_total += float(doc.get("principal") or 0)
        interest_total += float(doc.get("interest_amount") or 0)
        total_with_interest += float(doc.get("total_with_interest") or 0)
        if doc.get("status") == InvestmentStatus.active.value:
            monthly_payout_total += float(doc.get("monthly_payout") or 0)
            due_this_month += _investment_due_in_month(doc, current)

    investment_ids = [doc["_id"] for doc in investments]
    pay_pipe = [
        {
            "$match": {
                "investment_id": {"$in": investment_ids},
                "paid": True,
            }
        },
        {"$group": {"_id": None, "total": {"$sum": "$amount"}}},
    ]
    pay_result = await db.investor_payouts.aggregate(pay_pipe).to_list(1)
    paid = float(pay_result[0]["total"]) if pay_result else 0.0

    paid_due_this_month = 0.0
    if investment_ids:
        async for p in db.investor_payouts.find(
            {"investment_id": {"$in": investment_ids}, "paid": True}
        ):
            due_raw = p.get("due_date")
            if due_raw is None:
                continue
            due = as_date(due_raw)
            if date(due.year, due.month, 1) == current:
                paid_due_this_month += float(p.get("amount") or 0)

    settled = await _settled_in_month(db, investor_id, current)
    due_this_month = max(due_this_month - paid_due_this_month - settled, 0.0)

    return {
        "investments_count": len(investments),
        "principal_total": round(principal_total, 2),
        "interest_total": round(interest_total, 2),
        "total_with_interest": round(total_with_interest, 2),
        "paid_amount": round(paid, 2),
        "remaining_amount": round(max(total_with_interest - paid, 0), 2),
        "due_this_month_amount": round(due_this_month, 2),
        "monthly_payout_total": round(monthly_payout_total, 2),
    }


async def serialize_investor(db: AsyncIOMotorDatabase, doc: dict) -> InvestorOut:
    stats = await _investor_stats(db, doc["_id"])
    return InvestorOut(
        id=str(doc["_id"]),
        username=doc["username"],
        full_name=doc["full_name"],
        phone=doc.get("phone") or "",
        master_card=doc.get("master_card") or "",
        note=doc.get("note") or "",
        role="investor",
        active=bool(doc.get("active", True)),
        created_at=doc.get("created_at", datetime.now(timezone.utc)),
        **stats,
    )


async def list_investors(
    db: AsyncIOMotorDatabase,
    *,
    q: str | None = None,
    page: int = 1,
    page_size: int = 20,
) -> Page[InvestorOut]:
    await apply_due_payouts(db)
    safe_page = max(1, int(page or 1))
    safe_size = min(max(1, int(page_size or 20)), 100)

    query: dict = {"role": "investor"}
    if q and q.strip():
        rx = {"$regex": re.escape(q.strip()), "$options": "i"}
        query = {
            "$and": [
                query,
                {
                    "$or": [
                        {"full_name": rx},
                        {"username": rx},
                        {"phone": rx},
                    ]
                },
            ]
        }

    cursor = db.users.find(query).sort("created_at", -1)
    investors: list[InvestorOut] = []
    async for doc in cursor:
        investors.append(await serialize_investor(db, doc))

    total = len(investors)
    start = (safe_page - 1) * safe_size
    items = investors[start : start + safe_size]
    return Page.from_items(items, total=total, page=safe_page, page_size=safe_size)


async def create_investor(db: AsyncIOMotorDatabase, payload: InvestorCreate) -> InvestorOut:
    username = payload.username.strip().lower()
    existing = await db.users.find_one({"username": username})
    if existing:
        raise HTTPException(status_code=400, detail="اسم المستخدم مستخدم مسبقاً")

    salt = secrets.token_hex(16)
    now = datetime.now(timezone.utc)
    doc = {
        "username": username,
        "full_name": payload.full_name.strip(),
        "phone": payload.phone,
        "master_card": payload.master_card,
        "note": (payload.note or "").strip(),
        "role": "investor",
        "active": True,
        "salt": salt,
        "password_hash": hash_password(payload.password, salt),
        "created_at": now,
        "updated_at": now,
    }
    result = await db.users.insert_one(doc)
    doc["_id"] = result.inserted_id
    return await serialize_investor(db, doc)


async def update_investor(
    db: AsyncIOMotorDatabase,
    investor_id: str,
    payload: InvestorUpdate,
) -> InvestorOut:
    oid = _oid(investor_id)
    existing = await db.users.find_one({"_id": oid, "role": "investor"})
    if not existing:
        raise HTTPException(status_code=404, detail="المستثمر غير موجود")

    raw = payload.model_dump(exclude_unset=True)
    updates: dict = {}
    if "full_name" in raw and raw["full_name"]:
        updates["full_name"] = raw["full_name"].strip()
    if "phone" in raw and raw["phone"]:
        updates["phone"] = raw["phone"]
    if "master_card" in raw and raw["master_card"]:
        updates["master_card"] = raw["master_card"]
    if "note" in raw and raw["note"] is not None:
        updates["note"] = str(raw["note"]).strip()
    if "active" in raw and raw["active"] is not None:
        updates["active"] = bool(raw["active"])
    if "password" in raw and raw["password"]:
        salt = secrets.token_hex(16)
        updates["salt"] = salt
        updates["password_hash"] = hash_password(raw["password"], salt)

    if updates:
        updates["updated_at"] = datetime.now(timezone.utc)
        existing = await db.users.find_one_and_update(
            {"_id": oid},
            {"$set": updates},
            return_document=True,
        )
    return await serialize_investor(db, existing)


async def get_investor(db: AsyncIOMotorDatabase, investor_id: str) -> InvestorOut:
    doc = await db.users.find_one({"_id": _oid(investor_id), "role": "investor"})
    if not doc:
        raise HTTPException(status_code=404, detail="المستثمر غير موجود")
    return await serialize_investor(db, doc)


async def dashboard_investor_stats(
    db: AsyncIOMotorDatabase,
    *,
    month: date | None = None,
) -> dict:
    """إحصائيات مجمّعة للمستثمرين والعقود — للوحة المدير."""
    await apply_due_payouts(db)
    investors_count = int(await db.users.count_documents({"role": "investor"}))
    investments = await db.investments.find(
        {"status": {"$ne": InvestmentStatus.cancelled.value}}
    ).to_list(None)

    principal_total = 0.0
    interest_total = 0.0
    total_with_interest = 0.0
    due_this_month = 0.0
    today = date.today()
    current = date((month or today).year, (month or today).month, 1)

    for doc in investments:
        principal_total += float(doc.get("principal") or 0)
        interest_total += float(doc.get("interest_amount") or 0)
        total_with_interest += float(doc.get("total_with_interest") or 0)
        due_this_month += _investment_due_in_month(doc, current)

    investment_ids = [doc["_id"] for doc in investments]
    paid = 0.0
    if investment_ids:
        pay_pipe = [
            {
                "$match": {
                    "investment_id": {"$in": investment_ids},
                    "paid": True,
                }
            },
            {"$group": {"_id": None, "total": {"$sum": "$amount"}}},
        ]
        pay_result = await db.investor_payouts.aggregate(pay_pipe).to_list(1)
        paid = float(pay_result[0]["total"]) if pay_result else 0.0

    # استبعاد أقساط الشهر المحدد المدفوعة مسبقاً من المستحق الظاهر
    if investment_ids:
        paid_this_month_cursor = db.investor_payouts.find(
            {
                "investment_id": {"$in": investment_ids},
                "paid": True,
            }
        )
        paid_due_this_month = 0.0
        async for p in paid_this_month_cursor:
            due_raw = p.get("due_date")
            if due_raw is None:
                continue
            due = as_date(due_raw)
            if date(due.year, due.month, 1) == current:
                paid_due_this_month += float(p.get("amount") or 0)
        due_this_month = max(due_this_month - paid_due_this_month, 0.0)

    key = month_key(current)
    settled_pipe = [
        {"$match": {"year_month": key}},
        {"$group": {"_id": None, "total": {"$sum": "$amount"}}},
    ]
    settled_result = await db.investor_settlements.aggregate(settled_pipe).to_list(1)
    settled = float(settled_result[0]["total"]) if settled_result else 0.0
    due_this_month = max(due_this_month - settled, 0.0)

    return {
        "investors_count": investors_count,
        "investments_count": len(investments),
        "investor_principal_total": round(principal_total, 2),
        "investor_total_with_interest": round(total_with_interest, 2),
        "investor_paid_amount": round(paid, 2),
        "investor_remaining_amount": round(max(total_with_interest - paid, 0), 2),
        "investor_due_this_month_amount": round(due_this_month, 2),
    }


async def confirm_investor_dues(
    db: AsyncIOMotorDatabase,
    user,
    investor_id: str,
    payload: InvestorConfirmDues | None = None,
) -> InvestorOut:
    """تسديد مستحقات المستثمر هذا الشهر — كلياً أو جزئياً.

    يُعلَّم ما يكفي من أقساط الشهر المستحقة كمصروف (FIFO)،
    وأي متبقٍ من مبلغ التسديد يُسجَّل كرصيد تسديد للشهر.
    """
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="تسديد المستحقات متاح للمدير فقط")

    await apply_due_payouts(db)
    oid = _oid(investor_id)
    doc = await db.users.find_one({"_id": oid, "role": "investor"})
    if not doc:
        raise HTTPException(status_code=404, detail="المستثمر غير موجود")

    stats = await _investor_stats(db, oid)
    outstanding = float(stats["due_this_month_amount"])
    if outstanding <= 0.01:
        raise HTTPException(status_code=400, detail="لا توجد مستحقات معلقة لتأكيدها")

    pay = outstanding
    if payload is not None and payload.amount is not None:
        pay = round(float(payload.amount), 2)
        if pay <= 0:
            raise HTTPException(status_code=400, detail="مبلغ التسديد يجب أن يكون أكبر من صفر")
        if pay > outstanding + 0.01:
            raise HTTPException(
                status_code=400,
                detail=f"مبلغ التسديد أكبر من المستحقات المتبقية ({outstanding})",
            )
        pay = min(pay, outstanding)

    today = date.today()
    current = date(today.year, today.month, 1)
    now = datetime.now(timezone.utc)

    unpaid = await db.investor_payouts.find(
        {"investor_id": oid, "paid": False}
    ).sort([("due_date", 1), ("installment_no", 1)]).to_list(None)

    remaining = pay
    touched_investments: set[ObjectId] = set()
    for payout in unpaid:
        if remaining <= 0.01:
            break
        due_raw = payout.get("due_date")
        if due_raw is None:
            continue
        due = as_date(due_raw)
        if date(due.year, due.month, 1) != current:
            continue
        amount = float(payout.get("amount") or 0)
        if amount <= 0:
            continue
        if remaining + 0.01 >= amount:
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
            remaining = round(remaining - amount, 2)
            inv_id = payout.get("investment_id")
            if inv_id is not None:
                touched_investments.add(inv_id)

    if remaining > 0.01:
        key = month_key(current)
        existing = await db.investor_settlements.find_one(
            {"investor_id": oid, "year_month": key}
        )
        already = float((existing or {}).get("amount") or 0)
        await db.investor_settlements.update_one(
            {"investor_id": oid, "year_month": key},
            {
                "$set": {
                    "investor_id": oid,
                    "year_month": key,
                    "amount": round(already + remaining, 2),
                    "confirmed_at": now,
                    "confirmed_by": _oid(user.id),
                    "updated_at": now,
                },
                "$setOnInsert": {"created_at": now},
            },
            upsert=True,
        )

    for inv_id in touched_investments:
        await refresh_investment_status(db, inv_id)

    return await serialize_investor(db, doc)
