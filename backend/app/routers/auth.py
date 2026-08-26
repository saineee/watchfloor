from sqlalchemy import select
from sqlalchemy.exc import IntegrityError, MultipleResultsFound
from app.models import User
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.schemas import UserCreate, UserRead, UserLogin
from app.security import hash_password, verify_password
from fastapi import APIRouter, Depends, HTTPException, Request

router = APIRouter(prefix="/auth", tags=["auth"])
# dummy hash computed once at import because hashing is roughly 30ms per call, 2 hashes per request would reintroduce the same issue
DUMMY_HASH = hash_password("not_a_real_password")

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

@router.post("/login", response_model=UserRead, status_code=200)
async def login_user(request: Request, user: UserLogin, db: AsyncSession = Depends(get_db)):
    user_data = user.model_dump()
    stmt = select(User).where(User.email == user_data["email"])

    try:
        result = await db.execute(stmt)
        db_user = result.scalar_one_or_none()

    except MultipleResultsFound:
        raise HTTPException(status_code=500, detail="Multiple users found with this email")

    if not db_user:
        # used to keep all code exec time consistent, so an attacker cannot figure if the email is registered or not
        verify_password("hash", DUMMY_HASH)
        raise HTTPException(status_code=401, detail="Incorrect email or password")

    if not verify_password(user_data["password"], db_user.password_hash):
        raise HTTPException(status_code=401, detail="Incorrect email or password")

    request.session["user_id"] = db_user.id
    return db_user

