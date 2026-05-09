import os
import pytest
from fastapi.testclient import TestClient
from app import app

client = TestClient(app)


@pytest.fixture
def set_env_vars():
    os.environ["APP_NAME"] = "Test App"
    os.environ["ENVIRONMENT"] = "test"
    os.environ["SECRET_KEY"] = "test-secret-key"
    yield
    del os.environ["APP_NAME"]
    del os.environ["ENVIRONMENT"]
    del os.environ["SECRET_KEY"]


def test_health_check():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "OK", "message": "The application is healthy!"}


def test_get_version():
    r = client.get("/version")
    assert r.status_code == 200
    assert r.json() == {"version": "1.0.0"}


def test_get_env(set_env_vars):
    r = client.get("/env")
    assert r.status_code == 200
    assert r.json() == {
        "app_name": "Test App",
        "environment": "test",
        "secret_key": "test-secret-key",
    }


def test_get_devops_tip():
    r = client.get("/tips")
    assert r.status_code == 200
    assert "tip" in r.json()


def test_read_root():
    r = client.get("/")
    assert r.status_code == 200
    assert r.json()["message"] == "Welcome to the DevOps Demo App!"


def test_login():
    r = client.get("/login")
    assert r.status_code == 200
    assert r.json() == {"status": "authenticated"}


def test_logout():
    r = client.get("/logout")
    assert r.status_code == 200
    assert r.json() == {"status": "logged out"}
