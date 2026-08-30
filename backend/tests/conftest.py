from app.config import settings
from sqlalchemy.engine import make_url

url = make_url(settings.database_url)

if not url.database.endswith("_test"):
    raise ValueError(f"refusing to run against {url.database}, the name must end in _test")

