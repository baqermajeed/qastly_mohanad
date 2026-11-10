from fastapi import APIRouter, Depends, HTTPException, status

from app.schemas.auth import UserOut
from app.services import auth as auth_service

router = APIRouter(prefix="/payments", tags=["payments"])


@router.post("", status_code=410)
async def add_payment(
    _: UserOut = Depends(auth_service.get_current_user),
) -> None:
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="الدفعات تُضاف تلقائياً يوم 1 من كل شهر ولا تُسجَّل يدوياً",
    )


@router.patch("/{payment_id}", status_code=410)
async def update_payment(
    payment_id: str,
    _: UserOut = Depends(auth_service.get_current_user),
) -> None:
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="الدفعات تُدار تلقائياً ولا يمكن تعديلها يدوياً",
    )
