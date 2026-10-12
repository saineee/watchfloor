from datetime import datetime, timezone
import time
from typing import Annotated
import anthropic
import pydantic
from app.llm import hash_input, triage
from app.metrics import ALERTS_INGESTED, TRIAGE_DURATION, TRIAGE_OUTCOMES
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy import select
from app.database import get_db
from app.models import Alert, AlertStatus, ALLOWED_TRANSITIONS
from fastapi import Depends, Query, HTTPException, APIRouter, Response
from sqlalchemy.ext.asyncio import AsyncSession
from app.schemas import AlertCreate, AlertRead, AlertUpdate
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/alerts", tags=["alerts"])


def _resolve_check(alert: Alert):
    if alert.status == AlertStatus.resolved:
        raise HTTPException(status_code=409, detail="Resolved alerts cannot be modified")


@router.post("", response_model=AlertRead)
async def create_alert(alert: AlertCreate, db: AsyncSession = Depends(get_db), response: Response = None):
    alert_data = alert.model_dump()
    stmt = select(Alert).where(Alert.device_name == alert_data["device_name"],
                               Alert.error_type == alert_data["error_type"],
                               Alert.status != AlertStatus.resolved)
    result = await db.execute(stmt)
    existing_alert = result.scalar_one_or_none()
    ingest_result = "deduped"
    if not existing_alert:
        db_alert = Alert(**alert_data)
        db.add(db_alert)
        try:
            await db.commit()
            await db.refresh(db_alert)
            ingest_result = "created"
            ALERTS_INGESTED.labels(result=ingest_result).inc()
            response.status_code = 201
            return db_alert
        # IntegrityError may occur because a concurrent request inserted the same
        # device and error type between select and commit, and db constraint caught it, falls through to the bump below on purpose
        except IntegrityError:
            await db.rollback()
            result = await db.execute(stmt)
            existing_alert = result.scalar_one_or_none()
            ingest_result = "raced"
            logger.info("raced", extra={"error_type": alert_data["error_type"], "device_name": alert_data["device_name"]})
            if not existing_alert:
                ingest_result = "race_resolved"
                ALERTS_INGESTED.labels(result=ingest_result).inc()
                logger.warning("race_resolved", extra={"error_type": alert_data["error_type"], "device_name": alert_data["device_name"]})
                raise HTTPException(status_code=409, detail="Alert resolved during race, retry")

    existing_alert.occurrence_count += 1
    existing_alert.last_occurrence = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(existing_alert)
    response.status_code = 200
    ALERTS_INGESTED.labels(result=ingest_result).inc()
    return existing_alert


@router.get("", response_model=list[AlertRead])
async def list_alerts(limit: Annotated[int, Query(ge=1, le=100)] = 50, offset: Annotated[int, Query(ge=0)] = 0,
                      db: AsyncSession = Depends(get_db)):
    stmt = select(Alert).limit(limit).offset(offset).order_by(Alert.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{alert_id}", response_model=AlertRead)
async def get_alert(alert_id: int, db: AsyncSession = Depends(get_db)):
    alert = await db.get(Alert, alert_id)
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    return alert


@router.patch("/{alert_id}", response_model=AlertRead)
async def update_alert(alert_id: int, alert_update: AlertUpdate, db: AsyncSession = Depends(get_db)):
    alert = await db.get(Alert, alert_id)
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    _resolve_check(alert)

    data = alert_update.model_dump(exclude_unset=True)
    new_status = data.get("status")
    if new_status is not None:
        if new_status != alert.status and new_status not in ALLOWED_TRANSITIONS[alert.status]:
            raise HTTPException(status_code=409,
                                detail=f"cannot transition from {alert.status.value} to {new_status.value}.")

    for key, value in data.items():
        setattr(alert, key, value)

    await db.commit()
    await db.refresh(alert)
    return alert


@router.post("/{alert_id}/triage", response_model=AlertRead)
async def triage_alert(alert_id: int, db: AsyncSession = Depends(get_db)):
    alert = await db.get(Alert, alert_id)
    triage_outcome = "skipped"
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    _resolve_check(alert)
    fingerprint = hash_input(alert)
    if fingerprint != alert.triage_source_hash:
        start = time.perf_counter()
        try:
            result = await triage(alert)
        except anthropic.RateLimitError:
            logger.exception("Rate limit exceeded for alert", extra={"alert_id":alert_id})
            triage_outcome = "failed"
            TRIAGE_OUTCOMES.labels(outcome=triage_outcome).inc()
            raise HTTPException(status_code=503, detail="Rate limit exceeded")
        except anthropic.InternalServerError:
            logger.exception("Internal server error for alert", extra={"alert_id": alert_id})
            triage_outcome = "failed"
            TRIAGE_OUTCOMES.labels(outcome=triage_outcome).inc()
            raise HTTPException(status_code=503, detail="Internal server error")
        except anthropic.APIStatusError:
            logger.exception("Api status error for alert", extra={"alert_id": alert_id})
            triage_outcome = "failed"
            TRIAGE_OUTCOMES.labels(outcome=triage_outcome).inc()
            raise HTTPException(status_code=502, detail="API status error")
        except anthropic.APIConnectionError:
            logger.exception("Connection error for alert", extra={"alert_id": alert_id})
            triage_outcome = "failed"
            TRIAGE_OUTCOMES.labels(outcome=triage_outcome).inc()
            raise HTTPException(status_code=503, detail="Connection error")
        except pydantic.ValidationError:
            logger.exception("Validation error for alert", extra={"alert_id": alert_id})
            triage_outcome = "failed"
            TRIAGE_OUTCOMES.labels(outcome=triage_outcome).inc()
            raise HTTPException(status_code=502, detail="Validation error")
        TRIAGE_DURATION.observe(time.perf_counter() - start)
        alert.summary = result.summary
        alert.severity = result.severity
        alert.triage_source_hash = fingerprint
        try:
            await db.commit()
        except SQLAlchemyError:
            await db.rollback()
            triage_outcome = "failed"
            TRIAGE_OUTCOMES.labels(outcome=triage_outcome).inc()
            logger.exception("Database error for alert", extra={"alert_id": alert_id})
            raise HTTPException(status_code=503, detail="Database error: problem committing to database")
        triage_outcome = "completed"
        TRIAGE_OUTCOMES.labels(outcome=triage_outcome).inc()
        await db.refresh(alert)
    else:
        logger.info("Alert is already triaged", extra={"alert_id": alert_id})
        TRIAGE_OUTCOMES.labels(outcome=triage_outcome).inc()
    return alert
