from typing import Optional
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.services import payment_service
from fastapi import HTTPException
from app.schemas import PaymentCreate, PaymentResponse

router = APIRouter(prefix="/payment", tags=["Payment"])
# Thanh toán
@router.post("/", response_model=PaymentResponse)
def make_payment(request: PaymentCreate, db: Session = Depends(get_db)):
    try:
        payment = payment_service.process_payment(db, request)
        return payment
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

# Tổng hợp phiếu tính tiền theo ca
@router.get("/shift/{shift_id}")
def get_payments_by_shift(shift_id: int, db: Session = Depends(get_db)):
    return payment_service.get_payments_by_shift(db, shift_id)

# Lịch sử thanh toán theo ngày
@router.get("/history/")
def get_payments_by_date(year: int, month: Optional[int] = None, day: Optional[int] = None, db: Session = Depends(get_db)):
    return payment_service.get_payments_by_date(db, year, month, day)