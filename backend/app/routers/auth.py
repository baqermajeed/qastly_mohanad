from fastapi import APIRouter, Depends
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.database import get_db
from app.schemas.auth import LoginRequest, LoginResponse, UserOut
from app.services import auth as auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=LoginResponse)
async def login(
    payload: LoginRequest,
    db: AsyncIOMotorDatabase = Depends(get_db),
) -> LoginResponse:
    return await auth_service.login(db, payload)


@router.get("/me", response_model=UserOut)
async def me(current_user: UserOut = Depends(auth_service.get_current_user)) -> UserOut:
    return current_user


@router.post("/logout", status_code=204)
async def logout(
    db: AsyncIOMotorDatabase = Depends(get_db),
    token: str | None = Depends(auth_service.get_optional_token),
) -> None:
    await auth_service.logout(db, token)
