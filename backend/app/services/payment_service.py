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
        payment_method= request.payment_method
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

def get_payment_details_by_id(db: Session, payment_id: int):
    payment = db.query(models.Payment).filter(models.Payment.payment_id == payment_id).first()

    if not payment:
        raise HTTPException(status_code=404, detail="Không tìm thấy thanh toán với ID này.")

    session = payment.session

    if not session:
        raise HTTPException(status_code=404, detail="Không tìm thấy phiên bàn tương ứng.")

    table = session.table
    package = session.package

    return {
        "payment_id": payment.payment_id,
        "table_number": table.table_number if table else None,
        "start_time": session.start_time,
        "end_time": session.end_time,
        "number_of_customers": session.number_of_customers,
        "buffet_package": package.name if package else "Không có gói buffet"
    }


def get_total_customers_by_shift(db: Session, shift_id: int):
    sessions = db.query(models.TableSession).filter(
        models.TableSession.shift_id == shift_id
    ).all()

    if not sessions:
        raise HTTPException(status_code=404, detail="Không tìm thấy phiên bàn nào cho ca này.")

    total_customers = sum(session.number_of_customers for session in sessions)

    return {
        "shift_id": shift_id,
        "total_customers": total_customers,
        "total_sessions": len(sessions)
    }

def get_total_customers_by_date(db: Session, year: int, month: int = None, day: int = None):
    query = db.query(models.TableSession).filter(
        extract('year', models.TableSession.start_time) == year
    )

    if month:
        query = query.filter(extract('month', models.TableSession.start_time) == month)
    if day:
        query = query.filter(extract('day', models.TableSession.start_time) == day)

    sessions = query.all()

    if not sessions:
        raise HTTPException(status_code=404, detail="Không tìm thấy phiên bàn trong khoảng thời gian này.")

    total_customers = sum(session.number_of_customers for session in sessions)

    return {
        "year": year,
        "month": month,
        "day": day,
        "total_customers": total_customers,
        "total_sessions": len(sessions)
    }
