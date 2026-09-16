from fastapi import FastAPI, Depends, Response
from app.config import settings
from app.security import require_user
from fastapi.middleware.cors import CORSMiddleware
from app.routers.alerts import router as alerts_router
from app.routers.auth import router as auth_router
import logging

from prometheus_client import generate_latest, CONTENT_TYPE_LATEST

logging.basicConfig(level=logging.INFO)
app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins, allow_credentials=True,
                   allow_methods=["PATCH", "GET", "POST", "OPTIONS"],
                   allow_headers=["Accept", "Accept-Language", "Content-Type"])
app.include_router(alerts_router, dependencies=[Depends(require_user)])
app.include_router(auth_router)


@app.get("/healthz")
def health():
    return {"status": "ok"}


@app.get("/metrics")
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)
