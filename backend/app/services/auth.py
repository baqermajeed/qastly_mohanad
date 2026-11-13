from __future__ import annotations

import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import Depends, Header, HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.config import settings
from app.database import get_db
from app.schemas.auth import LoginRequest, LoginResponse, UserOut

PBKDF2_ITERATIONS = 120_000


def hash_password(password: str, salt: str) -> str:
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        PBKDF2_ITERATIONS,
    )
    return digest.hex()


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def user_out(doc: dict) -> UserOut:
    return UserOut(
        id=str(doc["_id"]),
        username=doc["username"],
        full_name=doc["full_name"],
        role=doc.get("role", "merchant"),
        bank_percent=doc.get("bank_percent"),
        platform_percent=doc.get("platform_percent"),
        active=bool(doc.get("active", True)),
    )


async def ensure_default_admin(db: AsyncIOMotorDatabase) -> None:
    username = settings.default_admin_username.strip().lower()
    existing = await db.users.find_one({"username": username})
    if existing:
        return

    salt = secrets.token_hex(16)
    await db.users.insert_one(
        {
            "username": username,
            "full_name": settings.default_admin_name,
            "role": "admin",
            "active": True,
            "salt": salt,
            "password_hash": hash_password(settings.default_admin_password, salt),
            "created_at": datetime.now(timezone.utc),
        }
    )


async def login(db: AsyncIOMotorDatabase, payload: LoginRequest) -> LoginResponse:
    username = payload.username.strip().lower()
    user = await db.users.find_one({"username": username})
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="اسم المستخدم أو كلمة المرور غير صحيحة",
        )

    if not user.get("active", True):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="هذا الحساب موقوف، تواصل مع مدير المنصة",
        )

    expected = user["password_hash"]
    actual = hash_password(payload.password, user["salt"])
    if not hmac.compare_digest(expected, actual):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="اسم المستخدم أو كلمة المرور غير صحيحة",
        )

    token = secrets.token_urlsafe(32)
    expires_at = datetime.now(timezone.utc) + timedelta(hours=settings.auth_token_ttl_hours)
    await db.sessions.insert_one(
        {
            "token_hash": _hash_token(token),
            "user_id": user["_id"],
            "created_at": datetime.now(timezone.utc),
            "expires_at": expires_at,
        }
    )

    return LoginResponse(access_token=token, user=user_out(user))


async def logout(db: AsyncIOMotorDatabase, token: str | None) -> None:
    if not token:
        return
    await db.sessions.delete_one({"token_hash": _hash_token(token)})


async def get_user_by_token(db: AsyncIOMotorDatabase, token: str) -> UserOut:
    session = await db.sessions.find_one({"token_hash": _hash_token(token)})
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="جلسة غير صالحة، سجّل الدخول مجدداً",
        )

    expires_at = session["expires_at"]
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at < datetime.now(timezone.utc):
        await db.sessions.delete_one({"_id": session["_id"]})
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="انتهت صلاحية الجلسة، سجّل الدخول مجدداً",
        )

    user = await db.users.find_one({"_id": session["user_id"]})
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="المستخدم غير موجود",
        )
    if not user.get("active", True):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="هذا الحساب موقوف، تواصل مع مدير المنصة",
        )
    return user_out(user)


def _extract_bearer(authorization: str | None) -> str | None:
    if not authorization:
        return None
    parts = authorization.split(" ", 1)
    if len(parts) != 2 or parts[0].lower() != "bearer" or not parts[1].strip():
        return None
    return parts[1].strip()


async def get_current_user(
    authorization: str | None = Header(default=None),
    db: AsyncIOMotorDatabase = Depends(get_db),
) -> UserOut:
    token = _extract_bearer(authorization)
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="يجب تسجيل الدخول أولاً",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return await get_user_by_token(db, token)


async def require_admin(
    current_user: UserOut = Depends(get_current_user),
) -> UserOut:
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="هذه العملية متاحة لمدير المنصة فقط",
        )
    return current_user


async def require_merchant(
    current_user: UserOut = Depends(get_current_user),
) -> UserOut:
    if current_user.role != "merchant":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="هذه العملية متاحة للتاجر فقط",
        )
    return current_user


async def require_investor(
    current_user: UserOut = Depends(get_current_user),
) -> UserOut:
    if current_user.role != "investor":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="هذه العملية متاحة للمستثمر فقط",
        )
    return current_user


async def get_optional_token(
    authorization: str | None = Header(default=None),
) -> str | None:
    return _extract_bearer(authorization)
