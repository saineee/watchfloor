from sqlalchemy import text

from app.database import engine

test_user = {"email": "test@gmail.com", "password": "1234891231k12"}

async def test_register_return_email_id(client):
    response = await client.post(
        "/auth/register",
        json=test_user,)
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "test@gmail.com"
    assert "id" in data
    assert "password" not in data
    assert "password_hash" not in data

async def test_two_failed_login_return_same_body(client):
    response = await client.post(
        "/auth/register",
        json=test_user)
    assert response.status_code == 201

    response = await client.post(
        "/auth/login",
        json={"email": "123123123@gmail.com", "password": "1238u9123jk1asdj"}
    )
    assert response.status_code == 401
    data_one = response.json()

    response = await client.post(
        "/auth/login",
        json={"email": "test@gmail.com", "password": "asdhfjhajfdd"}
    )
    assert response.status_code == 401
    data_two = response.json()

    assert data_one == data_two

async def test_get_alert_401_logged_out(client):
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

    response = await client.get(
        "/alerts"
    )

    assert response.status_code == 200

    response = await client.post(
        "/auth/logout"
    )
    assert response.status_code == 200

    response = await client.get(
        "/alerts"
    )
    assert response.status_code == 401

async def test_register_twice_409(client):
    response = await client.post(
        "/auth/register",
        json=test_user
    )
    assert response.status_code == 201

    response = await client.post(
        "/auth/register",
        json=test_user
    )
    assert response.status_code == 409

async def test_del_user_test_guarded_route_return_401(auth_client):
    response = await auth_client.get("/alerts")
    assert response.status_code == 200
    async with engine.begin() as conn:
        await conn.execute(text("DELETE FROM users WHERE email = :e"), {"e": test_user["email"]})
    response = await auth_client.get("/alerts")
    assert response.status_code == 401

