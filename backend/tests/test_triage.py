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

    response =  await auth_client.post(
        "/alerts/11213/triage"
    )
    assert mock_triage.call_count == 1
    assert response.status_code == 404

