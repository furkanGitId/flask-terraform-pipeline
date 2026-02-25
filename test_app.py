import pytest
from app import app

@pytest.fixture
def client():
    with app.test_client() as client:
        yield client

def test_home_page(client):
    """Check if the home page loads correctly"""
    response = client.get('/')
    assert response.status_code == 200
    assert b"Hello from CI/CD" in response.data

def test_health_check(client):
    """Check if the health endpoint works"""
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json == {"status": "ok"}