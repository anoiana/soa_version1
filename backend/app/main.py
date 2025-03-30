from fastapi import FastAPI
from contextlib import asynccontextmanager
from app.routers import order, menu, payment, shift, kitchen, user
from app.database import SessionLocal
from app.services.shift_service import create_shifts_for_today

# Lifespan event handler
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("Ứng dụng khởi động...")
    db = SessionLocal()
    create_shifts_for_today(db)
    db.close()
    print("Khởi động thành công")
    yield  # Để ứng dụng chạy bình thường sau khi khởi động

# Khởi tạo FastAPI với lifespan
app = FastAPI(title="Restaurant API", lifespan=lifespan)

# Đăng ký router
app.include_router(order.router)
app.include_router(menu.router)
app.include_router(shift.router)
app.include_router(kitchen.router)
app.include_router(payment.router)
app.include_router(user.router)

@app.get("/")
def root():
    return {"message": "Welcome to Restaurant API"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000, reload=True)
