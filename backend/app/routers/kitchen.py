import json
from fastapi import APIRouter, Depends, WebSocket
from sqlalchemy.orm import Session
from app.services import kitchen_service
from app import schemas
from app.database import SessionLocal
import asyncio
from app.database import get_db

router = APIRouter( prefix="/kitchen", tags=["Kitchen"])

@router.get("/get-orders/", response_model=list[dict])
async def get_kitchen_orders(db: Session = Depends(get_db)):
    return kitchen_service.get_pending_orders(db)

# Cập nhật trạng thái món ăn
@router.patch("/order-items/{order_item_id}/status", response_model=schemas.OrderItem)
def patch_order_item_status(order_item_id: int, status: str, db: Session = Depends(get_db)):
    return kitchen_service.update_order_status(db, order_item_id, status)

@router.websocket("/ws")
async def websocket_kitchen(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            updates = kitchen_service.get_queue_updates()
            await websocket.send_json({"updates": updates})
            await asyncio.sleep(1)
    except Exception:
        await websocket.close()

@router.put("/menu_items/{item_id}/availability")
async def toggle_menu_item_availability(item_id: int, available: bool, db: Session = Depends(get_db)):
    return kitchen_service.toggle_menu_item_availability(db, item_id, available)

@router.websocket("/ws/menu")
async def websocket_menu_updates(websocket: WebSocket):
    """
    WebSocket để frontend khách nhận cập nhật trạng thái menu real-time.
    """
    await websocket.accept()
    try:
        while True:
            # Gọi hàm từ kitchen_service để lấy cập nhật
            menu_updates = kitchen_service.get_menu_updates()
            if menu_updates:
                await websocket.send_json({"menu_updates": menu_updates})
            await asyncio.sleep(1)  # Cập nhật mỗi giây
    except Exception:
        await websocket.close()