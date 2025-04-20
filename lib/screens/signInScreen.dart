import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:midterm/main.dart';
import 'openTable.dart';
typedef OrderUpdateCallback = void Function(Map<int, int> pendingOrderCountsByTable);
typedef TableClearedCallback = void Function(int tableNumber);
typedef ThemeChangeCallback = void Function(ThemeMode themeMode);


class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();

}

class _LoginScreenState extends State<LoginScreen> {

  // Controllers for password and email
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // List of roles
  final List<String> _roles = ['Nhân viên phục vụ', 'Nhân viên bếp', 'Quản lý'];
  String? _selectedRole;

  // Password visibility state
  bool _obscurePassword = true;

  // Loading states
  bool _isLoading = false;
  bool _isResetLoading = false;


  // Handle login
  Future<void> _handleLogin() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vui lòng nhập ${(_selectedRole == "Nhân viên phục vụ" || _selectedRole == "Nhân viên bếp") ? "secret code" : "mật khẩu"}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    if (_selectedRole == "Quản lý" && _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng nhập email', style: GoogleFonts.poppins()),
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
        final response = await http.post(
          Uri.parse('https://soa-deploy.up.railway.app/user/employee/login?secret_code=${_passwordController.text}'),
          headers: {'Content-Type': 'application/json'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] ?? 'Đăng nhập thành công với vai trò $_selectedRole',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
              ),
              backgroundColor: Colors.green[700],
            ),
          );

          if (_selectedRole == "Nhân viên bếp") {

            if (!mounted) return; // Kiểm tra context
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MenuScreen(),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TableSelectionScreen(role: _selectedRole!),
              ),
            );
          }
        } else {
          final errorData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['error'] ?? 'Đăng nhập thất bại: Secret code không hợp lệ',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      } else {
        final response = await http.post(
          Uri.parse('https://soa-deploy.up.railway.app/user/admin/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': _emailController.text,
            'password': _passwordController.text,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] ?? 'Đăng nhập thành công với vai trò Quản lý',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
              ),
              backgroundColor: Colors.green[700],
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TableSelectionScreen(role: _selectedRole!),
            ),
          );
        } else {
          final errorData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['error'] ?? 'Đăng nhập thất bại: Thông tin không hợp lệ',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Handle reset password
  Future<void> _handleResetPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng nhập email để đặt lại mật khẩu', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    setState(() {
      _isResetLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://soa-deploy.up.railway.app/user/send-password-reset?email=${Uri.encodeComponent(_emailController.text)}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ?? 'Yêu cầu đặt lại mật khẩu đã được gửi. Vui lòng kiểm tra email.',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            ),
            backgroundColor: Colors.green[700],
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorData['error'] ?? 'Không thể gửi yêu cầu đặt lại mật khẩu',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      setState(() {
        _isResetLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check screen size
    final bool isLargeScreen = MediaQuery.of(context).size.width > 600;
    final double maxWidth = isLargeScreen ? 500 : double.infinity;
    final double fontSizeTitle = isLargeScreen ? 32 : 28;
    final double fontSizeButton = isLargeScreen ? 20 : 18;
    final double paddingValue = isLargeScreen ? 32.0 : 24.0;
    final double fieldHeight = isLargeScreen ? 60.0 : 56.0;
    final double iconSize = isLargeScreen ? 28 : 24;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('image/br4.jpg'),
            fit: BoxFit.cover,
            // colorFilter: ColorFilter.mode(
            //   Colors.black.withOpacity(0.5), // Dark overlay for text readability
            //   BlendMode.darken,
            // ),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: EdgeInsets.symmetric(horizontal: paddingValue, vertical: 40.0),
              margin: isLargeScreen ? EdgeInsets.all(20.0) : EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey[850]!.withOpacity(0.85), // Slightly transparent for contrast
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  Text(
                    'ĐĂNG NHẬP HỆ THỐNG',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.orange[400],
                      fontSize: fontSizeTitle,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 48 : 40),

                  // Role dropdown
                  SizedBox(
                    height: fieldHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800]!.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
                  SizedBox(height: isLargeScreen ? 24 : 20),

                  // Email field (only for Quản lý)
                  if (_selectedRole == "Quản lý")
                    SizedBox(
                      height: fieldHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[800]!.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _emailController,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: isLargeScreen ? 18 : 16,
                          ),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
                            border: InputBorder.none,
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                    ),
                  if (_selectedRole == "Quản lý") SizedBox(height: isLargeScreen ? 24 : 20),

                  // Password field
                  SizedBox(
                    height: fieldHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800]!.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: isLargeScreen ? 18 : 16,
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 12 : 8),

                  // Forgot password (only for Quản lý)
                  if (_selectedRole == "Quản lý")
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isResetLoading ? null : _handleResetPassword,
                        child: _isResetLoading
                            ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.orange[400],
                            strokeWidth: 2,
                          ),
                        )
                            : Text(
                          'Quên mật khẩu?',
                          style: GoogleFonts.poppins(
                            color: Colors.orange[400],
                            fontSize: isLargeScreen ? 16 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: isLargeScreen ? 24 : 20),

                  // Login button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[400],
                      padding: EdgeInsets.symmetric(
                        vertical: isLargeScreen ? 18 : 16,
                        horizontal: isLargeScreen ? 100 : 80,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 6,
                      shadowColor: Colors.black45,
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