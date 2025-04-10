from sqlalchemy.orm import Session
from app import models
import redis
import json
from typing import List
from fastapi import HTTPException
from datetime import datetime, timezone

# Kết nối Redis
redis_client = redis.Redis(host='localhost', port=6379, db=0)

def get_pending_orders(db: Session) -> List[dict]:
    pending_items = (
        db.query(models.Order, models.OrderItem, models.MenuItem)
        .join(models.OrderItem, models.Order.order_id == models.OrderItem.order_id)
        .join(models.MenuItem, models.OrderItem.item_id == models.MenuItem.item_id)
        .filter(models.OrderItem.status.in_(["ordered"]))
        .order_by(models.Order.order_time.asc())
        .all()
    )

    orders = {}
    for order, item, menu_item in pending_items:
        if order.order_id not in orders:
            orders[order.order_id] = {
                "order_id": order.order_id,
                "session_id": order.session_id,
                "order_time": order.order_time.isoformat(),
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

def get_queue_updates() -> List[dict]:
    queue_data = redis_client.lrange("kitchen_queue", 0, -1)
    return [json.loads(item) for item in queue_data]

def update_order_status(db: Session, order_item_id: int, status: str):
    """
    Cập nhật trạng thái của từng order_item và kiểm tra xem order có hoàn thành không.
    """
    order_item = db.query(models.OrderItem).filter(
        models.OrderItem.order_item_id == order_item_id
    ).first()
    if not order_item:
        raise HTTPException(status_code=404, detail="Order item not found")

    valid_statuses = ["ordered", "preparing", "ready", "served"]
    if status not in valid_statuses:
        raise HTTPException(status_code=400, detail="Invalid status")

    order_item.status = status
    db.commit()
    db.refresh(order_item)

    all_items = db.query(models.OrderItem).filter(
        models.OrderItem.order_id == order_item.order_id
    ).all()
    is_order_completed = all(item.status in ["ready", "served"] for item in all_items)

    item_data_queue = {
        "order_item_id": order_item.order_item_id,
        "order_id": order_item.order_id,
        "item_id": order_item.item_id,
        "quantity": order_item.quantity,
        "status": order_item.status,
        "order_completed": is_order_completed
    }
    redis_client.rpush("kitchen_queue", json.dumps(item_data_queue))

    if is_order_completed:
        order_complete_data = {
            "order_id": order_item.order_id,
            "status": "completed",
            "completed_time": datetime.now(timezone.utc).isoformat()
        }
        redis_client.rpush("kitchen_queue", json.dumps(order_complete_data))

    return order_item

# Bật tắt món ăn trong menu
def toggle_menu_item_availability(db: Session, item_id: int, available: bool):
    """
    Bật/tắt trạng thái khả dụng của món ăn trong menu (available là tinyint: 0/1).
    """
    menu_item = db.query(models.MenuItem).filter(
        models.MenuItem.item_id == item_id
    ).first()
    if not menu_item:
        raise HTTPException(status_code=404, detail="Menu item not found")

    # Chuyển bool thành tinyint (True -> 1, False -> 0)
    menu_item.available = 1 if available else 0
    db.commit()
    db.refresh(menu_item)

    # Đẩy thông báo vào Redis queue để frontend cập nhật menu
    menu_update_data = {
        "item_id": menu_item.item_id,
        "name": menu_item.name,
        "available": bool(menu_item.available),  # Chuyển lại thành bool cho frontend
        "updated_time": datetime.now(timezone.utc).isoformat()
    }
    redis_client.rpush("menu_updates", json.dumps(menu_update_data))

    return menu_item

def get_menu_updates():
    """
    Lấy tất cả cập nhật trạng thái menu từ Redis queue 'menu_updates'.
    """
    updates = redis_client.lrange("menu_updates", 0, -1)
    return [json.loads(update) for update in updates] if updates else []