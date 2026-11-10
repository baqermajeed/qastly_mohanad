from datetime import date, datetime, timezone
import hmac

from bson import ObjectId
from fastapi import HTTPException
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.schemas.auth import UserOut
from app.schemas.customer import (
    CustomerCreate,
    CustomerDetailOut,
    CustomerOut,
    CustomerStatus,
    CustomerUpdate,
    PaymentOut,
)
from app.schemas.dashboard import DashboardResponse, DashboardStats
from app.services.auth import hash_password
from app.services.auto_payments import apply_due_payments, apply_due_payments_for_customer
from app.services.merchants import list_merchants
from app.services.plan import due_date_for, first_due_date, remaining_months, split_plan
from app.services.status import as_date, resolve_status, whatsapp_url


def _oid(value: str) -> ObjectId:
    if not ObjectId.is_valid(value):
        raise HTTPException(status_code=400, detail="معرّف غير صالح")
    return ObjectId(value)


async def _paid_amount(db: AsyncIOMotorDatabase, customer_id: ObjectId) -> float:
    pipeline = [
        {"$match": {"customer_id": customer_id}},
        {"$group": {"_id": None, "total": {"$sum": "$amount"}}},
    ]
    result = await db.payments.aggregate(pipeline).to_list(1)
    if not result:
        return 0.0
    return round(float(result[0]["total"]), 2)


async def _payments_count(db: AsyncIOMotorDatabase, customer_id: ObjectId) -> int:
    return int(await db.payments.count_documents({"customer_id": customer_id}))


async def _merchant_name(db: AsyncIOMotorDatabase, merchant_id: ObjectId | None) -> str | None:
    if merchant_id is None:
        return None
    user = await db.users.find_one({"_id": merchant_id}, {"full_name": 1})
    if not user:
        return None
    return user.get("full_name")


def _customer_scope(user: UserOut, merchant_id: str | None = None) -> dict:
    if user.role == "admin":
        if merchant_id:
            return {"merchant_id": _oid(merchant_id)}
        return {}
    return {"merchant_id": _oid(user.id)}


def _assert_access(user: UserOut, doc: dict) -> None:
    if user.role == "admin":
        return
    if str(doc.get("merchant_id")) != user.id:
        raise HTTPException(status_code=404, detail="الزبون غير موجود")


async def _serialize_customer(
    db: AsyncIOMotorDatabase,
    doc: dict,
    *,
    include_payments: bool = False,
) -> CustomerOut | CustomerDetailOut:
    await apply_due_payments_for_customer(db, doc)
    fresh = await db.customers.find_one({"_id": doc["_id"]})
    if fresh:
        doc = fresh

    paid = await _paid_amount(db, doc["_id"])
    count = await _payments_count(db, doc["_id"])
    financed = float(doc.get("financed_amount") or 0)
    months = int(doc["months_count"])
    month_pay = float(doc.get("monthly_payment") or 0)
    remaining = round(max(financed - paid, 0), 2)
    remaining_m = remaining_months(remaining, month_pay)
    customer_status = resolve_status(
        remaining_amount=remaining,
        stored_status=doc.get("status"),
    )
    first_due = as_date(doc["first_due_date"]) if doc.get("first_due_date") else first_due_date(as_date(doc["registration_date"]))
    next_due = None
    if (
        remaining > 0
        and count < months
        and customer_status == CustomerStatus.active
    ):
        next_due = due_date_for(first_due, count + 1)

    if doc.get("status") != customer_status.value:
        await db.customers.update_one(
            {"_id": doc["_id"]},
            {"$set": {"status": customer_status.value, "updated_at": datetime.now(timezone.utc)}},
        )

    base = {
        "id": str(doc["_id"]),
        "merchant_id": str(doc.get("merchant_id") or ""),
        "merchant_name": await _merchant_name(db, doc.get("merchant_id")),
        "name": doc["name"],
        "phone": doc["phone"],
        "governorate": doc["governorate"],
        "mastercard_number": str(doc.get("mastercard_number") or ""),
        "national_id": str(doc.get("national_id") or ""),
        "total_amount": float(doc["total_amount"]),
        "months_count": months,
        "registration_date": as_date(doc["registration_date"]),
        "bank_percent": float(doc.get("bank_percent") or 0),
        "platform_percent": float(doc.get("platform_percent") or 0),
        "bank_amount": float(doc.get("bank_amount") or 0),
        "platform_amount": float(doc.get("platform_amount") or 0),
        "financed_amount": financed,
        "monthly_payment": month_pay,
        "paid_amount": paid,
        "remaining_amount": remaining,
        "remaining_months": remaining_m,
        "payments_count": count,
        "first_due_date": first_due,
        "next_due_date": next_due,
        "status": customer_status,
        "whatsapp_url": whatsapp_url(doc["phone"]),
        "created_at": doc.get("created_at", datetime.now(timezone.utc)),
    }

    if not include_payments:
        return CustomerOut(**base)

    payments_cursor = db.payments.find({"customer_id": doc["_id"]}).sort("installment_no", 1)
    payments: list[PaymentOut] = []
    async for payment in payments_cursor:
        payments.append(
            PaymentOut(
                id=str(payment["_id"]),
                amount=float(payment["amount"]),
                payment_date=as_date(payment.get("payment_date") or payment.get("due_date")),
                note=payment.get("note"),
                method=payment.get("method") or "auto",
                installment_no=payment.get("installment_no"),
                created_at=payment.get("created_at", datetime.now(timezone.utc)),
            )
        )
    return CustomerDetailOut(**base, payments=payments)


