from fastapi import APIRouter, Depends, HTTPException, Query

from app.database import get_db
from app.schemas.investor import (
    InvestorConfirmDues,
    InvestorCreate,
    InvestorOut,
    InvestorUpdate,
)
from app.schemas.pagination import Page
from app.services import auth as auth_service
from app.services import investors as investor_service

router = APIRouter(prefix="/investors", tags=["investors"])


@router.get("", response_model=Page[InvestorOut])
async def list_investors(
    q: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    _: object = Depends(auth_service.require_admin),
) -> Page[InvestorOut]:
    return await investor_service.list_investors(
        get_db(),
        q=q,
        page=page,
        page_size=page_size,
    )


@router.post("", response_model=InvestorOut, status_code=201)
async def create_investor(
    payload: InvestorCreate,
    _: object = Depends(auth_service.require_admin),
) -> InvestorOut:
    return await investor_service.create_investor(get_db(), payload)


@router.get("/{investor_id}", response_model=InvestorOut)
async def get_investor(
    investor_id: str,
    current_user=Depends(auth_service.get_current_user),
) -> InvestorOut:
    if current_user.role == "investor" and current_user.id != investor_id:
        raise HTTPException(status_code=404, detail="المستثمر غير موجود")
    if current_user.role not in ("admin", "investor"):
        raise HTTPException(status_code=403, detail="غير مصرح")
    return await investor_service.get_investor(get_db(), investor_id)


@router.patch("/{investor_id}", response_model=InvestorOut)
async def update_investor(
    investor_id: str,
    payload: InvestorUpdate,
    _: object = Depends(auth_service.require_admin),
) -> InvestorOut:
    return await investor_service.update_investor(get_db(), investor_id, payload)


@router.post("/{investor_id}/confirm-dues", response_model=InvestorOut)
async def confirm_investor_dues(
    investor_id: str,
    payload: InvestorConfirmDues = InvestorConfirmDues(),
    current_user=Depends(auth_service.require_admin),
) -> InvestorOut:
    return await investor_service.confirm_investor_dues(
        get_db(), current_user, investor_id, payload
    )
