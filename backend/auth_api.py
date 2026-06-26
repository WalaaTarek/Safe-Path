from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import Base, engine, get_db
from models import User
from schemas import UserCreate, UserLogin

router = APIRouter()

Base.metadata.create_all(bind=engine)

@router.post("/signup")
def signup(user: UserCreate, db: Session = Depends(get_db)):

    existing_user = db.query(User).filter(
        User.email == user.email
    ).first()

    if existing_user:
        raise HTTPException(
            status_code=400,
            detail="Email already exists"
        )

    new_user = User(
        username=user.username,
        email=user.email,
        password=user.password
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return {
        "message": "Account created successfully",
        "user_id": new_user.id
    }


@router.post("/login")
def login(user: UserLogin, db: Session = Depends(get_db)):

    db_user = db.query(User).filter(
        User.email == user.email
    ).first()

    if not db_user:
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password"
        )

    if db_user.password != user.password:
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password"
        )

    return {
        "message": "Login successful",
        "user_id": db_user.id,
        "username": db_user.username
    }