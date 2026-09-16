from fastapi import FastAPI, Depends
from app.config import settings
from app.security import require_user
from fastapi.middleware.cors import CORSMiddleware
from app.routers.alerts import router as alerts_router
from app.routers.auth import router as auth_router
import logging

logging.basicConfig(level=logging.INFO)
app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins = settings.cors_origins, allow_credentials = True, allow_methods = ["PATCH", "GET", "POST", "OPTIONS"], allow_headers = ["Accept", "Accept-Language", "Content-Type"])
app.include_router(alerts_router, dependencies=[Depends(require_user)])
app.include_router(auth_router)


@app.get("/healthz")
def health():
    return {"status": "ok"}
