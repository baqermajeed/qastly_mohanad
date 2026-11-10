import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import close_db, connect_db, get_db
from app.routers import auth, customers, dashboard, merchants, payments


async def _auto_payment_loop() -> None:
    from app.services.auto_payments import apply_due_payments

    while True:
        try:
            await apply_due_payments(get_db())
        except Exception:
            pass
        await asyncio.sleep(60)


@asynccontextmanager
async def lifespan(_: FastAPI):
    await connect_db()
    task = asyncio.create_task(_auto_payment_loop())
    try:
        yield
    finally:
        task.cancel()
        await close_db()


app = FastAPI(
    title="Qasatly Mohanad API",
    description="منصة أقساط: مدير المنصة والتجار وخطط الزبائن",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api")
app.include_router(merchants.router, prefix="/api")
app.include_router(customers.router, prefix="/api")
app.include_router(payments.router, prefix="/api")
app.include_router(dashboard.router, prefix="/api")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
