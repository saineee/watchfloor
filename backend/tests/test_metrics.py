from prometheus_client import REGISTRY

HTTP_LABELS = {"method": "GET", "route": "unmatched", "status_code": "404"}


async def test_404_on_unknown_url(client):
    before_val = REGISTRY.get_sample_value("http_requests_total", HTTP_LABELS) or 0
    response = await client.get('/testlol')
    assert response.status_code == 404
    after_val = REGISTRY.get_sample_value("http_requests_total", HTTP_LABELS) or 0
    assert before_val + 1 == after_val
