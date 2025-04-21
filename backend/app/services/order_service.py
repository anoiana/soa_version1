from datetime import datetime
import json
# import os
from fastapi import HTTPException
from sqlalchemy.orm import Session
from app import models, schemas
# import redis
from zoneinfo import ZoneInfo
from app.redis_client import redis_client

# Kết nối Redis để gửi thông báo đến queue
# redis_client = redis.Redis(host='localhost', port=6379, db=0)

# redis_client = redis.Redis(
#     host=os.getenv("REDISHOST"),
#     port=int(os.getenv("REDISPORT")),
#     password=os.getenv("REDISPASSWORD"),
#     decode_responses=True  # để trả về string thay vì bytes
# )

def create_order_with_items(db: Session, order_data: schemas.OrderCreate):
    table = db.query(models.Table).filter(models.Table.table_number == order_data.table_number).first()
    if not table:
        raise HTTPException(status_code=404, detail="Table not found")

    session = db.query(models.TableSession).filter(
        models.TableSession.table_id == table.table_id,
        models.TableSession.end_time.is_(None)
    ).first()

    if not session:
        raise HTTPException(status_code=400, detail="No active session for this table")

    # Tạo order
    new_order = models.Order(
        session_id=session.session_id,
        status="ordered",
        order_time=datetime.now(ZoneInfo("Asia/Ho_Chi_Minh"))
    )
    db.add(new_order)
    db.flush()

    # Truy vấn tất cả menu items 1 lần
    item_ids = [item.item_id for item in order_data.items]
    menu_items = db.query(models.MenuItem).filter(
        models.MenuItem.item_id.in_(item_ids),
        models.MenuItem.available == True
    ).all()
    available_item_ids = {item.item_id for item in menu_items}

    # Kiểm tra xem có món nào không hợp lệ
    invalid_ids = set(item_ids) - available_item_ids
    if invalid_ids:
        db.rollback()
        raise HTTPException(status_code=404, detail=f"Menu items {list(invalid_ids)} not found or unavailable")

    # Tạo các order_item
    order_items = [
        models.OrderItem(
            order_id=new_order.order_id,
            item_id=item.item_id,
            quantity=item.quantity,
            status="ordered"
        ) for item in order_data.items
    ]
    db.add_all(order_items)

    # Commit
    db.commit()

    # Tạo dữ liệu gửi qua Redis (nếu muốn bạn vẫn có thể thêm refresh sau commit)
    order_data_queue = {
        "order_id": new_order.order_id,
        "session_id": new_order.session_id,
        "table_number": order_data.table_number,
        "order_time": new_order.order_time.isoformat(),
        "items": [
            {
                "item_id": item.item_id,
                "quantity": item.quantity,
                "status": "ordered"
            } for item in order_data.items
        ]
    }

    redis_client.publish("kitchen:orders", json.dumps(order_data_queue))

    return new_order


# Mở bàn mới
def open_table(db: Session, table_data: schemas.TableSessionCreate):
    # 🔎 Tìm table_id từ table_number
    table = db.query(models.Table).filter(
        models.Table.table_number == table_data.table_number
    ).first()

    if not table:
        raise HTTPException(status_code=404, detail="Không tìm thấy bàn.")

    # Kiểm tra xem bàn đã mở chưa
    existing_session = db.query(models.TableSession).filter(
        models.TableSession.table_id == table.table_id,
        models.TableSession.end_time.is_(None)  # Bàn chưa đóng
    ).first()

    if existing_session:
        raise HTTPException(status_code=400, detail="Bàn này đang hoạt động, không thể mở bàn mới.")

    shift_id = get_current_shift(db, table_data.secret_code)

    # Tạo phiên bàn mới
    new_session = models.TableSession(
        table_id=table.table_id,  # Dùng table_id từ số bàn
        start_time=datetime.now(ZoneInfo("Asia/Ho_Chi_Minh")),
        number_of_customers=table_data.number_of_customers,
        shift_id=shift_id
    )

    # ✅ Cập nhật trạng thái bàn thành "eating"
    table.status = "eating"

    db.add(new_session)
    db.commit()
    db.refresh(new_session)
    db.refresh(table)  # Làm mới dữ liệu bàn để đảm bảo cập nhật
    return new_session

