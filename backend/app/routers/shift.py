from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app import schemas, models
from datetime import datetime
from zoneinfo import ZoneInfo
from app.services.shift_service import create_shifts_for_today,get_current_shift_secret_code

router = APIRouter(prefix="/shifts", tags=["Shifts"])

@router.get("/", response_model=list[schemas.ShiftResponse])
def get_shifts(db: Session = Depends(get_db)):
    today = datetime.now(ZoneInfo("Asia/Ho_Chi_Minh")).replace(hour=0, minute=0, second=0, microsecond=0)   
    shifts = db.query(models.Shift).filter(models.Shift.start_time >= today).all()
    return shifts

@router.get("/secret-code")
def get_current_secret_code(db: Session = Depends(get_db)):
    return get_current_shift_secret_code(db)

# @router.post("/generate-shift")
# def generate_shifts(db: Session = Depends(get_db)):
#     """
#     Tạo ca làm việc hôm nay nếu chưa có.
#     """
#     return create_shifts_for_today(db)


