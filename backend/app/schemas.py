from pydantic import BaseModel, ConfigDict, EmailStr, Field
from typing import Annotated
from datetime import datetime
from app.models import Severity, AlertStatus

class AlertBase(BaseModel):
    error_type: str
    device_name: str
    ip_address: str
    description: str
    device_state: str
    location: str | None = None
    device_last_available: datetime | None = None

class AlertCreate(AlertBase):
    pass

class AlertRead(AlertBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: datetime
    status: AlertStatus
    severity: Severity | None = None
    summary: str | None = None
    occurrence_count: int
    last_occurrence: datetime | None = None

class AlertUpdate(BaseModel):
    status: AlertStatus | None = None
    severity: Severity | None = None
    summary: str | None = None

class UserCreate(BaseModel):
    email: EmailStr
    password: Annotated[str, Field(min_length=12)]

class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    email: EmailStr
    created_at: datetime

class UserLogin(BaseModel):
    email: EmailStr
    password: str