# Đóng bàn theo số bàn, chỉ cho phép đóng bàn đang mở.
def close_table(db: Session, table_number: str, request: schemas.TableSessionClose):
    # 🔎 Tìm bàn theo số bàn
    table = db.query(models.Table).filter(
        models.Table.table_number == table_number
    ).first()

    if not table:
        raise HTTPException(status_code=404, detail="Không tìm thấy bàn.")

    # 🔎 Tìm phiên bàn đang mở
    existing_session = db.query(models.TableSession).filter(
        models.TableSession.table_id == table.table_id,
        models.TableSession.end_time.is_(None)  # Bàn chưa đóng
    ).first()

    if not existing_session:
        raise HTTPException(status_code=400, detail="Bàn này không có phiên nào đang hoạt động.")
    get_current_shift(db, request.secret_code)
    
    # ✅ Cập nhật end_time để đóng bàn
    existing_session.end_time = datetime.now(ZoneInfo("Asia/Ho_Chi_Minh"))

    # ✅ Cập nhật trạng thái bàn thành "ready"
    table.status = "ready"
    # total_amount = calculate_total_amount(db, existing_session.session_id)

    db.commit()
    db.refresh(existing_session)
    db.refresh(table)  # Làm mới dữ liệu bàn để đảm bảo cập nhật

    return {
        "message": "Bàn đã đóng thành công.",
        "session_id": existing_session.session_id,
        "table_number": table_number,
        # "total_amount": total_amount,
        "end_time": existing_session.end_time
    }
# Hàm tìm ca làm việc hiện tại.
def get_current_shift(db: Session, secret_code: str):
    """Trả về shift_id nếu secret_code hợp lệ, ngược lại báo lỗi."""
    now = datetime.now(ZoneInfo("Asia/Ho_Chi_Minh"))
    current_shift = db.query(models.Shift).filter(
        models.Shift.start_time <= now,
        models.Shift.end_time >= now,
        models.Shift.secret_code == secret_code
    ).first()

    if not current_shift:
        raise HTTPException(status_code=403, detail="Mã ca làm việc không hợp lệ hoặc không có ca làm việc hiện tại.")

    return current_shift.shift_id  # Bây giờ an toàn để truy cập shift_id

# # Tính tổng tiền dựa trên giá gói buffet và số người ăn
# def calculate_total_amount(db: Session, session_id: int) -> float:
#     """Tính tổng tiền dựa trên giá gói buffet và số người ăn"""
#     session = db.query(models.TableSession).filter(models.TableSession.session_id == session_id).first()
    
#     # if not session or session.package_id is None:
#     #     raise HTTPException(status_code=400, detail="Không tìm thấy phiên bàn hoặc không có gói buffet.")
#     if not session:
#         raise HTTPException(status_code=400, detail="Không tìm thấy phiên bàn.")

#     if session.package_id is None:
#         # Có thể xử lý như bàn không ăn buffet → tổng tiền 0
#         return 0.0


#     buffet_package = db.query(models.BuffetPackage).filter(models.BuffetPackage.package_id == session.package_id).first()
    
#     if not buffet_package:
#         raise HTTPException(status_code=400, detail="Không tìm thấy gói buffet cho phiên này.")

#     # Tính tổng tiền: giá gói buffet * số người ăn
#     total_amount = buffet_package.price_per_person * session.number_of_customers
#     return total_amount

# Hàm update Package ID
def update_package_for_table(db: Session, data: schemas.Table_UpdatePackage):
    table = db.query(models.Table).filter(
        models.Table.table_number == data.table_number
    ).first()
    if not table:
        raise HTTPException(status_code=404, detail="Không tìm thấy bàn.")

    # Tìm phiên bàn đang mở
    session = db.query(models.TableSession).filter(
        models.TableSession.table_id == table.table_id,
        models.TableSession.end_time.is_(None)
    ).first()
    if not session:
        raise HTTPException(status_code=400, detail="Bàn không có phiên hoạt động.")

    # Kiểm tra gói buffet có tồn tại không
    buffet = db.query(models.BuffetPackage).filter(
        models.BuffetPackage.package_id == data.package_id
    ).first()
    if not buffet:
        raise HTTPException(status_code=404, detail="Không tìm thấy gói buffet.")

    # Cập nhật package_id
    session.package_id = data.package_id
    db.commit()
    db.refresh(session)

    return {"message": "Cập nhật gói buffet thành công.", "session_id": session.session_id}

# Hàm tìm bàn theo session_id
def get_table_number_by_session_id(db: Session, session_id: int):
    session = db.query(models.TableSession).join(models.Table).filter(
        models.TableSession.session_id == session_id
    ).first()

    if not session:
        raise HTTPException(status_code=404, detail="Không tìm thấy phiên bàn.")

    return {
        "session_id": session.session_id,
        "table_number": session.table.table_number
    }

def process_websocket_order(db: Session, order_data: dict):
    """
    Xử lý order nhận từ WebSocket, lưu vào cơ sở dữ liệu và publish vào Redis.
    """
    try:
        order_create = schemas.OrderCreate(
            table_number=order_data["table_number"],
            items=[
                schemas.OrderItemCreate(item_id=item["item_id"], quantity=item["quantity"])
                for item in order_data["items"]
            ]
        )
    except KeyError as e:
        raise HTTPException(status_code=400, detail=f"Invalid order data: missing {str(e)}")

    return create_order_with_items(db, order_create)