from app.database import get_db
from app.models import User
from sqlalchemy.ext.asyncio import AsyncSession

from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from fastapi import Request, Depends, HTTPException
from starlette import status

hasher = PasswordHasher()

def hash_password(password):
    return hasher.hash(password)

def verify_password(password, hashed_password):
    try:
        hasher.verify(hashed_password, password)
        return True
    except VerifyMismatchError:
        return False

async def require_user(request: Request, db: AsyncSession = Depends(get_db)):
    user_id = request.session.get("user_id")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)
    db_user = await db.get(User, user_id)
    if not db_user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)
    return db_user