async def create_customer(
    db: AsyncIOMotorDatabase,
    payload: CustomerCreate,
    user: UserOut,
) -> CustomerOut:
    if user.role != "merchant":
        raise HTTPException(status_code=403, detail="إضافة الزبائن متاحة للتاجر فقط")
    if user.bank_percent is None or user.platform_percent is None:
        raise HTTPException(status_code=400, detail="حساب التاجر بلا نسب عمولة، راجع مدير المنصة")
    if user.bank_percent + user.platform_percent >= 100:
        raise HTTPException(status_code=400, detail="نسب العمولة غير صالحة")

    now = datetime.now(timezone.utc)
    # تاريخ ووقت التسجيل دائماً من وقت الخادم الفعلي
    reg_date = now.date()
    plan = split_plan(
        total_amount=float(payload.total_amount),
        months_count=int(payload.months_count),
        bank_percent=float(user.bank_percent),
        platform_percent=float(user.platform_percent),
    )
    if plan["financed_amount"] <= 0:
        raise HTTPException(status_code=400, detail="المبلغ المتبقي للتقسيط يجب أن يكون أكبر من صفر")

    first_due = first_due_date(reg_date)
    doc = {
        "merchant_id": _oid(user.id),
        "name": payload.name.strip(),
        "phone": payload.phone,
        "governorate": payload.governorate.strip(),
        "mastercard_number": payload.mastercard_number or "",
        "national_id": payload.national_id or "",
        "total_amount": float(payload.total_amount),
        "months_count": int(payload.months_count),
        "registration_date": now,
        "bank_percent": float(user.bank_percent),
        "platform_percent": float(user.platform_percent),
        "bank_amount": plan["bank_amount"],
        "platform_amount": plan["platform_amount"],
        "financed_amount": plan["financed_amount"],
        "monthly_payment": plan["monthly_payment"],
        "first_due_date": datetime.combine(first_due, datetime.min.time()),
        "status": CustomerStatus.active.value,
        "created_at": now,
        "updated_at": now,
    }
    result = await db.customers.insert_one(doc)
    doc["_id"] = result.inserted_id
    return await _serialize_customer(db, doc)  # type: ignore[return-value]


async def list_customers(
    db: AsyncIOMotorDatabase,
    user: UserOut,
    *,
    status_filter: CustomerStatus | None = None,
    merchant_id: str | None = None,
) -> list[CustomerOut]:
    await apply_due_payments(db)
    query = _customer_scope(user, merchant_id)
    cursor = db.customers.find(query).sort("created_at", -1)
    customers: list[CustomerOut] = []
    async for doc in cursor:
        item = await _serialize_customer(db, doc)
        if status_filter is None or item.status == status_filter:
            customers.append(item)  # type: ignore[arg-type]
    return customers


