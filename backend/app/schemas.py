from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator
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
    last_occurrence: datetime


class AlertUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    status: AlertStatus | None = None
    description: str | None = None
    location: str | None = None
    device_state: str | None = None
    ip_address: str | None = None
    device_last_available: datetime | None = None
    severity: Severity | None = None
    summary: str | None = None

    @field_validator("status", "description", "device_state", "ip_address")
    @classmethod
    def validate_fields(cls, v):
        if v is None:
            raise ValueError("field cannot be set to null")
        return v


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


class TriageResult(BaseModel):
    model_config = ConfigDict(extra="forbid")
    severity: Severity = Field(description="P1 is service outage affecting multiple customers;"
                                           " P2 is an outage for a single customer with significant business impact, "
                                           "or degradation affecting multiple; P3 is degradation affecting a single customer, "
                                           "needs escalation to a higher team; P4 is an alert or incident with no immediate escalation, "
                                           "goes to a queue; P5 is a service or info request. When the number of affected customers cannot be determined from the alert, assume higher priority. "
                                           "More than 1 affected customer is automatic priority 1 when paired with hard down, use this information for other priorities. Occurrence count alone does not raise priority.")
    summary: str = Field(max_length=300,
                         description="Summary of the problem containing the device, error type, problem, and whether the issue is impacting others. "
                                     "Response should be one line and 300 characters or less.")
