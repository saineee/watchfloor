from fastapi import FastAPI, Depends, Response, Request
from app.config import settings
from app.security import require_user
from fastapi.middleware.cors import CORSMiddleware
from app.routers.alerts import router as alerts_router
from app.routers.auth import router as auth_router
import logging
from app.metrics import HTTP_REQUEST_STATUS_CODES

from prometheus_client import generate_latest, CONTENT_TYPE_LATEST

logging.basicConfig(level=logging.INFO)
app = FastAPI()


def extract_route(request: Request):
    route = request.scope.get("route")
    route_path = route.path if route else "unmatched"
    return route_path


@app.middleware("http")
async def http_request_metric(request: Request, call_next):
    method = request.method
    try:
        response = await call_next(request)
    except Exception:
        route = extract_route(request)
        HTTP_REQUEST_STATUS_CODES.labels(status_code=500, method=method, route=route).inc()
        raise
    status_code = response.status_code
    route = extract_route(request)
    HTTP_REQUEST_STATUS_CODES.labels(status_code=status_code, method=method, route=route).inc()
    return response


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
