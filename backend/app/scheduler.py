from apscheduler.schedulers.background import BackgroundScheduler
from app.services.shift_service import create_shifts_for_today
from app.database import SessionLocal
import logging

# Cấu hình logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def job_create_shifts():
    """Job tự động tạo ca làm việc mỗi giờ."""
    try:
        db = SessionLocal()
        create_shifts_for_today(db)
        logger.info("Đã hoàn thành tạo ca cho hôm nay.")
    except Exception as e:
        logger.exception("Lỗi khi chạy job tạo ca:")
    finally:
        db.close()

def start_scheduler():
    """Khởi động Scheduler với interval 2 tiếng."""
    scheduler = BackgroundScheduler(timezone="Asia/Ho_Chi_Minh")
    # Tạo job sẽ chạy mỗi 2 giờ
    scheduler.add_job(job_create_shifts, 'cron', hour=0, minute=1)
    scheduler.start()
    logger.info("Scheduler đã được khởi động và chạy mỗi 00:01")

