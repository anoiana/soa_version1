from typing import List, Optional
from fastapi import HTTPException
from sqlalchemy.orm import Session
from app.models import MenuItem,BuffetPackage,PackageItem, Table
from app.schemas import MenuItemCreate, MenuItemResponse, MenuItemUpdate,BuffetPackageCreate, BuffetPackageUpdate, PackageItemBase

# Lấy tất cả món ăn trong menumenu
def get_all_menu_items(db: Session):
    return db.query(MenuItem).all()

# Lấy món ăn theo id
def get_menu_item(db: Session, item_id: int):
    return db.query(MenuItem).filter(MenuItem.item_id == item_id).first()

# Tạo món ăn mới
def create_menu_item(db: Session, items: List[MenuItemCreate]) -> List[MenuItemResponse]:
    """Tạo nhiều món ăn cùng lúc."""
    created_items = []
    for item in items:
        new_item = MenuItem(**item.model_dump())
        db.add(new_item)
        db.commit()
        db.refresh(new_item)
        created_items.append(MenuItemResponse.model_validate(new_item, from_attributes=True)) 
    return created_items

# Lấy danh sách món ăn theo gói buffet
def get_menu_items_by_package(db: Session, package_id: int) -> List[MenuItemResponse]:
    """Trả về danh sách món ăn thuộc gói buffet đã chọn."""
    
    # Kiểm tra xem gói buffet có tồn tại không
    package = db.query(BuffetPackage).filter(
        BuffetPackage.package_id == package_id
    ).first()

    if not package:
        raise HTTPException(status_code=404, detail="Gói buffet không tồn tại")

    # Truy vấn danh sách món ăn thuộc gói buffet
    menu_items = db.query(MenuItem).join(PackageItem).filter(
        PackageItem.package_id == package_id
    ).all()

    return [MenuItemResponse.model_validate(item, from_attributes=True) for item in menu_items]

# Cập nhật món ăn theo id
def update_menu_item(db: Session, item_id: int, item: MenuItemUpdate):
    db_item = db.query(MenuItem).filter(MenuItem.item_id == item_id).first()
    if db_item:
        for key, value in item.model_dump(exclude_unset=True).items():
            setattr(db_item, key, value)
        db.commit()
        db.refresh(db_item)
    return db_item

# Xóa món ăn theo id
def delete_menu_item(db: Session, item_id: int):
    db_item = db.query(MenuItem).filter(MenuItem.item_id == item_id).first()
    if db_item:
        db.delete(db_item)
        db.commit()
        return True
    return False

# ----------------------Buffet------------------------
# Lấy tất cả gói buffet
def get_all_packages(db: Session):
    return db.query(BuffetPackage).all()

# Lấy gói buffet theo id
def get_package(db: Session, package_id: int):
    return db.query(BuffetPackage).filter(BuffetPackage.package_id == package_id).first()

# Tạo gói buffet mới
def create_package(db: Session, package: BuffetPackageCreate):
    new_package = BuffetPackage(**package.model_dump())
    db.add(new_package)
    db.commit()
    db.refresh(new_package)
    return new_package

# Cập nhật gói buffet theo id
def update_package(db: Session, package_id: int, package: BuffetPackageUpdate):
    db_package = db.query(BuffetPackage).filter(BuffetPackage.package_id == package_id).first()
    if db_package:
        for key, value in package.model_dump(exclude_unset=True).items():
            setattr(db_package, key, value)
        db.commit()
        db.refresh(db_package)
    return db_package

# Xóa gói buffet 
def delete_package(db: Session, package_id: int):
    db_package = db.query(BuffetPackage).filter(BuffetPackage.package_id == package_id).first()
    if db_package:
        db.delete(db_package)
        db.commit()
        return True
    return False

# Thêm món ăn vào gói buffet
def add_menu_items_to_package(db: Session, data: List[PackageItemBase]):
    """Thêm một danh sách các mục menu vào gói buffet."""
    added_items = []
    for item_data in data:
        package_item = PackageItem(package_id=item_data.package_id, item_id=item_data.item_id)
        db.add(package_item)
        db.commit()
        db.refresh(package_item)
        added_items.append(package_item) # or use Pydantic response model.
    return added_items

# Xoa món ăn khỏi gói buffet
def remove_menu_item_from_package(db: Session, package_id: int, item_id: int):
    package_item = db.query(PackageItem).filter(
        PackageItem.package_id == package_id, PackageItem.item_id == item_id
    ).first()
    if package_item:
        db.delete(package_item)
        db.commit()
        return True
    return False

# --------------------------------QUẢN LÝ TRẠNG THÁI BÀN--------------------------------
def get_all_tables_status(db: Session, status: Optional[str] = None):
    """Lấy danh sách tất cả bàn, có thể lọc theo trạng thái."""
    query = db.query(Table)
    if status:
        query = query.filter(Table.status == status)

    tables = query.all()
    return [{"table_number": table.table_number, "status": table.status} for table in tables]
