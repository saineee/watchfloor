from sqlalchemy.exc import IntegrityError
from app.models import User
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.schemas import UserCreate, UserRead
from app.security import hash_password
from fastapi import APIRouter, Depends, HTTPException

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/register", response_model=UserRead, status_code=201)
async def register_user(user: UserCreate, db: AsyncSession = Depends(get_db)):
    user_data = user.model_dump()
    user_data["password_hash"] = hash_password(user_data.pop("password"))
    db_user = User(**user_data)
    db.add(db_user)

    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=409, detail="Email already registered")

    await db.refresh(db_user)
    return db_user
