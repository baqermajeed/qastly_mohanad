from datetime import date, datetime, timezone
import re
import secrets

from bson import ObjectId
from fastapi import HTTPException
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.schemas.auth import UserOut
from app.schemas.customer import CustomerStatus
from app.schemas.merchant import MerchantCreate, MerchantOut, MerchantUpdate
from app.schemas.pagination import Page
from app.services.auth import hash_password
from app.services.auto_payments import apply_due_payments
from app.services.plan import (
    as_date,
    installment_due_in_month,
    iter_months,
    month_key,
)


def _oid(value: str) -> ObjectId:
    if not ObjectId.is_valid(value):
        raise HTTPException(status_code=400, detail="معرّف غير صالح")
    return ObjectId(value)


def _customer_due_in_month(doc: dict, month: date) -> float:
    if doc.get("status") in (
        CustomerStatus.inactive.value,
        CustomerStatus.pending.value,
        CustomerStatus.rejected.value,
    ):
        return 0.0
    months = int(doc.get("months_count") or 0)
    monthly = float(doc.get("monthly_payment") or 0)
    first_due_raw = doc.get("first_due_date")
    if first_due_raw is None or months <= 0:
        return 0.0
    financed = float(doc.get("financed_amount") or 0)
    return installment_due_in_month(
        first_due=as_date(first_due_raw),
        months_count=months,
        monthly_payment=monthly,
        financed_amount=financed if financed > 0 else monthly * months,
        month=month,
    )


def _month_due_total(customers: list[dict], month: date) -> tuple[float, int]:
    total = 0.0
    count = 0
    for doc in customers:
        due = _customer_due_in_month(doc, month)
        if due > 0:
            total += due
            count += 1
    return round(total, 2), count


def _earliest_due_month(customers: list[dict], fallback: date) -> date:
    earliest: date | None = None
    for doc in customers:
        raw = doc.get("first_due_date")
        if raw is None:
            continue
        d = as_date(raw)
        start = date(d.year, d.month, 1)
        if earliest is None or start < earliest:
            earliest = start
    if earliest is None:
        return date(fallback.year, fallback.month, 1)
    return earliest


async def _settled_by_month(
    db: AsyncIOMotorDatabase,
    merchant_id: ObjectId,
) -> dict[str, float]:
    cursor = db.merchant_settlements.find({"merchant_id": merchant_id})
    result: dict[str, float] = {}
    async for doc in cursor:
        key = str(doc.get("year_month") or "")
        if not key:
            continue
        result[key] = float(doc.get("amount") or 0)
    return result


async def _outstanding_dues(
    db: AsyncIOMotorDatabase,
    merchant_id: ObjectId,
    customers: list[dict],
    *,
    today: date | None = None,
    created_at: date | datetime | None = None,
) -> dict:
    today = today or date.today()
    current = date(today.year, today.month, 1)
    fallback = as_date(created_at) if created_at else current
    start = _earliest_due_month(customers, fallback)
    if start > current:
        start = current

    settled_map = await _settled_by_month(db, merchant_id)
    outstanding = 0.0
    carried = 0.0
    current_due, current_count = _month_due_total(customers, current)
    current_key = month_key(current)
    current_settled = settled_map.get(current_key, 0.0)

    for month in iter_months(start, current):
        due, _ = _month_due_total(customers, month)
        key = month_key(month)
        settled = settled_map.get(key, 0.0)
        unpaid = round(max(due - settled, 0.0), 2)
        if unpaid <= 0:
            continue
        outstanding += unpaid
        if key != current_key:
            carried += unpaid

    outstanding = round(outstanding, 2)
    carried = round(carried, 2)
    confirmed = outstanding <= 0.01 and (
        current_due <= 0.01 or current_settled + 0.01 >= current_due
    )

    return {
        "due_this_month_amount": outstanding,
        "due_this_month_count": current_count,
        "due_confirmed_this_month": confirmed,
        "due_carried_amount": carried,
    }


