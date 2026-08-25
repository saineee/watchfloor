import os
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from dotenv import load_dotenv

load_dotenv()
database_url = os.environ['DATABASE_URL']

engine = create_async_engine(database_url)
async_session_maker = async_sessionmaker(bind=engine)

async def get_db():
    db = async_session_maker()
    try:
        yield db
    finally:
        await db.close()
