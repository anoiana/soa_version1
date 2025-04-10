from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app import schemas, models
from datetime import datetime, timedelta,timezone
from zoneinfo import ZoneInfo

router = APIRouter(prefix="/shifts", tags=["Shifts"])

@router.get("/", response_model=list[schemas.ShiftResponse])
def get_shifts(db: Session = Depends(get_db)):
    today = datetime.now(ZoneInfo("Asia/Ho_Chi_Minh")).replace(hour=0, minute=0, second=0, microsecond=0)   
    shifts = db.query(models.Shift).filter(models.Shift.start_time >= today).all()
    return shifts
