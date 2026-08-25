from sqlalchemy import select
from app.database import get_db
from fastapi import FastAPI, Depends, Query
from typing import Annotated
from sqlalchemy.ext.asyncio import AsyncSession
from app.schemas import AlertRead, AlertCreate
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
