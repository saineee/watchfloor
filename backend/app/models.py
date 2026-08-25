from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
import enum
from sqlalchemy import func, DateTime
from datetime import datetime

class Base(DeclarativeBase):
    pass

class AlertStatus(enum.Enum):
    new = "new"
    in_progress = "in_progress"
    escalated = "escalated"
    resolved = "resolved"

class Severity(enum.Enum):
    p1 = "P1"
    p2 = "P2"
    p3 = "P3"
    p4 = "P4"
    p5 = "P5"

class Alert(Base):
    __tablename__ = "alerts"
    id : Mapped[int] = mapped_column(primary_key=True)
    error_type: Mapped[str]
    device_name: Mapped[str]
    status: Mapped[AlertStatus] = mapped_column(default=AlertStatus.new)
    ip_address: Mapped[str]
    device_last_available: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    occurrence_count: Mapped[int] = mapped_column(default=1)
    device_state: Mapped[str]
    last_occurrence: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    severity: Mapped[Severity | None]
    description: Mapped[str]
    summary: Mapped[str | None]
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    location: Mapped[str | None]

