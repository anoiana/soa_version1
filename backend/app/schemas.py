from pydantic import BaseModel, ConfigDict
from decimal import Decimal
from datetime import datetime
from typing import List, Optional
# USER SERVICE
class UserCreate(BaseModel):
    name: str
    email: str
    phone: str
    password: str

# Schema đăng nhập
class UserLogin(BaseModel):
    email: str
    password: str

# MENU SERVICE
class MenuItemBase(BaseModel):
    name: str
    category: str | None = None
    available: bool = True
    img: str | None = None

class MenuItemCreate(MenuItemBase):
    pass

class MenuItemUpdate(MenuItemBase):
    pass

class MenuItemResponse(MenuItemBase):
    item_id: int
    model_config = ConfigDict(from_attributes=True)

# BUFFET SERVICE
class BuffetPackageBase(BaseModel):
    name: str
    description: str | None = None
    price_per_person: Decimal
    img: str | None = None

class BuffetPackageCreate(BuffetPackageBase):
    pass

class BuffetPackageUpdate(BuffetPackageBase):
    pass

class BuffetPackageResponse(BuffetPackageBase):
    package_id: int

    class Config:
        from_attributes = True

class PackageItemBase(BaseModel):
    package_id: int
    item_id: int

# ORDER SERVICE
class OrderItemCreate(BaseModel):
    item_id: int
    quantity: int

class OrderCreate(BaseModel):
    table_number: int  # Nhận số bàn từ request
    items: List[OrderItemCreate]

class OrderItem(BaseModel):
    order_item_id: int
    order_id: int
    item_id: int
    quantity: int
    status: str

    class Config:
        from_attributes = True  # Để map từ SQLAlchemy model

class Order(BaseModel):
    order_id: int
    session_id: int
    order_time: datetime  # ISO format
    items: List[OrderItem] = []

    class Config:
        from_attributes = True

# TABLE SESSIONS
class TableSessionBase(BaseModel):
    number_of_customers: int
    package_id: Optional[int] = None
    shift_id: Optional[int] = None

class TableSessionCreate(BaseModel):
    table_number: str  # Nhập số bàn thay vì table_id
    number_of_customers: int    
    secret_code: str 

class Table_UpdatePackage(BaseModel):
    table_number: str
    package_id: int

class TableSessionClose(BaseModel):
    secret_code: str
    
class TableSessionResponse(TableSessionBase):
    session_id: int
    start_time: datetime
    end_time: Optional[datetime] = None
    table_id: int
    class Config:
        from_attributes = True

class TableStatus(BaseModel):
    table_number: int
    status: str
# SHIFT
class ShiftResponse(BaseModel):
    shift_id: int
    start_time: datetime
    end_time: datetime

    class Config:
        from_attributes = True  # Cho phép chuyển đổi từ SQLAlchemy model

# PAYMENT
class PaymentCreate(BaseModel):
    session_id: int
    amount: Decimal
    payment_method: Optional[str] = None  # Ví dụ: "Cash", "Credit Card"

class PaymentResponse(BaseModel):
    payment_id: int
    session_id: int
    amount: Decimal
    payment_time: datetime
    payment_method: str

    class Config:
        from_attributes = True