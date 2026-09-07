from app.config import settings
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker

engine = create_async_engine(settings.database_url)
async_session_maker = async_sessionmaker(bind=engine, expire_on_commit=False)


async def get_db():
    db = async_session_maker()
    try:
        yield db
    finally:
        await db.close()
