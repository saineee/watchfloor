from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
import enum
from sqlalchemy import func, DateTime, Index, text, String, ForeignKey
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
    id: Mapped[int] = mapped_column(primary_key=True)
    error_type: Mapped[str]
    device_name: Mapped[str]
    status: Mapped[AlertStatus] = mapped_column(default=AlertStatus.new)
    ip_address: Mapped[str]
    device_last_available: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    occurrence_count: Mapped[int] = mapped_column(default=1)
    device_state: Mapped[str]
    last_occurrence: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    severity: Mapped[Severity | None]
    description: Mapped[str]
    summary: Mapped[str | None]
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    location: Mapped[str | None]
    triage_source_hash: Mapped[str | None] = mapped_column(String(64))

    __table_args__ = (
        Index('uq_open_alert_device_error',
              "device_name",
              "error_type",
              unique=True,
              postgresql_where=text("status != 'resolved'")),
    )


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(unique=True, index=True)
    password_hash: Mapped[str]
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Session(Base):
    __tablename__ = "sessions"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    token: Mapped[str] = mapped_column(unique=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
