from datetime import datetime, timezone

from app.models import Session, User
from sqlalchemy import select
from app.database import get_db
from sqlalchemy.ext.asyncio import AsyncSession
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from fastapi import Request, Depends, HTTPException, status

hasher = PasswordHasher()
COOKIE = 'session'
MAX_AGE = 3600


def hash_password(password):
    return hasher.hash(password)


def verify_password(password, hashed_password):
    try:
        hasher.verify(hashed_password, password)
        return True
    except VerifyMismatchError:
        return False


async def require_user(request: Request, db: AsyncSession = Depends(get_db)):
    cookie = request.cookies.get(COOKIE)
    if not cookie:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)
    stmt = select(Session).where(Session.token == cookie)
    result = await db.execute(stmt)
    db_session = result.scalar_one_or_none()
    if not db_session:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)
    now = datetime.now(timezone.utc)
    if now > db_session.expires_at:
        await db.delete(db_session)
        await db.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)

    user = await db.get(User, db_session.user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)

    return user
