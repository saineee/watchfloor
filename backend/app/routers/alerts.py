from datetime import datetime, timezone
from typing import Annotated

from app.llm import hash_input, triage
from sqlalchemy.exc import IntegrityError

from sqlalchemy import select
from app.database import get_db
from app.models import Alert, AlertStatus
from fastapi import Depends, Query, HTTPException, APIRouter, Response
from sqlalchemy.ext.asyncio import AsyncSession
from app.schemas import AlertCreate, AlertRead, AlertUpdate

router = APIRouter(prefix="/alerts", tags=["alerts"])

@router.post("", response_model=AlertRead)
async def create_alert(alert: AlertCreate, db: AsyncSession = Depends(get_db), response: Response = None ):
    alert_data = alert.model_dump()
    stmt = select(Alert).where(Alert.device_name == alert_data["device_name"],
                               Alert.error_type == alert_data["error_type"],
                               Alert.status != AlertStatus.resolved)
    result = await db.execute(stmt)
    existing_alert = result.scalar_one_or_none()
    if not existing_alert:
        db_alert = Alert(**alert_data)
        db.add(db_alert)
        try:
            await db.commit()
            await db.refresh(db_alert)
            response.status_code = 201
            return db_alert
        # IntegrityError may occur because a concurrent request inserted the same
        # device and error type between select and commit, and db constraint caught it, falls through to the bump below on purpose
        except IntegrityError:
            await db.rollback()
            result = await db.execute(stmt)
            existing_alert = result.scalar_one_or_none()
            if not existing_alert:
                raise HTTPException(status_code=409, detail="Alert resolved during race, retry")

    existing_alert.occurrence_count += 1
    existing_alert.last_occurrence = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(existing_alert)
    response.status_code = 200
    return existing_alert

@router.get("", response_model=list[AlertRead])
async def list_alerts(limit: Annotated[int, Query(ge=1, le=100)] = 50, offset: Annotated[int, Query(ge=0)] = 0, db: AsyncSession = Depends(get_db)):
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

    data = alert_update.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(alert, key, value)

    await db.commit()
    await db.refresh(alert)
    return alert

@router.post("/{alert_id}/triage", response_model=AlertRead)
async def triage_alert(alert_id: int, db: AsyncSession = Depends(get_db)):
    alert = await db.get(Alert, alert_id)
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    fingerprint = hash_input(alert)
    if fingerprint != alert.triage_source_hash:
        result = await triage(alert)
        alert.summary = result.summary
        alert.severity = result.severity
        alert.triage_source_hash = fingerprint
        await db.commit()
        await db.refresh(alert)
    return alert
