import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'openTable.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controller cho mật khẩu và email
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Danh sách vai trò
  final List<String> _roles = ['Nhân viên phục vụ', 'Nhân viên bếp', 'Quản lý'];
  String? _selectedRole; // Vai trò được chọn

  // Trạng thái ẩn/hiện mật khẩu
  bool _obscurePassword = true;

  // Trạng thái loading
  bool _isLoading = false;

  // Hàm xử lý đăng nhập
  Future<void> _handleLogin() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng chọn vai trò'),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Vui lòng nhập ${(_selectedRole == "Nhân viên phục vụ" || _selectedRole == "Nhân viên bếp") ? "secret code" : "mật khẩu"}'),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    if (_selectedRole == "Quản lý" && _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng nhập email'),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_selectedRole == "Nhân viên phục vụ" || _selectedRole == "Nhân viên bếp") {
        // Gọi API đăng nhập nhân viên

        final response = await http.post(
          Uri.parse('https://soa-deploy.up.railway.app/user/employee/login?secret_code=${_passwordController.text}'),
          headers: {
            'Content-Type': 'application/json',
          },
        );
        if (response.statusCode == 200) {
          // Giả định phản hồi thành công
          final data = jsonDecode(utf8.decode(response.bodyBytes));

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] ?? 'Đăng nhập thành công với vai trò $_selectedRole',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              backgroundColor: Colors.green[700],
            ),
          );

          // Điều hướng nếu cần
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TableSelectionScreen()));
        } else {
          // Xử lý lỗi từ API
          final errorData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['error'] ?? 'Đăng nhập thất bại: Secret code không hợp lệ'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      } else {
        // Gọi API đăng nhập Quản lý
        final response = await http.post(
          Uri.parse('https://soa-deploy.up.railway.app/user/login/'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': _emailController.text,
            'password': _passwordController.text,
          }),
        );

        if (response.statusCode == 200) {
          // Giả định phản hồi thành công
          final data = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Đăng nhập thành công với vai trò Quản lý'),
              backgroundColor: Colors.green[700],
            ),
          );
          // Điều hướng nếu cần
          // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ManagerDashboard()));
        } else {
          // Xử lý lỗi từ API
          final errorData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['error'] ?? 'Đăng nhập thất bại: Thông tin không hợp lệ'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Hàm xử lý reset password (giả lập)
  void _handleResetPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Yêu cầu đặt lại mật khẩu đã được gửi'),
        backgroundColor: Colors.orange[700],
      ),
    );
    // Thêm logic reset password (gọi API, chuyển hướng, v.v.)
  }

  @override
  Widget build(BuildContext context) {
    // Kiểm tra kích thước màn hình
    final bool isLargeScreen = MediaQuery.of(context).size.width > 600;
    final double maxWidth = isLargeScreen ? 500 : double.infinity;
    final double fontSizeTitle = isLargeScreen ? 32 : 28;
    final double fontSizeButton = isLargeScreen ? 20 : 18;
    final double paddingValue = isLargeScreen ? 32.0 : 24.0;
    final double fieldHeight = isLargeScreen ? 60.0 : 56.0; // Chiều cao cố định cho các trường
    final double iconSize = isLargeScreen ? 28 : 24;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: EdgeInsets.symmetric(horizontal: paddingValue, vertical: 40.0),
            margin: isLargeScreen ? EdgeInsets.all(20.0) : null,
            decoration: isLargeScreen
                ? BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            )
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo hoặc tiêu đề
                Text(
                  'ĐĂNG NHẬP HỆ THỐNG',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.orange[400],
                    fontSize: fontSizeTitle,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isLargeScreen ? 60 : 40),

                // Thanh xổ xuống chọn vai trò
                SizedBox(
                  height: fieldHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800]!.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedRole,
                      hint: Text(
                        'Chọn vai trò',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: isLargeScreen ? 18 : 16,
                        ),
                      ),
                      items: _roles.map((String role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(
                            role,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: isLargeScreen ? 18 : 16,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedRole = newValue;
                          _emailController.clear();
                          _passwordController.clear();
                        });
                      },
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                        labelText: 'Vai trò',
                        labelStyle: GoogleFonts.poppins(
                          color: Colors.orange[400],
                          fontSize: isLargeScreen ? 18 : 16,
                        ),
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.person,
                          color: Colors.orange[400],
                          size: iconSize,
                        ),
                      ),
                      dropdownColor: Colors.grey[800],
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.orange[400],
                        size: iconSize,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isLargeScreen ? 30 : 20),

                // Trường nhập email (chỉ hiển thị khi là Quản lý)
                if (_selectedRole == "Quản lý")
                  SizedBox(
                    height: fieldHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800]!.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _emailController,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: isLargeScreen ? 18 : 16,
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 16,
                          ),
                          labelText: 'Email',
                          labelStyle: GoogleFonts.poppins(
                            color: Colors.orange[400],
                            fontSize: isLargeScreen ? 18 : 16,
                          ),
                          prefixIcon: Icon(
                            Icons.email,
                            color: Colors.orange[400],
                            size: iconSize,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ),
                if (_selectedRole == "Quản lý") SizedBox(height: isLargeScreen ? 30 : 20),

                // Trường nhập mật khẩu
                SizedBox(
                  height: fieldHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800]!.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: isLargeScreen ? 18 : 16,
                      ),
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                        labelText: (_selectedRole == "Nhân viên phục vụ" || _selectedRole == "Nhân viên bếp")
                            ? 'Secret Code'
                            : 'Mật khẩu',
                        labelStyle: GoogleFonts.poppins(
                          color: Colors.orange[400],
                          fontSize: isLargeScreen ? 18 : 16,
                        ),
                        prefixIcon: Icon(
                          Icons.lock,
                          color: Colors.orange[400],
                          size: iconSize,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            color: Colors.orange[400],
                            size: iconSize,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isLargeScreen ? 10 : 8),

                // Dòng Quên mật khẩu (chỉ hiển thị khi là Quản lý)
                if (_selectedRole == "Quản lý")
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _handleResetPassword,
                      child: Text(
                        'Quên mật khẩu?',
                        style: GoogleFonts.poppins(
                          color: Colors.orange[400],
                          fontSize: isLargeScreen ? 16 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: isLargeScreen ? 30 : 20),

                // Nút đăng nhập
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[400],
                    padding: EdgeInsets.symmetric(
                      vertical: isLargeScreen ? 20 : 16,
                      horizontal: isLargeScreen ? 120 : 100,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                  ).copyWith(
                    overlayColor: WidgetStateProperty.all(Colors.orange[600]),
                  ),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? SizedBox(
                    width: isLargeScreen ? 28 : 24,
                    height: isLargeScreen ? 28 : 24,
                    child: CircularProgressIndicator(
                      color: Colors.black87,
                      strokeWidth: 3,
                    ),
                  )
                      : Text(
                    'Đăng nhập',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: fontSizeButton,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}