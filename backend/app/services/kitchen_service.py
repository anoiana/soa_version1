import os
from sqlalchemy.orm import Session
from app import models
import redis
import json
from typing import List
from fastapi import HTTPException
from datetime import datetime, timezone

# Kết nối Redis
redis_client = redis.Redis(
    host=os.getenv("REDISHOST"),
    port=int(os.getenv("REDISPORT")),
    password=os.getenv("REDISPASSWORD"),
    decode_responses=True
)

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
    updates = []
    while True:
        item = redis_client.lpop("kitchen_queue")
        if not item:
            break
        try:
            updates.append(json.loads(item))
        except json.JSONDecodeError:
            continue
    return updates

def update_order_status(db: Session, order_item_id: int, status: str):
    """
    Cập nhật trạng thái của một OrderItem và Order tương ứng.

    Args:
        db: Đối tượng Session của SQLAlchemy.
        order_item_id: ID của OrderItem cần cập nhật.
        status: Trạng thái mới muốn cập nhật cho OrderItem.
                 Phải là một trong VALID_ORDER_ITEM_STATUSES.

    Raises:
        HTTPException(400): Nếu status đầu vào không hợp lệ hoặc
                             việc chuyển trạng thái không được phép.
        HTTPException(404): Nếu order_item_id không tồn tại.

    Returns:
        Đối tượng OrderItem đã được cập nhật.
    """

    # 1. Kiểm tra xem status đầu vào có hợp lệ không
    if status not in VALID_ORDER_ITEM_STATUSES:
        raise HTTPException(
            status_code=400,
            detail=(f"Invalid status value '{status}' provided. "
                    f"Allowed statuses are: {', '.join(VALID_ORDER_ITEM_STATUSES)}")
        )

    # 2. Lấy thông tin của order_item
    order_item = db.query(models.OrderItem).filter(
        models.OrderItem.order_item_id == order_item_id
    ).first()
    if not order_item:
        raise HTTPException(status_code=404, detail="Order item not found")

    # 3. Xác định trạng thái hiện tại và xử lý nếu là None
    current_item_status = order_item.status
    # Nếu trạng thái hiện tại là None, coi nó như là 'ordered' cho mục đích kiểm tra chuyển đổi
    if current_item_status is None:
        current_item_status_for_check = "ordered"
    else:
        # Đảm bảo trạng thái hiện tại trong DB (nếu không phải None) cũng là một trạng thái hợp lệ
        # Điều này giúp bắt lỗi nếu dữ liệu trong DB có vấn đề
        if current_item_status not in VALID_ORDER_ITEM_STATUSES:
             raise HTTPException(
                 status_code=500, # Lỗi server vì dữ liệu DB không nhất quán
                 detail=f"Order item has an invalid current status '{current_item_status}' in the database."
             )
        current_item_status_for_check = current_item_status

    # 4. Kiểm tra xem việc chuyển trạng thái có được phép không
    allowed_next_statuses = ALLOWED_TRANSITIONS.get(current_item_status_for_check, [])
    if status not in allowed_next_statuses:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid status transition from '{current_item_status_for_check}' to '{status}'"
        )

    # 5. Cập nhật trạng thái của order_item
    order_item.status = status
    # Lưu ý: Chúng ta *không* tự động đổi order_item.status thành "ordered" nếu nó là None
    # Chúng ta chỉ cập nhật nó thành giá trị 'status' hợp lệ đã được kiểm tra.
    db.commit()
    db.refresh(order_item)

    # --- Logic cập nhật Order status ---
# 6. Lấy lại tất cả item và order (sau khi item đã commit)
    all_items = db.query(models.OrderItem).filter(
        models.OrderItem.order_id == order_item.order_id
    ).all()

    order = db.query(models.Order).filter(
        models.Order.order_id == order_item.order_id
    ).first()

    order_final_status = None # Để lưu trạng thái cuối cùng gửi qua Redis

    if order:
        # Xác định trạng thái hiện tại của Order (coi None như "ordered")
        is_order_effectively_ordered = (order.status is None or order.status == "ordered")

        # Kiểm tra điều kiện cập nhật trạng thái Order
        # all() sẽ trả về True nếu list rỗng, nên cần kiểm tra all_items có phần tử không
        all_items_served = bool(all_items) and all(item.status == "served" for item in all_items)
        # any() trả về False nếu list rỗng
        any_item_progressed = any(item.status in ["ready", "served"] for item in all_items)

        new_order_status = order.status # Mặc định là không đổi

        if all_items_served:
            new_order_status = "served"
        elif any_item_progressed and is_order_effectively_ordered:
            new_order_status = "in_progress"

        # Chỉ commit nếu trạng thái thực sự thay đổi
        if new_order_status != order.status:
            order.status = new_order_status
            db.commit()
            db.refresh(order)

        order_final_status = order.status # Lấy trạng thái sau khi có thể đã refresh
    # Kết thúc khối if order:

    # 7. Tạo thông tin để push vào Redis
    item_data_queue = {
        "order_item_id": order_item.order_item_id,
        "order_id": order_item.order_id,
        "item_id": order_item.item_id,
        "quantity": order_item.quantity,
        "status": order_item.status,           # Trạng thái item vừa cập nhật
        "order_status": order_final_status,    # Trạng thái order sau khi xử lý
    }

    # 8. Push dữ liệu vào Redis (kitchen_queue)
    try:
        # Giả sử redis_client đã được khởi tạo và kết nối ở đâu đó
        redis_client.rpush("kitchen_queue", json.dumps(item_data_queue))
    except NameError:
         print("Redis error: redis_client is not defined.") # Nên dùng logging
    except redis.RedisError as e:
        # Nên sử dụng logging thay vì print trong ứng dụng thực tế
        print(f"Redis error when pushing order item {order_item.order_item_id}: {e}")
    except Exception as e:
        print(f"An unexpected error occurred during Redis push: {e}") # Nên dùng logging

    # 9. Trả về đối tượng order_item đã cập nhật
    return order_item

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
        redis_client.rpush("menu_updates", json.dumps(menu_update_data))
    except redis.RedisError as e:
        print("Redis error when pushing menu update:", str(e))

    return menu_item

def get_menu_updates():
    updates = []
    while True:
        update = redis_client.lpop("menu_updates")
        if not update:
            break
        try:
            updates.append(json.loads(update))
        except json.JSONDecodeError:
            continue
    return updates
