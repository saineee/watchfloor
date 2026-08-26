from sqlalchemy import select
from app.database import get_db
from fastapi import FastAPI, Depends, Query, HTTPException
from typing import Annotated
from sqlalchemy.ext.asyncio import AsyncSession
from app.schemas import AlertRead, AlertCreate, AlertUpdate
from app.models import Alert

app = FastAPI()

@app.get("/healthz")
def health():
    return {"status": "ok"}

@app.post("/alerts", response_model=AlertRead, status_code=201)
async def create_alert(alert: AlertCreate, db: AsyncSession = Depends(get_db)):
    alert_data = alert.model_dump()
    db_alert = Alert(**alert_data)
    db.add(db_alert)
    await db.commit()
    await db.refresh(db_alert)
    return db_alert

@app.get("/alerts", response_model=list[AlertRead])
async def get_alerts(limit: Annotated[int, Query(ge=1, le=100)] = 50, offset: Annotated[int, Query(ge=0)] = 0, db: AsyncSession = Depends(get_db)):
    stmt = select(Alert).limit(limit).offset(offset).order_by(Alert.created_at.desc())
    result = await db.execute(stmt)
    return result.scalars().all()

@app.get("/alerts/{alert_id}", response_model=AlertRead)
async def get_alert(alert_id: int, db: AsyncSession = Depends(get_db)):
    alert = await db.get(Alert, alert_id)
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    return alert

@app.patch("/alerts/{alert_id}", response_model=AlertRead)
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
