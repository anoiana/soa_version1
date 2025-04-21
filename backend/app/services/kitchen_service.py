# import os
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload
from app import models
import redis
import json
from typing import List
from fastapi import HTTPException, logger
from datetime import datetime, timezone
import logging
from app.schemas import OrderItemDetail
from app.redis_client import redis_client

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
# Kết nối Redis

# redis_client = redis.Redis(
#     host=os.getenv("REDISHOST"),
#     port=int(os.getenv("REDISPORT")),
#     password=os.getenv("REDISPASSWORD"),
#     decode_responses=True
# )

# Lấy danh sách order chưa làm
# def get_pending_orders(db: Session) -> List[dict]:
#     pending_items = (
#         db.query(models.Order, models.OrderItem, models.MenuItem)
#         .join(models.OrderItem, models.Order.order_id == models.OrderItem.order_id)
#         .join(models.MenuItem, models.OrderItem.item_id == models.MenuItem.item_id)
#         .filter(models.OrderItem.status.in_(["ordered"]))
#         .order_by(models.Order.order_time.asc())
#         .all()
#     )

#     orders = {}
#     for order, item, menu_item in pending_items:
#         if order.order_id not in orders:
#             orders[order.order_id] = {
#                 "order_id": order.order_id,
#                 "session_id": order.session_id,
#                 "order_time": order.order_time.isoformat(),
#                 "items": []
#             }
#         orders[order.order_id]["items"].append({
#             "order_item_id": item.order_item_id,
#             "item_id": item.item_id,
#             "name": menu_item.name,
#             "quantity": item.quantity,
#             "status": item.status
#         })

#     return list(orders.values())

def get_pending_orders(db: Session) -> List[dict]:
    """
    Retrieves orders containing items with 'ordered' status, optimized using relationship loading.
    Filters items directly in SQL to minimize Python-side processing.

    Args:
        db (Session): SQLAlchemy database session.

    Returns:
        List[dict]: List of orders with their pending items.
    """
    # Subquery để lấy các Order có ít nhất một OrderItem với status "ordered"
    order_ids = (
        select(models.Order.order_id)
        .join(models.Order.items)
        .filter(models.OrderItem.status == "ordered")
        .distinct()
        .subquery()
    )

    # Truy vấn chính: lấy Orders và preload các OrderItem với status "ordered"
    orders = (
        db.query(models.Order)
        .filter(models.Order.order_id.in_(select(order_ids)))
        .options(
            selectinload(models.Order.items)
            .subqueryload(models.OrderItem.menu_item)  # Tối ưu hơn joinedload nếu MenuItem nhỏ
        )
        .order_by(models.Order.order_time.asc())
        .all()
    )

    # Ánh xạ dữ liệu thành cấu trúc mong muốn
    result = []
    for order in orders:
        # Lọc các OrderItem có status "ordered" (đảm bảo an toàn dù đã lọc ở SQL)
        pending_items = [
            {
                "order_item_id": item.order_item_id,
                "item_id": item.item_id,
                "name": item.menu_item.name if item.menu_item else "Unknown",
                "quantity": item.quantity,
                "status": item.status.value if hasattr(item.status, "value") else item.status
            }
            for item in order.items
            if item.status == "ordered"
        ]

        # Chỉ thêm Order nếu có ít nhất một item "ordered"
        if pending_items:
            result.append({
                "order_id": order.order_id,
                "session_id": order.session_id,
                "order_time": order.order_time.isoformat(),
                "items": pending_items
            })

    return result

# Lấy danh sách order theo trạng thái
def get_orders_by_status(db: Session, status: str) -> List[dict]:
    order_items = (
        db.query(models.Order, models.OrderItem, models.MenuItem)
        .join(models.OrderItem, models.Order.order_id == models.OrderItem.order_id)
        .join(models.MenuItem, models.OrderItem.item_id == models.MenuItem.item_id)
        .filter(models.Order.status == status)
        .order_by(models.Order.order_time.asc())
        .all()
    )

    orders = {}
    for order, item, menu_item in order_items:
        if order.order_id not in orders:
            orders[order.order_id] = {
                "order_id": order.order_id,
                "session_id": order.session_id,
                "order_time": order.order_time.isoformat(),
                "status": order.status,
                "items": []
            }
        orders[order.order_id]["items"].append({
            "order_item_id": item.order_item_id,
            "item_id": item.item_id,
            "name": menu_item.name,
            "quantity": item.quantity,
            "status": item.status
        })

    return list(orders.values())


# Định nghĩa các trạng thái HỢP LỆ mà một OrderItem có thể có
# Đồng thời đây cũng là các trạng thái được phép NHẬP VÀO
VALID_ORDER_ITEM_STATUSES = {"ordered", "served"}

