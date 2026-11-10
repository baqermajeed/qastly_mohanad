from fastapi import APIRouter, Depends, Query

from app.database import get_db
from app.schemas.merchant import MerchantCreate, MerchantOut, MerchantUpdate
from app.schemas.pagination import Page
from app.services import auth as auth_service
from app.services import merchants as merchant_service

router = APIRouter(prefix="/merchants", tags=["merchants"])


@router.get("", response_model=Page[MerchantOut])
async def list_merchants(
    q: str | None = Query(default=None),
    governorate: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    _: object = Depends(auth_service.require_admin),
) -> Page[MerchantOut]:
    return await merchant_service.list_merchants(
        get_db(),
        q=q,
        governorate=governorate,
        page=page,
        page_size=page_size,
    )


@router.post("", response_model=MerchantOut, status_code=201)
async def create_merchant(
    payload: MerchantCreate,
    _: object = Depends(auth_service.require_admin),
) -> MerchantOut:
    return await merchant_service.create_merchant(get_db(), payload)


@router.get("/{merchant_id}", response_model=MerchantOut)
async def get_merchant(
    merchant_id: str,
    _: object = Depends(auth_service.require_admin),
) -> MerchantOut:
    return await merchant_service.get_merchant(get_db(), merchant_id)


@router.patch("/{merchant_id}", response_model=MerchantOut)
async def update_merchant(
    merchant_id: str,
    payload: MerchantUpdate,
    _: object = Depends(auth_service.require_admin),
) -> MerchantOut:
    return await merchant_service.update_merchant(get_db(), merchant_id, payload)


@router.post("/{merchant_id}/confirm-dues", response_model=MerchantOut)
async def confirm_merchant_dues(
    merchant_id: str,
    current_user=Depends(auth_service.require_admin),
) -> MerchantOut:
    return await merchant_service.confirm_merchant_dues(
        get_db(),
        merchant_id,
        current_user,
    )
