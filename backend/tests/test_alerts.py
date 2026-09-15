async def test_check_return_summary_sev(auth_client, alert_payload):
    response = await auth_client.post(
        "/alerts",
        json=alert_payload)
    assert response.status_code == 201
    assert response.json()["severity"] is None
    assert response.json()["summary"] is None

async def test_check_dedup(auth_client, alert_payload):
    response = await auth_client.post(
        "/alerts",
        json=alert_payload
    )
    alert_data = response.json()
    assert alert_data["occurrence_count"] == 1
    assert response.status_code == 201

    response = await auth_client.post(
        "/alerts",
        json=alert_payload
    )
    assert response.status_code == 200
    assert alert_data["id"] == response.json()["id"]
    assert response.json()["occurrence_count"] == 2
    response = await auth_client.get("/alerts")
    assert len(response.json()) == 1

async def test_create_alert_resolve_new_id(auth_client, alert_payload):
    response = await auth_client.post(
        "/alerts",
        json=alert_payload
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
    json=alert_payload
    )
    assert response.status_code == 201
    assert response.json()["id"] != alert_id

    response = await auth_client.get("/alerts")
    assert len(response.json()) == 2

async def test_patch_none_on_null_field_return_422(auth_client, alert_payload):
    response = await auth_client.post(
        "/alerts",
        json=alert_payload
    )
    assert response.status_code == 201
    alert_id = response.json()["id"]
    response = await auth_client.patch(
        f"/alerts/{alert_id}",
        json={"description": None},
    )
    assert response.status_code == 422

async def test_patch_location_set_200(auth_client, alert_payload):
    response = await auth_client.post(
        "/alerts",
        json=alert_payload
    )
    assert response.status_code == 201
    alert_id = response.json()["id"]
    response = await auth_client.patch(
        f"/alerts/{alert_id}",
        json={"location": None},
    )
    assert response.status_code == 200
    assert response.json()["location"] is None

async def test_patch_extra_field_return_422(auth_client, alert_payload):
    response = await auth_client.post(
        "/alerts",
        json=alert_payload
    )
    assert response.status_code == 201
    alert_id = response.json()["id"]
    response = await auth_client.patch(
        f"/alerts/{alert_id}",
        json={"unknown": "unknown"},
    )
    assert response.status_code == 422

async def test_get_alert_not_exist_return_404(auth_client):
    response = await auth_client.get(
        "/alerts/999999",
    )
    assert response.status_code == 404

async def test_get_alert_list_manual_limit_return_422(auth_client):
    response = await auth_client.get(
        "/alerts?limit=101"
    )
    assert response.status_code == 422

async def test_invalid_status_transition_return_status_code_409(auth_client, alert_payload):
    response = await auth_client.post(
        "/alerts",
        json=alert_payload
    )
    assert response.status_code == 201
    alert_id = response.json()["id"]

    response = await auth_client.patch(
        f"/alerts/{alert_id}",
        json={"status": "escalated"}
    )
    assert response.status_code == 409

    response = await auth_client.get(f"/alerts/{alert_id}")
    assert response.status_code == 200
    assert response.json()["status"] == "new"

async def test_valid_status_transition_return_200_successfully(auth_client, alert_payload):
    response = await auth_client.post(
        "/alerts",
        json=alert_payload
    )
    assert response.status_code == 201
    alert_id = response.json()["id"]

    response = await auth_client.patch(
        f"/alerts/{alert_id}",
        json={"status": "in_progress"}
    )
    assert response.status_code == 200

    response = await auth_client.get(f"/alerts/{alert_id}")
    assert response.status_code == 200
    assert response.json()["status"] == "in_progress"