async def _merchant_stats(
    db: AsyncIOMotorDatabase,
    merchant_id: ObjectId,
    *,
    created_at: date | datetime | None = None,
) -> dict:
    empty = {
        "customers_count": 0,
        "total_amounts": 0.0,
        "bank_amounts": 0.0,
        "platform_amounts": 0.0,
        "financed_amounts": 0.0,
        "paid_amounts": 0.0,
        "remaining_amounts": 0.0,
        "due_this_month_amount": 0.0,
        "due_this_month_count": 0,
        "due_confirmed_this_month": True,
        "due_carried_amount": 0.0,
    }

    customers = await db.customers.find({"merchant_id": merchant_id}).to_list(None)
    counted = [
        doc
        for doc in customers
        if doc.get("status")
        not in (CustomerStatus.pending.value, CustomerStatus.rejected.value)
    ]
    if not counted:
        return empty

    total_amounts = 0.0
    bank_amounts = 0.0
    platform_amounts = 0.0
    financed_amounts = 0.0

    for doc in counted:
        total_amounts += float(doc.get("total_amount") or 0)
        bank_amounts += float(doc.get("bank_amount") or 0)
        platform_amounts += float(doc.get("platform_amount") or 0)
        financed_amounts += float(doc.get("financed_amount") or 0)

    customer_ids = [doc["_id"] for doc in counted]
    pay_pipe = [
        {"$match": {"customer_id": {"$in": customer_ids}}},
        {"$group": {"_id": None, "total": {"$sum": "$amount"}}},
    ]
    pay_result = await db.payments.aggregate(pay_pipe).to_list(1)
    paid = float(pay_result[0]["total"]) if pay_result else 0.0
    dues = await _outstanding_dues(
        db,
        merchant_id,
        counted,
        created_at=created_at,
    )

    return {
        "customers_count": len(counted),
        "total_amounts": round(total_amounts, 2),
        "bank_amounts": round(bank_amounts, 2),
        "platform_amounts": round(platform_amounts, 2),
        "financed_amounts": round(financed_amounts, 2),
        "paid_amounts": round(paid, 2),
        "remaining_amounts": round(max(financed_amounts - paid, 0), 2),
        **dues,
    }


async def dashboard_due_this_month(
    db: AsyncIOMotorDatabase,
    user: UserOut,
) -> tuple[float, int]:
    """مستحقات التاجر الظاهرة في لوحة الإحصائيات (من حساب الباكند)."""
    if user.role == "merchant":
        oid = _oid(user.id)
        doc = await db.users.find_one({"_id": oid})
        stats = await _merchant_stats(
            db,
            oid,
            created_at=(doc or {}).get("created_at"),
        )
        return (
            float(stats["due_this_month_amount"]),
            int(stats["due_this_month_count"]),
        )

    # للمدير: مجموع مستحقات كل التجار غير المؤكدة
    total = 0.0
    count = 0
    cursor = db.users.find({"role": "merchant"})
    async for merchant in cursor:
        stats = await _merchant_stats(
            db,
            merchant["_id"],
            created_at=merchant.get("created_at"),
        )
        amount = float(stats["due_this_month_amount"])
        if amount <= 0:
            continue
        total += amount
        count += int(stats["due_this_month_count"])
    return round(total, 2), count


async def serialize_merchant(db: AsyncIOMotorDatabase, doc: dict) -> MerchantOut:
    stats = await _merchant_stats(
        db,
        doc["_id"],
        created_at=doc.get("created_at"),
    )
    return MerchantOut(
        id=str(doc["_id"]),
        username=doc["username"],
        full_name=doc["full_name"],
        phone=doc.get("phone") or "",
        governorate=doc.get("governorate") or "",
        address=doc.get("address") or "",
        master_card=doc.get("master_card") or "",
        role="merchant",
        bank_percent=float(doc.get("bank_percent") or 0),
        platform_percent=float(doc.get("platform_percent") or 0),
        active=bool(doc.get("active", True)),
        created_at=doc.get("created_at", datetime.now(timezone.utc)),
        **stats,
    )


async def list_merchants(
    db: AsyncIOMotorDatabase,
    *,
    q: str | None = None,
    governorate: str | None = None,
    page: int = 1,
    page_size: int = 20,
) -> Page[MerchantOut]:
    await apply_due_payments(db)
    safe_page = max(1, int(page or 1))
    safe_size = min(max(1, int(page_size or 20)), 100)

    query: dict = {"role": "merchant"}
    clauses: list[dict] = []
    if governorate and governorate.strip():
        clauses.append({"governorate": governorate.strip()})
    if q and q.strip():
        rx = {"$regex": re.escape(q.strip()), "$options": "i"}
        clauses.append(
            {
                "$or": [
                    {"full_name": rx},
                    {"username": rx},
                    {"phone": rx},
                    {"governorate": rx},
                ]
            }
        )
    if clauses:
        query = {"$and": [query, *clauses]}

    cursor = db.users.find(query).sort("created_at", -1)
    merchants: list[MerchantOut] = []
    async for doc in cursor:
        merchants.append(await serialize_merchant(db, doc))

    total = len(merchants)
    start = (safe_page - 1) * safe_size
    items = merchants[start : start + safe_size]
    return Page.from_items(items, total=total, page=safe_page, page_size=safe_size)


async def create_merchant(db: AsyncIOMotorDatabase, payload: MerchantCreate) -> MerchantOut:
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
        "governorate": payload.governorate.strip(),
        "address": payload.address.strip(),
        "master_card": payload.master_card,
        "role": "merchant",
        "active": True,
        "bank_percent": float(payload.bank_percent),
        "platform_percent": float(payload.platform_percent),
        "salt": salt,
        "password_hash": hash_password(payload.password, salt),
        "created_at": now,
        "updated_at": now,
    }
    result = await db.users.insert_one(doc)
    doc["_id"] = result.inserted_id
    return await serialize_merchant(db, doc)


