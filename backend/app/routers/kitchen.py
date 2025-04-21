import json
from typing import List
from fastapi import APIRouter, Depends, WebSocket
from sqlalchemy.orm import Session
from app.services import kitchen_service
from app import schemas
from app.database import SessionLocal
import asyncio
from app.database import get_db
from app.redis_client import redis_client
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# redis_client = redis.Redis(
#     host=os.getenv("REDISHOST"),
#     port=int(os.getenv("REDISPORT")),
#     password=os.getenv("REDISPASSWORD"),
#     decode_responses=True
# )

router = APIRouter( prefix="/kitchen", tags=["Kitchen"])

# Lấy danh sách món ăn
@router.get("/get-orders/", response_model=list[dict])
async def get_kitchen_orders(db: Session = Depends(get_db)):
    return kitchen_service.get_pending_orders(db)

@router.get("/get-orders-by-status/{status}", response_model=list[dict])
async def get_orders_by_status(status: str, db: Session = Depends(get_db)):
    return kitchen_service.get_orders_by_status(db, status)

# Cập nhật trạng thái món ăn
@router.patch("/order-items/{order_item_id}/status", response_model=schemas.OrderItem)
def patch_order_item_status(order_item_id: int, status: str, db: Session = Depends(get_db)):
    return kitchen_service.update_order_status(db, order_item_id, status)

# Lấy danh sách món ăn trong 1 order
@router.get("/order/{order_id}/items", response_model=List[schemas.OrderItemDetail])
def get_order_items(order_id: int, db: Session = Depends(get_db)):
    return kitchen_service.get_order_items_with_menu_name(db, order_id)

# 
@router.patch("/order/complete/{order_id}")
def api_complete_order(order_id: int, db: Session = Depends(get_db)):
    return kitchen_service.complete_order(db, order_id)

# WebSocket
# @router.websocket("/ws")
# async def websocket_kitchen(websocket: WebSocket):
#     await websocket.accept()
#     db: Session = SessionLocal()
#     pubsub = redis_client.pubsub()
#     pubsub.subscribe("kitchen:orders")
    
#     try:
#         pending_orders = kitchen_service.get_pending_orders(db)
#         await websocket.send_json({"orders": pending_orders})

#         async with asyncio.timeout(300):
#             while True:
#                 message = pubsub.get_message(timeout=1.0)
#                 if message and message["type"] == "message":
#                     try:
#                         data = json.loads(message["data"])
#                         if message["channel"] == "kitchen:orders":
#                             await websocket.send_json({"order": data})
#                     except json.JSONDecodeError:
#                         logger.error("Invalid JSON in Redis message")
#                 await asyncio.sleep(0.1)
#     except asyncio.TimeoutError:
#         logger.info("WebSocket timeout")
#     except Exception as e:
#         logger.error(f"WebSocket error: {str(e)}")
#     finally:
#         db.close()
#         pubsub.close()
#         await websocket.close()

@router.put("/menu_items/{item_id}/availability")
async def toggle_menu_item_availability(item_id: int, available: bool, db: Session = Depends(get_db)):
    return kitchen_service.toggle_menu_item_availability(db, item_id, available)

# @router.websocket("/ws/menu")
# async def websocket_menu_updates(websocket: WebSocket):
#     await websocket.accept()
#     pubsub = redis_client.pubsub()
#     pubsub.subscribe("kitchen:menu_updates")
    
#     try:
#         async with asyncio.timeout(300):
#             while True:
#                 message = pubsub.get_message(timeout=1.0)
#                 if message and message["type"] == "message":
#                     try:
#                         data = json.loads(message["data"])
#                         await websocket.send_json({"menu_updates": [data]})
#                     except json.JSONDecodeError:
#                         logger.error("Invalid JSON in Redis message")
#                 await asyncio.sleep(0.1)
#     except asyncio.TimeoutError:
#         logger.info("Menu WebSocket timeout")
#     except Exception as e:
#         logger.error(f"Menu WebSocket error: {str(e)}")
#     finally:
#         pubsub.close()
#         await websocket.close()