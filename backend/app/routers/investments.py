from fastapi import APIRouter, Depends, Query

from app.database import get_db
from app.schemas.investment import (
    InvestmentCreate,
    InvestmentOut,
    InvestmentStatus,
    InvestmentUpdate,
)
from app.schemas.pagination import Page
from app.services import auth as auth_service
from app.services import investments as investment_service

router = APIRouter(prefix="/investments", tags=["investments"])


@router.get("", response_model=Page[InvestmentOut])
async def list_investments(
    investor_id: str | None = Query(default=None),
    status: InvestmentStatus | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    current_user=Depends(auth_service.get_current_user),
) -> Page[InvestmentOut]:
    return await investment_service.list_investments(
        get_db(),
        current_user,
        investor_id=investor_id,
        status=status,
        page=page,
        page_size=page_size,
    )


@router.post("", response_model=InvestmentOut, status_code=201)
async def create_investment(
    payload: InvestmentCreate,
    current_user=Depends(auth_service.require_admin),
) -> InvestmentOut:
    return await investment_service.create_investment(get_db(), current_user, payload)


@router.post("/payouts/{payout_id}/confirm", response_model=InvestmentOut)
async def confirm_payout(
    payout_id: str,
    current_user=Depends(auth_service.require_admin),
) -> InvestmentOut:
    return await investment_service.confirm_payout(get_db(), current_user, payout_id)


@router.get("/{investment_id}", response_model=InvestmentOut)
async def get_investment(
    investment_id: str,
    current_user=Depends(auth_service.get_current_user),
) -> InvestmentOut:
    return await investment_service.get_investment(
        get_db(), current_user, investment_id
    )


@router.patch("/{investment_id}", response_model=InvestmentOut)
async def update_investment(
    investment_id: str,
    payload: InvestmentUpdate,
    current_user=Depends(auth_service.require_admin),
) -> InvestmentOut:
    return await investment_service.update_investment(
        get_db(), current_user, investment_id, payload
    )


@router.post("/{investment_id}/confirm-payouts", response_model=InvestmentOut)
async def confirm_due_payouts(
    investment_id: str,
    current_user=Depends(auth_service.require_admin),
) -> InvestmentOut:
    return await investment_service.confirm_due_payouts(
        get_db(), current_user, investment_id
    )
