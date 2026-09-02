from fastapi import FastAPI, Depends
from starlette.middleware.sessions import SessionMiddleware
from app.config import settings
from app.security import require_user
from app.routers.alerts import router as alerts_router
from app.routers.auth import router as auth_router

app = FastAPI()
app.add_middleware(SessionMiddleware, secret_key=settings.secret_key, max_age=3600,
                   same_site="lax", https_only=settings.cookie_secure)
app.include_router(alerts_router, dependencies=[Depends(require_user)])
app.include_router(auth_router)


@app.get("/healthz")
def health():
    return {"status": "ok"}
