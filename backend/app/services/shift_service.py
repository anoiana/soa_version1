from sqlalchemy.orm import Session
import datetime
from datetime import timedelta
from app import models
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone
from app import models
import random
import string
from zoneinfo import ZoneInfo

def generate_secret_code():
    """Tạo mã bí mật với 3 chữ in hoa đầu và 3 số sau."""
    chu_hoa = ''.join(random.choices(string.ascii_uppercase, k=3))
    so = ''.join(random.choices(string.digits, k=3))
    return chu_hoa + so

def create_shifts_for_today(db: Session):
    now = datetime.now(ZoneInfo("Asia/Ho_Chi_Minh"))
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)

    shifts = [
        {"start_hour": 10},  # Ca 1: 10h - 16h
        {"start_hour": 16},  # Ca 2: 16h - 22h
    ]

    for shift in shifts:
        start_time = today.replace(hour=shift["start_hour"])
        
        # Kiểm tra nếu ca này đã có trong database
        existing_shift = db.query(models.Shift).filter(models.Shift.start_time == start_time).first()
        if existing_shift:
            continue  # Nếu đã tồn tại, bỏ qua

        # Tạo mới ca làm việc
        new_shift = models.Shift.create_shift(start_time, generate_secret_code())
        db.add(new_shift)

    db.commit()


