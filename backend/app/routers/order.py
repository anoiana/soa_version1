from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.services import order_service
from app import schemas 

router = APIRouter(prefix="/order", tags=["Order"])

# Mở bàn
@router.post("/open-table/", response_model=schemas.TableSessionResponse)
def open_table_api(table_data: schemas.TableSessionCreate, db: Session = Depends(get_db)):
    return order_service.open_table(db, table_data)  # Gọi service mở bàn
# Đóng bàn
@router.put("/close/{table_number}")
def close_table_endpoint(table_number: str, request: schemas.TableSessionClose, db: Session = Depends(get_db)):
    return order_service.close_table(db, table_number, request)

# API xác nhận gọi món
@router.post("/confirm", response_model=schemas.Order)
async def confirm_order(order_data: schemas.OrderCreate, db: Session = Depends(get_db)):
    return order_service.create_order_with_items(db, order_data)

# Update Package ID
@router.put("/table/update-package")
def update_table_package(data: schemas.Table_UpdatePackage, db: Session = Depends(get_db)):
    return order_service.update_package_for_table(db, data)