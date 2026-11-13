from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

from app.config import settings

client: AsyncIOMotorClient | None = None
db: AsyncIOMotorDatabase | None = None


async def connect_db() -> None:
    global client, db
    from app.services.auth import ensure_default_admin
    from app.services.auto_payments import apply_due_payments

    client = AsyncIOMotorClient(settings.mongodb_uri)
    db = client[settings.mongodb_db]
    await db.customers.create_index("phone")
    await db.customers.create_index("status")
    await db.customers.create_index("merchant_id")
    await db.payments.create_index("customer_id")
    await db.payments.create_index(
        [("customer_id", 1), ("installment_no", 1)],
        unique=True,
        sparse=True,
    )
    await db.users.create_index("username", unique=True)
    await db.users.create_index("role")
    await db.investments.create_index("investor_id")
    await db.investments.create_index("status")
    await db.investor_payouts.create_index("investment_id")
    await db.investor_payouts.create_index("investor_id")
    await db.investor_payouts.create_index(
        [("investment_id", 1), ("installment_no", 1)],
        unique=True,
        sparse=True,
    )
    await db.merchant_settlements.create_index(
        [("merchant_id", 1), ("year_month", 1)],
        unique=True,
    )
    await db.sessions.create_index("token_hash", unique=True)
    await db.sessions.create_index("expires_at", expireAfterSeconds=0)
    await ensure_default_admin(db)
    await apply_due_payments(db)
    from app.services.auto_payouts import apply_due_payouts

    await apply_due_payouts(db)


async def close_db() -> None:
    global client, db
    if client is not None:
        client.close()
    client = None
    db = None


def get_db() -> AsyncIOMotorDatabase:
    if db is None:
        raise RuntimeError("Database is not connected")
    return db
