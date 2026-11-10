from fastapi import APIRouter, Depends, Query

from app.database import get_db
from app.schemas.auth import UserOut
from app.schemas.customer import CustomerCreate, CustomerDetailOut, CustomerOut, CustomerStatus, CustomerUpdate
from app.services import auth as auth_service
from app.services import customers as customer_service

router = APIRouter(prefix="/customers", tags=["customers"])


@router.post("", response_model=CustomerOut, status_code=201)
async def create_customer(
    payload: CustomerCreate,
    current_user: UserOut = Depends(auth_service.require_merchant),
) -> CustomerOut:
    return await customer_service.create_customer(get_db(), payload, current_user)


@router.get("", response_model=list[CustomerOut])
async def list_customers(
    status: CustomerStatus | None = Query(default=None),
    merchant_id: str | None = Query(default=None),
    current_user: UserOut = Depends(auth_service.get_current_user),
) -> list[CustomerOut]:
    return await customer_service.list_customers(
        get_db(),
        current_user,
        status_filter=status,
        merchant_id=merchant_id,
    )


@router.post("/{customer_id}/approve", response_model=CustomerOut)
async def approve_customer(
    customer_id: str,
    current_user: UserOut = Depends(auth_service.require_admin),
) -> CustomerOut:
    return await customer_service.approve_customer(get_db(), customer_id, current_user)


@router.post("/{customer_id}/reject", response_model=CustomerOut)
async def reject_customer(
    customer_id: str,
    current_user: UserOut = Depends(auth_service.require_admin),
) -> CustomerOut:
    return await customer_service.reject_customer(get_db(), customer_id, current_user)


@router.get("/{customer_id}", response_model=CustomerDetailOut)
async def get_customer(
    customer_id: str,
    current_user: UserOut = Depends(auth_service.get_current_user),
) -> CustomerDetailOut:
    return await customer_service.get_customer(get_db(), customer_id, current_user)


@router.patch("/{customer_id}", response_model=CustomerOut)
async def update_customer(
    customer_id: str,
    payload: CustomerUpdate,
    current_user: UserOut = Depends(auth_service.get_current_user),
) -> CustomerOut:
    return await customer_service.update_customer(get_db(), customer_id, payload, current_user)


@router.delete("/{customer_id}", status_code=204)
async def delete_customer(
    customer_id: str,
    current_user: UserOut = Depends(auth_service.get_current_user),
) -> None:
    await customer_service.delete_customer(get_db(), customer_id, current_user)
