from pathlib import Path
from app.schemas import TriageResult
from app.models import Severity
from unittest.mock import AsyncMock
import httpx
from app.main import app
from sqlalchemy import text
import pytest
from alembic import command
from alembic.config import Config
from app.config import settings
from app.models import Base
from sqlalchemy.engine import make_url
from app.database import engine

url = make_url(settings.database_url)
BASE_DIR = Path(__file__).resolve().parent.parent
alembic_ini = BASE_DIR / "alembic.ini"

test_user = {"email": "test@gmail.com", "password": "1234891231k12"}

if not url.database.endswith("_test"):
    raise ValueError(f"refusing to run against {url.database}, the name must end in _test")

@pytest.fixture(scope="session", autouse=True)
def apply_migrations():
    alembic_cfg = Config(str(alembic_ini))
    command.upgrade(alembic_cfg, "head")

@pytest.fixture(scope="function", autouse=True)
async def truncate_db():

    yield

    async with engine.begin() as conn:
        for table in Base.metadata.sorted_tables:
            await conn.execute(text(f'TRUNCATE TABLE "{table.name}" RESTART IDENTITY CASCADE;'))

@pytest.fixture(scope="function", autouse=False)
async def client():
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:

        yield client

@pytest.fixture(scope="function", autouse=False)
async def auth_client(client):
    response = await client.post(
        "/auth/register",
        json=test_user
    )
    assert response.status_code == 201
    response = await client.post(
        "/auth/login",
        json=test_user
    )
    assert response.status_code == 200
    return client

@pytest.fixture(scope="function", autouse=False)
def mock_triage(monkeypatch):
    mock_result = TriageResult(severity=Severity.p1, summary="test summary")
    mock_async_func = AsyncMock(return_value=mock_result)
    monkeypatch.setattr("app.routers.alerts.triage", mock_async_func)
    return mock_async_func

@pytest.fixture(scope="function", autouse=False)
def alert_payload():
    return {
    "error_type": "ESX Host down",
    "device_name": "dallas.esx.host03",
    "ip_address": "172.16.17.32",
    "description": "alarm: host connection and power state red",
    "device_state": "down",
    "location": "dallas",
    "device_last_available": None}

