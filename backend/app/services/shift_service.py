from fastapi import HTTPException
from sqlalchemy import and_
from sqlalchemy.orm import Session
from datetime import datetime
from app import models
import random
import string
from zoneinfo import ZoneInfo
from datetime import datetime, timedelta, time

def generate_secret_code():
    """Tạo mã bí mật gồm 3 chữ in hoa và 3 số."""
    chu_hoa = ''.join(random.choices(string.ascii_uppercase, k=3))
    so = ''.join(random.choices(string.digits, k=3))
    return chu_hoa + so

def create_shifts_for_today(db: Session, raise_if_full: bool = True):
    now = datetime.now(ZoneInfo("Asia/Ho_Chi_Minh"))
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)

    shift_definitions = [
        {"start_hour": 10, "label": "ca 1"},
        {"start_hour": 16, "label": "ca 2"},
    ]

    created_labels = []

    for shift in shift_definitions:
        start_time = today.replace(hour=shift["start_hour"])
        existing_shift = db.query(models.Shift).filter(models.Shift.start_time == start_time).first()
        if existing_shift:
            continue
        new_shift = models.Shift.create_shift(start_time, generate_secret_code())
        db.add(new_shift)
        created_labels.append(shift["label"])

    db.commit()

    if not created_labels:
        if raise_if_full:
            raise HTTPException(status_code=409, detail="Hôm nay đã có đầy đủ ca làm việc.")
        else:
            return {"message": "Không cần tạo thêm ca hôm nay (đã đủ)."}

    return {"message": f"Đã tạo {' và '.join(created_labels)} cho hôm nay."}

def get_current_shift_secret_code(db: Session):
    now = datetime.now(ZoneInfo("Asia/Ho_Chi_Minh"))

    shift = db.query(models.Shift).filter(
        and_(
            models.Shift.start_time <= now,
            models.Shift.end_time > now
        )
    ).first()

    if not shift:
        raise HTTPException(status_code=404, detail="Hiện tại không nằm trong ca làm việc nào.")

    return {
        "shift_id": shift.shift_id,
        "secret_code": shift.secret_code,
        "start_time": shift.start_time,
        "end_time": shift.end_time
    }