# Định nghĩa quy tắc chuyển đổi trạng thái
ALLOWED_TRANSITIONS = {
    "ordered":  ["served"],
    "served": [],
    # Lưu ý: Không có key 'None' ở đây, vì chúng ta sẽ xử lý None thành 'ordered' trước khi kiểm tra
}

# Cập nhật trạng thái của OrderItem
def update_order_status(db: Session, order_item_id: int, status: str):
    if status not in VALID_ORDER_ITEM_STATUSES:
        raise HTTPException(
            status_code=400,
            detail=(f"Invalid status value '{status}' provided. "
                    f"Allowed statuses are: {', '.join(VALID_ORDER_ITEM_STATUSES)}")
        )

    # Truy vấn order_item cùng với order luôn
    order_item = db.query(models.OrderItem).filter(
        models.OrderItem.order_item_id == order_item_id
    ).first()

    if not order_item:
        raise HTTPException(status_code=404, detail="Order item not found")

    current_item_status = order_item.status or "ordered"
    if current_item_status not in VALID_ORDER_ITEM_STATUSES:
        raise HTTPException(
            status_code=500,
            detail=f"Order item has an invalid current status '{current_item_status}' in the database."
        )

    allowed_next_statuses = ALLOWED_TRANSITIONS.get(current_item_status, [])
    if status not in allowed_next_statuses:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid status transition from '{current_item_status}' to '{status}'"
        )

    # Cập nhật trạng thái của item
    order_item.status = status

    # Lấy order liên quan và tất cả item khác trong order đó
    order_id = order_item.order_id
    all_items = db.query(models.OrderItem).filter(
        models.OrderItem.order_id == order_id
    ).all()

    order = db.query(models.Order).filter(
        models.Order.order_id == order_id
    ).first()

    order_final_status = None

    if order:
        # Cập nhật order status nếu cần
        all_statuses = [item.status or "ordered" for item in all_items]

        if all(status == "served" for status in all_statuses):
            new_order_status = "served"
        elif any(status == "served" for status in all_statuses):
            new_order_status = "in_progress"
        else:
            new_order_status = order.status  # không đổi

        if new_order_status != order.status:
            order.status = new_order_status

        order_final_status = order.status

    # Chỉ commit một lần sau khi xử lý xong cả item và order
    db.commit()

    # item_data_queue = {
    #     "order_item_id": order_item.order_item_id,
    #     "order_id": order_item.order_id,
    #     "item_id": order_item.item_id,
    #     "quantity": order_item.quantity,
    #     "status": order_item.status,
    #     "order_status": order_final_status,
    # }

    # try:
    #     redis_client.publish("kitchen:status_updates", json.dumps(item_data_queue))
    # except redis.RedisError as e:
    #     logger.error(f"Redis publish error: {str(e)}")

    return order_item

# Cập nhật trạng thái cả Order:
def complete_order(db: Session, order_id: int):
    order = db.query(models.Order).filter(models.Order.order_id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    item_exists = db.query(models.OrderItem).filter(models.OrderItem.order_id == order_id).first()
    if not item_exists:
        raise HTTPException(status_code=404, detail="No order items found for this order")

    db.query(models.OrderItem).filter(
        models.OrderItem.order_id == order_id
    ).update({models.OrderItem.status: "served"}, synchronize_session=False)

    db.query(models.Order).filter(
        models.Order.order_id == order_id
    ).update({models.Order.status: "served"}, synchronize_session=False)

    db.commit()

    return {
        "message": "Order completed successfully.",
        "order_id": order_id
    }


def toggle_menu_item_availability(db: Session, item_id: int, available: bool):
    menu_item = db.query(models.MenuItem).filter(
        models.MenuItem.item_id == item_id
    ).first()
    if not menu_item:
        raise HTTPException(status_code=404, detail="Menu item not found")

    menu_item.available = 1 if available else 0
    db.commit()
    db.refresh(menu_item)

    menu_update_data = {
        "item_id": menu_item.item_id,
        "name": menu_item.name,
        "available": bool(menu_item.available),
        "updated_time": datetime.now(timezone.utc).isoformat()
    }

    try:
        redis_client.publish("kitchen:menu_updates", json.dumps(menu_update_data))
    except redis.RedisError as e:
        logger.error(f"Redis publish error: {str(e)}")

    return menu_item

def get_order_items_with_menu_name(db: Session, order_id: int) -> List[OrderItemDetail]:
    results = (
        db.query(models.OrderItem, models.MenuItem.name)
        .join(models.MenuItem, models.OrderItem.item_id == models.MenuItem.item_id)
        .filter(models.OrderItem.order_id == order_id)
        .all()
    )

    order_items = []
    for order_item, name in results:
        item = OrderItemDetail(
            order_item_id=order_item.order_item_id,
            order_id=order_item.order_id,
            item_id=order_item.item_id,
            name=name,
            quantity=order_item.quantity,
            status=order_item.status
        )
        order_items.append(item)

    return order_items