async def update_merchant(
    db: AsyncIOMotorDatabase,
    merchant_id: str,
    payload: MerchantUpdate,
) -> MerchantOut:
    oid = _oid(merchant_id)
    existing = await db.users.find_one({"_id": oid, "role": "merchant"})
    if not existing:
        raise HTTPException(status_code=404, detail="التاجر غير موجود")

    raw = payload.model_dump(exclude_unset=True)
    updates: dict = {}
    if "full_name" in raw and raw["full_name"]:
        updates["full_name"] = raw["full_name"].strip()
    if "phone" in raw and raw["phone"]:
        updates["phone"] = raw["phone"]
    if "governorate" in raw and raw["governorate"]:
        updates["governorate"] = raw["governorate"].strip()
    if "address" in raw and raw["address"]:
        updates["address"] = raw["address"].strip()
    if "master_card" in raw and raw["master_card"]:
        updates["master_card"] = raw["master_card"]
    if "bank_percent" in raw and raw["bank_percent"] is not None:
        updates["bank_percent"] = float(raw["bank_percent"])
    if "platform_percent" in raw and raw["platform_percent"] is not None:
        updates["platform_percent"] = float(raw["platform_percent"])
    if "active" in raw and raw["active"] is not None:
        updates["active"] = bool(raw["active"])
    if "password" in raw and raw["password"]:
        salt = secrets.token_hex(16)
        updates["salt"] = salt
        updates["password_hash"] = hash_password(raw["password"], salt)

    bank = float(updates.get("bank_percent", existing.get("bank_percent") or 0))
    platform = float(updates.get("platform_percent", existing.get("platform_percent") or 0))
    if bank + platform >= 100:
        raise HTTPException(
            status_code=400,
            detail="مجموع نسبة المصرف ونسبة المنصة يجب أن يكون أقل من 100",
        )

    if updates:
        updates["updated_at"] = datetime.now(timezone.utc)
        existing = await db.users.find_one_and_update(
            {"_id": oid},
            {"$set": updates},
            return_document=True,
        )
    return await serialize_merchant(db, existing)


async def get_merchant(db: AsyncIOMotorDatabase, merchant_id: str) -> MerchantOut:
    doc = await db.users.find_one({"_id": _oid(merchant_id), "role": "merchant"})
    if not doc:
        raise HTTPException(status_code=404, detail="التاجر غير موجود")
    return await serialize_merchant(db, doc)


async def confirm_merchant_dues(
    db: AsyncIOMotorDatabase,
    merchant_id: str,
    user: UserOut,
) -> MerchantOut:
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="تأكيد المستحقات متاح للمدير فقط")

    oid = _oid(merchant_id)
    doc = await db.users.find_one({"_id": oid, "role": "merchant"})
    if not doc:
        raise HTTPException(status_code=404, detail="التاجر غير موجود")

    await apply_due_payments(db)
    customers = await db.customers.find({"merchant_id": oid}).to_list(None)
    today = date.today()
    current = date(today.year, today.month, 1)
    fallback = as_date(doc.get("created_at") or today)
    start = _earliest_due_month(customers, fallback)
    if start > current:
        start = current

    settled_map = await _settled_by_month(db, oid)
    now = datetime.now(timezone.utc)
    total_confirmed = 0.0
    months_updated = 0

    for month in iter_months(start, current):
        due, _ = _month_due_total(customers, month)
        key = month_key(month)
        already = settled_map.get(key, 0.0)
        unpaid = round(max(due - already, 0.0), 2)
        if unpaid <= 0.01:
            continue
        await db.merchant_settlements.update_one(
            {"merchant_id": oid, "year_month": key},
            {
                "$set": {
                    "merchant_id": oid,
                    "year_month": key,
                    "amount": round(due, 2),
                    "confirmed_at": now,
                    "confirmed_by": _oid(user.id),
                    "updated_at": now,
                },
                "$setOnInsert": {"created_at": now},
            },
            upsert=True,
        )
        total_confirmed += unpaid
        months_updated += 1

    if months_updated == 0:
        raise HTTPException(
            status_code=400,
            detail="لا توجد مستحقات معلقة لتأكيدها هذا الشهر",
        )

    await db.users.update_one(
        {"_id": oid},
        {
            "$set": {
                "last_dues_confirmed_at": now,
                "last_dues_confirmed_amount": round(total_confirmed, 2),
                "updated_at": now,
            }
        },
    )
    fresh = await db.users.find_one({"_id": oid})
    return await serialize_merchant(db, fresh or doc)


def assert_customer_access(user: UserOut, customer: dict) -> None:
    if user.role == "admin":
        return
    if str(customer.get("merchant_id")) != user.id:
        raise HTTPException(status_code=404, detail="الزبون غير موجود")
