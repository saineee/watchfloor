test_alert ={
    "error_type": "ESX Host down",
    "device_name": "dallas.esx.host03",
    "ip_address": "172.16.17.32",
    "description": "alarm: host connection and power state red",
    "device_state": "down",
    "location": "dallas",
    "device_last_available": None}

async def test_check_return_summary_sev(auth_client):
    response = await auth_client.post(
        "/alerts",
        json=test_alert)
    assert response.status_code == 201
    assert response.json()["severity"] is None
    assert response.json()["summary"] is None

async def test_check_dedup(auth_client):
    response = await auth_client.post(
        "/alerts",
        json=test_alert
    )
    alert_data = response.json()
    assert alert_data["occurrence_count"] == 1
    assert response.status_code == 201

    response = await auth_client.post(
        "/alerts",
        json=test_alert
    )
    assert response.status_code == 200
    assert alert_data["id"] == response.json()["id"]
    assert response.json()["occurrence_count"] == 2
    response = await auth_client.get("/alerts")
    assert len(response.json()) == 1

async def test_create_alert_resolve_new_id(auth_client):
    response = await auth_client.post(
        "/alerts",
        json=test_alert
    )
    assert response.status_code == 201
    alert_id = response.json()["id"]
    response = await auth_client.patch(
        f"/alerts/{alert_id}",
    json={"status": "resolved"},
    )
    assert response.status_code == 200

    response = await auth_client.post(
    "/alerts",
    json=test_alert
    )
    assert response.status_code == 201
    assert response.json()["id"] != alert_id

    response = await auth_client.get("/alerts")
    assert len(response.json()) == 2
