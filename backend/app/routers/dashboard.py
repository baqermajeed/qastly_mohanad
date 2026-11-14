from fastapi import APIRouter, Depends, Query

from app.database import get_db
from app.schemas.auth import UserOut
from app.schemas.dashboard import DashboardResponse
from app.services import auth as auth_service
from app.services import customers as customer_service

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("", response_model=DashboardResponse)
async def get_dashboard(
    current_user: UserOut = Depends(auth_service.get_current_user),
    month: str | None = Query(
        default=None,
        description="شهر الإحصائيات بصيغة YYYY-MM",
    ),
) -> DashboardResponse:
    return await customer_service.dashboard(
        get_db(), current_user, month=month
    )
