from unittest.mock import AsyncMock

from sqlalchemy.ext.asyncio import AsyncSession

from sqlalchemy.exc import SQLAlchemyError

import anthropic
import httpx
from prometheus_client import REGISTRY

async def test_triage_test_call_count_1_carry_sev(auth_client, alert_payload, mock_triage):
    response = await auth_client.post(
        "/alerts",
        json=alert_payload
    )
    assert response.status_code == 201
    alert_id = response.json()["id"]
    response = await auth_client.post(
        f"/alerts/{alert_id}/triage"
    )
    assert mock_triage.call_count == 1
    assert response.json()["summary"] == "test summary"
    assert response.json()["severity"] == "P1"
    response = await auth_client.post(
        f"/alerts/{alert_id}/triage"
    )
    assert mock_triage.call_count == 1
    assert response.json()["id"] == alert_id
    assert response.json()["summary"] == "test summary"
    assert response.json()["severity"] == "P1"


async def test_triage_call_count_2_on_valid_re_triage(auth_client, alert_payload, mock_triage):
    response = await auth_client.post(
        "/alerts",
        json=alert_payload
    )
    assert response.status_code == 201
    alert_id = response.json()["id"]
    response = await auth_client.post(
        f"/alerts/{alert_id}/triage"
    )
    assert mock_triage.call_count == 1
    assert response.json()["summary"] == "test summary"
    assert response.json()["severity"] == "P1"

    response = await auth_client.patch(
        f"/alerts/{alert_id}",
        json={"description": "desc"}
    )
    assert response.json()["description"] == "desc"
    assert response.json()["id"] == alert_id
    assert response.status_code == 200

    response = await auth_client.post(
        f"/alerts/{alert_id}/triage"
    )
    assert mock_triage.call_count == 2


async def test_triage_not_refresh_on_occur_bump(auth_client, alert_payload, mock_triage):
    response = await auth_client.post(
        "/alerts",
        json=alert_payload
    )
    assert response.status_code == 201
    alert_id = response.json()["id"]
    response = await auth_client.post(
        f"/alerts/{alert_id}/triage"
    )
    assert mock_triage.call_count == 1
    assert response.json()["summary"] == "test summary"
    assert response.json()["severity"] == "P1"

    response = await auth_client.post(
        "/alerts",
        json=alert_payload
    )
    assert response.status_code == 200
    assert response.json()["occurrence_count"] == 2

    response = await auth_client.post(
        f"/alerts/{alert_id}/triage"
    )
    assert mock_triage.call_count == 1


async def test_triage_404_on_missing_alert(auth_client, alert_payload, mock_triage):
    response = await auth_client.post(
        "/alerts",
        json=alert_payload
    )
    assert response.status_code == 201
    alert_id = response.json()["id"]
    response = await auth_client.post(
        f"/alerts/{alert_id}/triage"
    )
    assert mock_triage.call_count == 1
    assert response.json()["summary"] == "test summary"
    assert response.json()["severity"] == "P1"

    response = await auth_client.post(
        "/alerts/11213/triage"
    )
    assert mock_triage.call_count == 1
    assert response.status_code == 404


async def test_triage_api_conn_error(auth_client, alert_payload, mock_triage):
    fake_req = httpx.Request("POST", "http://x")
    mock_triage.side_effect = anthropic.APIConnectionError(message="API Connection Error", request=fake_req)
    response = await auth_client.post(
        "/alerts",
        json=alert_payload
    )
    assert response.status_code == 201
    alert_id = response.json()["id"]

    response = await auth_client.post(
        f"/alerts/{alert_id}/triage"
    )
    assert mock_triage.call_count == 1
    assert response.status_code == 503
    response = await auth_client.get(
        f"/alerts/{alert_id}"
    )
    assert response.status_code == 200
    assert response.json()["summary"] is None
    assert response.json()["severity"] is None


async def test_triage_resolved_alert_409_and_0_func_call(auth_client, alert_payload, mock_triage):
    response = await auth_client.post(
        "/alerts",
        json=alert_payload
    )
    assert response.status_code == 201
    alert_id = response.json()["id"]

    response = await auth_client.patch(
        f"/alerts/{alert_id}", json={"status": "resolved"}
    )
    assert response.status_code == 200

    response = await auth_client.post(
        f"/alerts/{alert_id}/triage")
    assert mock_triage.call_count == 0
    assert response.status_code == 409

    response = await auth_client.get(
        f"/alerts/{alert_id}")
    assert response.status_code == 200
    assert response.json()["summary"] is None
    assert response.json()["severity"] is None


async def test_503_on_fail_commit_after_successful_triage(auth_client, alert_payload, mock_triage, monkeypatch):
    response = await auth_client.post(
        "/alerts",
        json=alert_payload
    )
    assert response.status_code == 201
    alert_id = response.json()["id"]
    before_val = REGISTRY.get_sample_value("triage_requests_total", {"outcome": "failed"}) or 0
    mock_async_commit = AsyncMock()
    mock_async_commit.side_effect = SQLAlchemyError("Error committing to database")
    monkeypatch.setattr(AsyncSession, "commit", mock_async_commit)

    response = await auth_client.post(
        f"/alerts/{alert_id}/triage"
    )
    assert response.status_code == 503
    after_val = REGISTRY.get_sample_value("triage_requests_total", {"outcome": "failed"}) or 0
    assert before_val + 1 == after_val
