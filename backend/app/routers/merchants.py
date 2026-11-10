from fastapi import APIRouter, Depends

from app.database import get_db
from app.schemas.merchant import MerchantCreate, MerchantOut, MerchantUpdate
from app.services import auth as auth_service
from app.services import merchants as merchant_service

router = APIRouter(prefix="/merchants", tags=["merchants"])


@router.get("", response_model=list[MerchantOut])
async def list_merchants(
    _: object = Depends(auth_service.require_admin),
) -> list[MerchantOut]:
    return await merchant_service.list_merchants(get_db())


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
