from zoneinfo import ZoneInfo
from sqlalchemy import extract
from sqlalchemy.orm import Session
from fastapi import HTTPException
from datetime import datetime, timedelta, timezone
from app import models, schemas

def process_payment(db: Session, request: schemas.PaymentCreate):
    session = db.query(models.TableSession).filter(
        models.TableSession.session_id == request.session_id
    ).first()

    if not session or session.end_time is None:
        raise ValueError("Bàn chưa đóng hoặc không hợp lệ.")

    # ❌ Kiểm tra nếu đã có thanh toán trước đó
    existing_payment = db.query(models.Payment).filter(
        models.Payment.session_id == request.session_id
    ).first()

    if existing_payment:
        raise ValueError("Phiên bàn này đã được thanh toán trước đó!")

    # ✅ Lưu thanh toán vào database
    new_payment = models.Payment(
        session_id=request.session_id,
        amount=request.amount,
        payment_time=datetime.now(ZoneInfo("Asia/Ho_Chi_Minh")),
        payment_method="Mặc định"
    )

    db.add(new_payment)
    db.commit()
    db.refresh(new_payment)

    return new_payment

def get_payments_by_shift(db: Session, shift_id: int):
    payments = db.query(models.Payment).join(models.TableSession).filter(
        models.TableSession.shift_id == shift_id
    ).all()

    if not payments:
        raise HTTPException(status_code=404, detail="Không tìm thấy phiếu tính tiền cho ca này.")

    total_revenue = sum(payment.amount for payment in payments)

    return {
        "shift_id": shift_id,
        "total_revenue": total_revenue,
        "payments": payments
    }

def get_payments_by_date(db: Session, year: int, month: int = None, day: int = None):
    query = db.query(models.Payment).filter(
        extract('year', models.Payment.payment_time) == year
    )

    if month:
        query = query.filter(extract('month', models.Payment.payment_time) == month)
    if day:
        query = query.filter(extract('day', models.Payment.payment_time) == day)

    payments = query.all()

    if not payments:
        raise HTTPException(status_code=404, detail="Không tìm thấy phiếu tính tiền trong khoảng thời gian này.")

    total_revenue = sum(payment.amount for payment in payments)

    return {
        "year": year,
        "month": month,
        "day": day,
        "total_revenue": total_revenue,
        "payments": payments
    }

