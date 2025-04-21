import email
from os import name
from fastapi import APIRouter, Depends, HTTPException
from app import schemas
from app.services import user_service
from sqlalchemy.orm import Session
from app.database import get_db

router = APIRouter()
router = APIRouter(prefix="/user", tags=["User"])
# @router.post("/")
# def create_user(user: schemas.UserCreate):
#     return user_service.create_user(user.name, user.email, user.phone, user.password)  # Không cần user_id


# @router.get("/{user_id}")
# def read_user(user_id: str):
#     return user_service.get_user(user_id)

# Đăng nhập 
@router.post("/admin/login")
def login(user: schemas.UserLogin):
    result = user_service.login_user(user.email, user.password)
    if "error" in result:
        raise HTTPException(status_code=401, detail=result["error"])
    return result

# Quên mật khẩu
@router.post("/send-password-reset")
async def send_password_reset_endpoint(email: str):
    try:
        result = user_service.send_password_reset(email)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    
@router.post("/employee/login")
def employee_login(secret_code: str, db: Session = Depends(get_db)):
    try:
        result = user_service.login_employee_by_secret_code(db, secret_code)
        if "error" in result:
            raise HTTPException(status_code=401, detail=result["error"])
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lỗi máy chủ: {str(e)}")