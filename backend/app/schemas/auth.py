from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=64)
    password: str = Field(..., min_length=4, max_length=128)


class UserOut(BaseModel):
    id: str
    username: str
    full_name: str
    role: str = "merchant"
    bank_percent: float | None = None
    platform_percent: float | None = None
    investor_percent: float | None = None
    active: bool = True


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