async def get_customer(
    db: AsyncIOMotorDatabase,
    customer_id: str,
    user: UserOut,
) -> CustomerDetailOut:
    doc = await db.customers.find_one({"_id": _oid(customer_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="الزبون غير موجود")
    _assert_access(user, doc)
    return await _serialize_customer(db, doc, include_payments=True)  # type: ignore[return-value]


async def update_customer(
    db: AsyncIOMotorDatabase,
    customer_id: str,
    payload: CustomerUpdate,
    user: UserOut,
) -> CustomerOut:
    oid = _oid(customer_id)
    existing = await db.customers.find_one({"_id": oid})
    if not existing:
        raise HTTPException(status_code=404, detail="الزبون غير موجود")
    _assert_access(user, existing)

    updates = {
        k: v
        for k, v in payload.model_dump(exclude_unset=True).items()
        if v is not None and k != "confirm_password"
    }
    if "name" in updates:
        updates["name"] = updates["name"].strip()
    if "governorate" in updates:
        updates["governorate"] = updates["governorate"].strip()
    if "phone" in updates:
        updates["phone"] = updates["phone"].strip().replace(" ", "").replace("-", "")
    if "mastercard_number" in updates and updates["mastercard_number"] is not None:
        updates["mastercard_number"] = str(updates["mastercard_number"]).strip()
    if "national_id" in updates and updates["national_id"] is not None:
        updates["national_id"] = str(updates["national_id"]).strip()
    if "status" in updates and updates["status"] is not None:
        if user.role != "admin":
            raise HTTPException(
                status_code=403,
                detail="تعديل حالة الخطة متاح لمدير المنصة فقط",
            )
        new_status = updates["status"]
        if isinstance(new_status, CustomerStatus):
            updates["status"] = new_status.value
        paid = await _paid_amount(db, oid)
        financed = float(existing.get("financed_amount") or 0)
        remaining = round(max(financed - paid, 0), 2)
        if remaining <= 0 and updates["status"] != CustomerStatus.completed.value:
            raise HTTPException(
                status_code=400,
                detail="هذه الخطة مكتملة السداد ولا يمكن تغيير حالتها إلا كمكتملة",
            )
        if updates["status"] == CustomerStatus.completed.value and remaining > 0.01:
            raise HTTPException(
                status_code=400,
                detail="لا يمكن تعليم الخطة كمكتملة وهناك مبالغ متبقية",
            )
        if updates["status"] == CustomerStatus.inactive.value:
            current = existing.get("status")
            if current != CustomerStatus.inactive.value:
                password = (payload.confirm_password or "").strip()
                if not password:
                    raise HTTPException(
                        status_code=400,
                        detail="أدخل كلمة مرور حسابك لتأكيد تعليم الخطة غير نشطة",
                    )
                admin_doc = await db.users.find_one({"_id": _oid(user.id)})
                if not admin_doc:
                    raise HTTPException(status_code=401, detail="تعذر التحقق من الحساب")
                expected = admin_doc.get("password_hash", "")
                actual = hash_password(password, admin_doc.get("salt", ""))
                if not hmac.compare_digest(str(expected), str(actual)):
                    raise HTTPException(
                        status_code=401,
                        detail="كلمة المرور غير صحيحة",
                    )

    if updates:
        updates["updated_at"] = datetime.now(timezone.utc)
        result = await db.customers.find_one_and_update(
            {"_id": oid},
            {"$set": updates},
            return_document=True,
        )
    else:
        result = existing

    if not result:
        raise HTTPException(status_code=404, detail="الزبون غير موجود")
    return await _serialize_customer(db, result)  # type: ignore[return-value]


async def delete_customer(
    db: AsyncIOMotorDatabase,
    customer_id: str,
    user: UserOut,
) -> None:
    oid = _oid(customer_id)
    existing = await db.customers.find_one({"_id": oid})
    if not existing:
        raise HTTPException(status_code=404, detail="الزبون غير موجود")
    _assert_access(user, existing)
    await db.customers.delete_one({"_id": oid})
    await db.payments.delete_many({"customer_id": oid})


async def dashboard(db: AsyncIOMotorDatabase, user: UserOut) -> DashboardResponse:
    await apply_due_payments(db)
    customers = await list_customers(db, user)
    merchants = await list_merchants(db) if user.role == "admin" else []

    total_customers = len(customers)
    completed_count = sum(1 for c in customers if c.status == CustomerStatus.completed)
    inactive_count = sum(1 for c in customers if c.status == CustomerStatus.inactive)
    active_count = sum(1 for c in customers if c.status == CustomerStatus.active)
    remaining_count = active_count + inactive_count
    total_amounts = round(sum(c.total_amount for c in customers), 2)
    paid_amounts = round(sum(c.paid_amount for c in customers), 2)
    remaining_amounts = round(sum(c.remaining_amount for c in customers), 2)
    bank_amounts = round(sum(c.bank_amount for c in customers), 2)
    platform_amounts = round(sum(c.platform_amount for c in customers), 2)
    financed_amounts = round(sum(c.financed_amount for c in customers), 2)

    return DashboardResponse(
        stats=DashboardStats(
            total_customers=total_customers,
            completed_count=completed_count,
            remaining_count=remaining_count,
            late_count=inactive_count,
            total_amounts=total_amounts,
            paid_amounts=paid_amounts,
            remaining_amounts=remaining_amounts,
            bank_amounts=bank_amounts,
            platform_amounts=platform_amounts,
            financed_amounts=financed_amounts,
            merchants_count=len(merchants),
        ),
        customers=customers,
        merchants=merchants,
        role=user.role,
    )
