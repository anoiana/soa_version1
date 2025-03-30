from sqlalchemy import create_engine, Column, Integer, String, Boolean, ForeignKey
from sqlalchemy.orm import sessionmaker, relationship, declarative_base
import os
import firebase_admin
from firebase_admin import credentials, db

DATABASE_URL = "mysql+pymysql://root:root@localhost:3306/soa_gk"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Load credentials từ file JSON
cred = credentials.Certificate("soa-gk-1ab71-firebase-adminsdk-fbsvc-e936728e32.json")
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://soa-gk-1ab71-default-rtdb.asia-southeast1.firebasedatabase.app/'  # Thay thế bằng URL thực tế của bạn
})

# Hàm lấy tham chiếu đến Firebase Database
def get_firebase_db():
    return db.reference() 