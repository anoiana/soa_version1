from sqlalchemy import create_engine, Column, Integer, String, Boolean, ForeignKey
from sqlalchemy.orm import sessionmaker, relationship, declarative_base
import os
import firebase_admin
from firebase_admin import credentials, db
import json

# DATABASE_URL = "mysql+pymysql://root:root@localhost:3306/soa_gk"
DATABASE_URL = "mysql+pymysql://root:IOLnqArrbQLwBGegpZwWzQXNFSmSQoiL@turntable.proxy.rlwy.net:38272/railway"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Lấy nội dung JSON từ biến môi trường
firebase_config_str = os.environ.get("FIREBASE_CONFIG")
if not firebase_config_str:
    raise Exception("FIREBASE_CONFIG env var not found")

# Ghi tạm ra file
with open("firebase_temp.json", "w") as f:
    f.write(firebase_config_str)

# Load credentials từ file JSON
cred = credentials.Certificate("firebase_temp.json")
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://soa-gk-1ab71-default-rtdb.asia-southeast1.firebasedatabase.app/'  # Thay thế bằng URL thực tế của bạn
})

# Hàm lấy tham chiếu đến Firebase Database
def get_firebase_db():
    return db.reference() 