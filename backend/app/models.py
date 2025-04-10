from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo
from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, Float,Text, DECIMAL, DateTime
from sqlalchemy.orm import relationship
from app.database import Base

# TABLE SERVICE
class Table(Base):
    __tablename__ = "table"
    table_id = Column(Integer, primary_key=True, index=True)
    table_number = Column(String, nullable=False)
    status = Column(String, default="ready")

# BUFFET SERVICE
class BuffetPackage(Base):
    __tablename__ = "buffet_package"

    package_id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    description = Column(Text)
    price_per_person = Column(DECIMAL, nullable=False)
    img = Column(String)
    items = relationship("PackageItem", back_populates="buffet_package")

class PackageItem(Base):
    __tablename__ = "package_item"

    package_id = Column(Integer, ForeignKey("buffet_package.package_id"), primary_key=True)
    item_id = Column(Integer, ForeignKey("menu_item.item_id"), primary_key=True)

    buffet_package = relationship("BuffetPackage", back_populates="items")
    menu_item = relationship("MenuItem", back_populates="packages")

# MENU SERVICE
class MenuItem(Base):
    __tablename__ = "menu_item"

    item_id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    category = Column(Text)
    available = Column(Boolean, default=True)
    img = Column(String)
    packages = relationship("PackageItem", back_populates="menu_item")

# ORDER SERVICE
class Order(Base):
    __tablename__ = "order"
    order_id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("table_session.session_id"), nullable=False)
    order_time = Column(DateTime, nullable=False)
    items = relationship("OrderItem", back_populates="order")

class OrderItem(Base):
    __tablename__ = "order_item"
    order_item_id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("order.order_id"), nullable=False)
    item_id = Column(Integer, ForeignKey("menu_item.item_id"), nullable=False)
    quantity = Column(Integer, default=1)
    status = Column(String, default="ordered")
    order = relationship("Order", back_populates="items")
    menu_item = relationship("MenuItem")

class TableSession(Base):
    __tablename__ = "table_session"
    session_id = Column(Integer, primary_key=True, index=True)
    table_id = Column(Integer, ForeignKey("table.table_id"), nullable=False)
    start_time = Column(DateTime, nullable=False)
    end_time = Column(DateTime, nullable=True)
    number_of_customers = Column(Integer, nullable=False)
    package_id = Column(Integer, ForeignKey("buffet_package.package_id"), nullable=True)
    shift_id = Column(Integer, ForeignKey("shift.shift_id"), nullable=True)

    table = relationship("Table")
    package = relationship("BuffetPackage")
    shift = relationship("Shift")
    # ✅ Thêm mối quan hệ với Payment
    payment = relationship("Payment", back_populates="session", uselist=False)  
class Shift(Base):
    __tablename__ = "shift"

    shift_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    start_time = Column(DateTime, nullable=False)
    end_time = Column(DateTime, nullable=False)
    secret_code = Column(String(10), nullable=False, unique=True)

    @classmethod
    def create_shift(cls, start_time: datetime, secret_code: str):
        """Tạo một ca làm mới với thời gian tự động tính toán"""
        return cls(
            start_time=start_time,
            end_time=start_time + timedelta(hours=6),  
            secret_code=secret_code
        ) 

class Payment(Base):
    __tablename__ = "payment"

    payment_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    session_id = Column(Integer, ForeignKey("table_session.session_id"), nullable=False, unique=True)
    amount = Column(DECIMAL(10, 2), nullable=False)
    payment_time = Column(DateTime, default=datetime.now(ZoneInfo("Asia/Ho_Chi_Minh")))
    payment_method = Column(String(50), nullable=True)  # Phương thức thanh toán (tiền mặt, thẻ, v.v.)

    # Liên kết với TableSession
    session = relationship("TableSession", back_populates="payment")