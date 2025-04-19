from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.services import menu_service, kitchen_service
from app.schemas import MenuItemCreate, MenuItemUpdate, MenuItemResponse,BuffetPackageCreate, BuffetPackageUpdate, BuffetPackageResponse, PackageItemBase, TableStatus

router = APIRouter(prefix="/menu", tags=["Menu"])

# Lấy danh sách món ăn
@router.get("/", response_model=list[MenuItemResponse])
def get_menu(db: Session = Depends(get_db)):
    return menu_service.get_all_menu_items(db)

# Lấy menu dựa trên gói buffet 
@router.get("/packages/{package_id}/menu-items", response_model=List[MenuItemResponse])
def get_menu_by_package(package_id: int, db: Session = Depends(get_db)):
    return menu_service.get_menu_items_by_package(db, package_id)

# 	Lấy chi tiết món ăn
@router.get("/{item_id}", response_model=MenuItemResponse)
def get_menu_item(item_id: int, db: Session = Depends(get_db)):
    item = menu_service.get_menu_item(db, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Món ăn không tồn tại")
    return item

# 	Thêm món ăn mới
@router.post("/", response_model=List[MenuItemResponse])
def create_menu_item(item: List[MenuItemCreate], db: Session = Depends(get_db)):
    return menu_service.create_menu_item(db, item)

# Cập nhật món ăn
@router.put("/{item_id}", response_model=MenuItemResponse)
def update_menu_item(item_id: int, item: MenuItemUpdate, db: Session = Depends(get_db)):
    updated_item = menu_service.update_menu_item(db, item_id, item)
    if not updated_item:
        raise HTTPException(status_code=404, detail="Món ăn không tồn tại")
    return updated_item

# Xóa món ăn
@router.delete("/{item_id}")
def delete_menu_item(item_id: int, db: Session = Depends(get_db)):
    if not menu_service.delete_menu_item(db, item_id):
        raise HTTPException(status_code=404, detail="Món ăn không tồn tại")
    return {"message": "Món ăn đã được xóa"}

# Cập nhật trạng thái món ăn
@router.patch("/{item_id}/status")
def update_menu_status(item_id: int, available: bool, db: Session = Depends(get_db)):
    updated_item = kitchen_service.toggle_menu_item_availability(db, item_id, available)
    if not updated_item:
        raise HTTPException(status_code=404, detail="Món ăn không tồn tại")
    return {"message": "Cập nhật trạng thái món ăn thành công"}

# ---------------------Buffet--------------------------------
@router.get("/buffet/", response_model=list[BuffetPackageResponse])
def get_all_packages(db: Session = Depends(get_db)):
    return menu_service.get_all_packages(db)

# Lấy buffet theo id
@router.get("/buffet/{package_id}", response_model=BuffetPackageResponse)
def get_package(package_id: int, db: Session = Depends(get_db)):
    package = menu_service.get_package(db, package_id)
    if not package:
        raise HTTPException(status_code=404, detail="Gói buffet không tồn tại")
    return package

# Thêm buffet mới
@router.post("/buffet/", response_model=BuffetPackageResponse)
def create_package(package: BuffetPackageCreate, db: Session = Depends(get_db)):
    return menu_service.create_package(db, package)

# Cập nhật buffet theo id
@router.put("/buffet/{package_id}", response_model=BuffetPackageResponse)
def update_package(package_id: int, package: BuffetPackageUpdate, db: Session = Depends(get_db)):
    updated_package = menu_service.update_package(db, package_id, package)
    if not updated_package:
        raise HTTPException(status_code=404, detail="Gói buffet không tồn tại")
    return updated_package

# Xóa buffet theo id
@router.delete("/buffet/{package_id}")
def delete_package(package_id: int, db: Session = Depends(get_db)):
    if not menu_service.delete_package(db, package_id):
        raise HTTPException(status_code=404, detail="Gói buffet không tồn tại")
    return {"message": "Gói buffet đã được xóa"}

# Thêm món ăn vào gói buffet
@router.post("/buffet/add-menu-item")  # Đổi tên endpoint cho phù hợp
def add_menu_items_to_package(data: List[PackageItemBase], db: Session = Depends(get_db)):
    return menu_service.add_menu_items_to_package(db, data)

# Xóa món ăn khỏi gói buffet
@router.delete("/buffet/remove-menu-item")
def remove_menu_item_from_package(data: PackageItemBase, db: Session = Depends(get_db)):
    if not menu_service.remove_menu_item_from_package(db, data.package_id, data.item_id):
        raise HTTPException(status_code=404, detail="Món ăn không tồn tại trong gói buffet")
    return {"message": "Món ăn đã được xóa khỏi gói buffet"}



# ----------------------------API QUẢN LÝ TRẠNG THÁI BÀN------------------------------------
@router.get("/tables/status", response_model=list[TableStatus])
def get_tables_status(
    status: Optional[str] = Query(None, description="Lọc theo trạng thái bàn (Eating, Ready, Cleaning,...)"),
    db: Session = Depends(get_db)
):
    """API lấy danh sách bàn, có thể lọc theo trạng thái."""
    return menu_service.get_all_tables_status(db, status)