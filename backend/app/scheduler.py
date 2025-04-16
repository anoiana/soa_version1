from apscheduler.schedulers.background import BackgroundScheduler
from app.services.shift_service import create_shifts_for_today
from app.database import SessionLocal
import logging

def job_create_shifts():
    try:
        db = SessionLocal()
        create_shifts_for_today(db)
    except Exception as e:
        logging.exception("Lỗi khi chạy job tạo ca:")
    finally:
        db.close()

def start_scheduler():
    scheduler = BackgroundScheduler(timezone="Asia/Ho_Chi_Minh")
    scheduler.add_job(job_create_shifts, 'cron', hour=0, minute=1)  # chạy lúc 00:01 mỗi ngày
    scheduler.start()
