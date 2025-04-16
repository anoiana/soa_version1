from email.mime.text import MIMEText
import smtplib
from typing import Dict, List
import requests  # ✅ Dùng thư viện requests chuẩn
from app.database import get_firebase_db
from firebase_admin import auth
from firebase_admin.auth import UserNotFoundError

FIREBASE_API_KEY = "AIzaSyCwbBxt5US6rbhM7PMGWiX0JsxisZFywjA"  # 🔥 Thay bằng API Key của Firebase

def login_user(email: str, password: str) -> dict:
    try:
        # ✅ Gửi request đến Firebase Authentication để đăng nhập
        url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={FIREBASE_API_KEY}"
        payload = {
            "email": email,
            "password": password,
            "returnSecureToken": True
        }

        response = requests.post(url, json=payload)
        result = response.json()

        if "idToken" in result:
            return {
                "message": "Login successful",
                "user_id": result["localId"],  # UID của user
                "email": result["email"],
                "token": result["idToken"]  # Token để xác thực các API sau này
            }
        else:
            return {"error": "Invalid email or password"}
    
    except Exception as e:
        return {"error": f"Lỗi đăng nhập: {str(e)}"}

def format_phone_number(phone: str) -> str:
    """ Chuyển đổi số điện thoại thành định dạng E.164 (thêm mã quốc gia nếu thiếu) """
    if phone.startswith("+"):
        return phone  # Đã đúng định dạng
    
    # Giả sử Việt Nam (+84), bạn có thể thay đổi tùy theo quốc gia
    if phone.startswith("0"):
        return "+84" + phone[1:]  # Bỏ số 0 đầu và thêm +84

    raise ValueError("Số điện thoại không hợp lệ!")

def create_user(name: str, email: str, phone: str, password: str):
    try:
        phone_e164 = format_phone_number(phone)  # 🔥 Chuyển đổi số điện thoại
        
        # ✅ Tạo user trên Firebase Authentication với số điện thoại
        user = auth.create_user(
            email=email,
            phone_number=phone_e164,  # 🔥 Đưa số điện thoại chuẩn E.164 vào đây
            email_verified=False,
            password=password
        )

        # ✅ Lưu thông tin vào Firebase Realtime Database (nếu cần)
        ref = get_firebase_db().child("users").child(user.uid)
        ref.set({
            "name": name,
            "email": email,
            "phone": phone_e164
        })

        return {"message": "User created successfully", "user_id": user.uid}

    except auth.EmailAlreadyExistsError:
        return {"error": "Email đã tồn tại, vui lòng sử dụng email khác."}

    except auth.PhoneNumberAlreadyExistsError:
        return {"error": "Số điện thoại đã được đăng ký, vui lòng sử dụng số khác."}

    except ValueError as e:
        return {"error": str(e)}
    
    except Exception as e:
        return {"error": f"Lỗi không xác định: {str(e)}"}
# Lấy thông tin người dùng từ Realtime Database
def get_user(user_id: str):
    ref = get_firebase_db().child("users").child(user_id)
    user_data = ref.get()
    if user_data:
        return user_data
    return {"message": "User not found"}

# Lấy danh sách người dùng từ Firebase Authentication
# Hàm lấy danh sách users
def get_all_users() -> List[Dict[str, str]]:
    users = auth.list_users().iterate_all()
    return [{"uid": user.uid, "email": user.email} for user in users]

# Đặt lại mật khẩu bằng email
def send_password_reset(email: str) -> dict:
        
    try:
        # Kiểm tra email có tồn tại không
        user = auth.get_user_by_email(email)
        
        # Tạo link đặt lại mật khẩu
        reset_link = auth.generate_password_reset_link(email)

        # Gửi email qua SMTP
        sender = "SOA Restaurant"  # Thay bằng Sender name và From từ Firebase Template
        msg = MIMEText(f"Nhấn vào đây để đặt lại mật khẩu: {reset_link}")
        msg["Subject"] = "Đặt lại mật khẩu"
        msg["From"] = sender
        msg["To"] = email
        
        # Cấu hình SMTP (dùng Gmail làm ví dụ)
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login("shopthinhtan@gmail.com", "dtls wcaw hjfe hncf")  # Thay bằng email và App Password
            server.send_message(msg)

        return {"message": "Password reset link sent successfully", "reset_link": reset_link}
    except UserNotFoundError:
        raise ValueError("Email này chưa đăng ký trong hệ thống.")
    except Exception as e:
        raise ValueError(f"Lỗi khi gửi email: {str(e)}")




