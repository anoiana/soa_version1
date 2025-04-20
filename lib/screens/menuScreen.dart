import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/service.dart';
import 'openTable.dart';

class MenuScreen extends StatefulWidget {
  final int packageId;
  final int tableNumber;
  final int numberOfCustomers;
  final String buffetPrice;
  final int sessionId;
  final String role;

  MenuScreen({
    required this.packageId,
    required this.tableNumber,
    required this.numberOfCustomers,
    required this.buffetPrice,
    required this.sessionId,
    required this.role,
  });

  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<Map<String, dynamic>> menuItems = [];
  List<Map<String, dynamic>> cart = [];
  bool isLoading = true;
  bool isConfirmLoading = false;
  String? errorMessage;
  int selectedCategoryIndex = 0;
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    fetchMenuItems();
    _initWebSocket();
  }

  void _initWebSocket() {
    print('Khởi tạo kết nối WebSocket...');
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://web-socket-soa-midterm.onrender.com/ws/menu'),
      );

      print('Kết nối WebSocket thành công.');

      _channel!.stream.listen(
            (message) {
          print('Nhận thông điệp WebSocket: $message');
          try {
            final data = jsonDecode(message);
            if (data['menu_update'] != null) {
              final menuUpdate = data['menu_update'];
              print('Nhận cập nhật menu: $menuUpdate');
              fetchMenuItems().then((_) {
                print('Đã tải lại danh sách món ăn sau cập nhật WebSocket.');
                _validateCart();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Món ${menuUpdate['name']} đã ${menuUpdate['available'] ? 'còn hàng' : 'hết hàng'}.',
                    ),
                    backgroundColor: menuUpdate['available'] ? Colors.green[700] : Colors.red[700],
                  ),
                );
              });
            } else {
              print('Thông điệp không chứa menu_update, bỏ qua.');
            }
          } catch (e) {
            print('Lỗi khi xử lý thông điệp WebSocket: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi xử lý thông điệp từ server'), backgroundColor: Colors.red[700]),
            );
          }
        },
        onError: (error) {
          print('Lỗi WebSocket: $error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi kết nối WebSocket'), backgroundColor: Colors.red[700]),
          );
          _reconnectWebSocket();
        },
        onDone: () {
          print('Kết nối WebSocket đã đóng.');
          _reconnectWebSocket();
        },
      );
    } catch (e) {
      print('Lỗi khi khởi tạo WebSocket: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể kết nối WebSocket'), backgroundColor: Colors.red[700]),
      );
      _reconnectWebSocket();
    }
  }

  void _reconnectWebSocket() {
    Future.delayed(Duration(seconds: 5), () {
      if (mounted) {
        print('Thử kết nối lại WebSocket...');
        _initWebSocket();
      }
    });
  }

  Future<void> fetchMenuItems() async {
    try {
      final items = await ApiService.fetchMenuItems(widget.packageId);
      final validatedItems = items.where((item) {
        final itemId = item['item_id'];
        if (itemId == null || itemId is! int) {
          print('Món không hợp lệ, bỏ qua: $item');
          return false;
        }
        return true;
      }).toList();

      setState(() {
        menuItems = validatedItems;
        if (isLoading) isLoading = false;
      });
      print('Đã tải danh sách món ăn: ${menuItems.length} món.');
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        if (isLoading) isLoading = false;
      });
      print('Lỗi khi tải danh sách món ăn: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải danh sách món ăn'), backgroundColor: Colors.red[700]),
      );
    }
  }

  void _validateCart() {
    List<Map<String, dynamic>> updatedCart = [];
    for (var cartItem in cart) {
      final itemId = cartItem['item_id'];
      if (itemId == null || itemId is! int) {
        print('Món trong giỏ không hợp lệ, xóa: $cartItem');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Món ${cartItem['name']} không hợp lệ và đã bị xóa.'),
            backgroundColor: Colors.red[700],
          ),
        );
        continue;
      }
      final menuItem = menuItems.firstWhere(
            (item) => item['item_id'] == itemId,
        orElse: () => {},
      );
      if (menuItem.isNotEmpty && menuItem['available'] == true) {
        updatedCart.add(cartItem);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Món ${cartItem['name']} đã hết hàng hoặc không còn trong menu.'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
    if (updatedCart.length != cart.length) {
      setState(() {
        cart = updatedCart;
      });
      print('Giỏ hàng đã được cập nhật: ${cart.length} món.');
    }
  }

  void _showSecretCodeDialog(BuildContext context) {
    TextEditingController codeController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text(
                'Nhập mã code - Bàn ${widget.tableNumber}',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: TextField(
                controller: codeController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nhập mã code',
                  labelStyle: TextStyle(color: Colors.orange[400]),
                  prefixIcon: Icon(Icons.vpn_key, color: Colors.orange[400]),
                  filled: true,
                  fillColor: Colors.grey[800]!.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: Text('Hủy', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[400],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                    if (codeController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Vui lòng nhập mã bí mật'), backgroundColor: Colors.red[700]),
                      );
                      return;
                    }

                    setState(() {
                      isLoading = true;
                    });

                    try {
                      final success = await ApiService.closeTable(widget.tableNumber, codeController.text);
                      if (success) {
                        Navigator.pop(context); // Đóng dialog nhập mã
                        _showPaymentDialog(context); // Hiển thị dialog thanh toán
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red[700]),
                      );
                    } finally {
                      setState(() {
                        isLoading = false;
                      });
                    }
                  },
                  child: isLoading
                      ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.orange[400],
                      strokeWidth: 3,
                    ),
                  )
                      : Text(
                    'Xác nhận',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPaymentDialog(BuildContext context) {
    double totalAmount = widget.numberOfCustomers * double.parse(widget.buffetPrice);
    final NumberFormat numberFormat = NumberFormat.decimalPattern('vi_VN');
    String formattedBuffetPrice = numberFormat.format(double.parse(widget.buffetPrice));
    String formattedTotalAmount = numberFormat.format(totalAmount);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool isLoading = false;
        String? selectedPaymentMethod = 'Tiền mặt';
        final List<String> paymentMethods = ['Tiền mặt', 'Chuyển khoản'];

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.orange[400]!.withOpacity(0.3), width: 1),
              ),
              elevation: 10,
              contentPadding: EdgeInsets.all(20),
              title: Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.orange[400], size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Thanh Toán - Bàn ${widget.tableNumber}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xác nhận thanh toán cho bàn của bạn',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildInfoRow(
                    icon: Icons.group,
                    label: 'Số người',
                    value: '${widget.numberOfCustomers}',
                  ),
                  SizedBox(height: 15),
                  _buildInfoRow(
                    icon: Icons.attach_money,
                    label: 'Giá buffet',
                    value: '$formattedBuffetPrice VNĐ/người',
                  ),
                  SizedBox(height: 15),
                  Divider(color: Colors.grey[700], thickness: 1),
                  SizedBox(height: 15),
                  _buildInfoRow(
                    icon: Icons.account_balance_wallet,
                    label: 'Tổng tiền',
                    value: '$formattedTotalAmount VNĐ',
                    isTotal: true,
                  ),
                  SizedBox(height: 20),
                  // Phần chọn phương thức thanh toán được cải thiện
                  AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800]!.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange[400]!.withOpacity(0.5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payment, color: Colors.orange[400], size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Phương thức thanh toán',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedPaymentMethod,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            filled: true,
                            fillColor: Colors.grey[850],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.orange[400]!.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.orange[400]!, width: 2),
                            ),
                          ),
                          dropdownColor: Colors.grey[850],
                          icon: Icon(Icons.arrow_drop_down, color: Colors.orange[400]),
                          style: TextStyle(color: Colors.white, fontSize: 16),
                          items: paymentMethods.map((String method) {
                            return DropdownMenuItem<String>(
                              value: method,
                              child: Row(
                                children: [
                                  Icon(
                                    method == 'Tiền mặt' ? Icons.money : Icons.qr_code,
                                    color: Colors.orange[400],
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(_formatPaymentMethod(method)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: isLoading
                              ? null
                              : (String? newValue) {
                            setState(() {
                              selectedPaymentMethod = newValue;
                              if (newValue == 'Chuyển khoản') {
                                _showQrCodeDialog(context);
                              }
                            });
                          },
                        ),
                        SizedBox(height: 8),
                        Text(
                          selectedPaymentMethod == 'Tiền mặt'
                              ? 'Vui lòng chuẩn bị tiền mặt để thanh toán.'
                              : 'Quét mã QR để chuyển khoản qua Momo, VietQR hoặc ví điện tử.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: Text(
                    'Hủy',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[400],
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                    shadowColor: Colors.orange[400]!.withOpacity(0.5),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                    setState(() {
                      isLoading = true;
                    });

                    try {
                      await makePayment(totalAmount, selectedPaymentMethod!);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Thanh toán thành công!'),
                          backgroundColor: Colors.green[700],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TableSelectionScreen(role: widget.role),
                        ),
                            (route) => false,
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: Colors.red[700],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    } finally {
                      setState(() {
                        isLoading = false;
                      });
                    }
                  },
                  child: isLoading
                      ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                      : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.black87, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Xác nhận',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showQrCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.orange[400]!.withOpacity(0.3), width: 1),
          ),
          elevation: 10,
          contentPadding: EdgeInsets.all(20),
          title: Row(
            children: [
              Icon(Icons.qr_code, color: Colors.orange[400], size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Quét QR để thanh toán',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Image.asset(
                  'image/qr.jpg',
                  width: 350,
                  height: 350,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 15),
              Text(
                'Nhắn tiền từ Momo, VietQR, hoặc Ví điện tử',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Đóng',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatPaymentMethod(String method) {
    switch (method) {
      case 'Tiền mặt':
        return 'Tiền mặt';
      case 'Chuyển khoản':
        return 'Chuyển khoản';
      default:
        return method;
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isTotal = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange[400], size: 24),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? Colors.orange[400] : Colors.white,
            fontSize: 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Future<void> makePayment(double amount, String paymentMethod) async {
    const String apiUrl = 'https://soa-deploy.up.railway.app/payment/';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'session_id': widget.sessionId,
          'amount': amount,
          'payment_method': paymentMethod,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Lỗi khi thanh toán');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  Future<void> closeTable(BuildContext context) async {
    TextEditingController codeController = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text(
                'Đóng Bàn ${widget.tableNumber}',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nhập mã code',
                      labelStyle: TextStyle(color: Colors.orange[400]),
                      prefixIcon: Icon(Icons.vpn_key, color: Colors.orange[400]),
                      filled: true,
                      fillColor: Colors.grey[800]!.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: Text('Hủy', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[400],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                    if (codeController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Vui lòng nhập mã code'), backgroundColor: Colors.red[700]),
                      );
                      return;
                    }

                    setState(() {
                      isLoading = true;
                    });

                    try {
                      final success = await ApiService.closeTable(widget.tableNumber, codeController.text);
                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã đóng bàn thành công'), backgroundColor: Colors.green[700]),
                        );
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TableSelectionScreen(role: widget.role),
                          ),
                              (route) => false,
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red[700]),
                      );
                    } finally {
                      setState(() {
                        isLoading = false;
                      });
                    }
                  },
                  child: isLoading
                      ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.orange[400],
                      strokeWidth: 3,
                    ),
                  )
                      : Text(
                    'Xác nhận',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<String> getUniqueCategories() {
    final categories = menuItems.map((item) => item['category'] as String).toSet().toList();
    print('Danh mục: $categories');
    return categories;
  }

  Future<void> confirmOrder(BuildContext context) async {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Giỏ hàng trống!'), backgroundColor: Colors.red[700]),
      );
      return;
    }
    setState(() {
      isConfirmLoading = true;
    });

    try {
      final success = await ApiService.confirmOrder(widget.tableNumber, cart);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xác nhận đơn hàng thành công'), backgroundColor: Colors.green[700]),
        );
        setState(() {
          cart.clear();
        });
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red[700]),
      );
    } finally {
      setState(() {
        isConfirmLoading = false;
      });
    }
  }

  @override
  void dispose() {
    print('Đóng kết nối WebSocket.');
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isLargeScreen = MediaQuery.of(context).size.width > 800;
    List<String> categories = getUniqueCategories();

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          'CHỌN MÓN - Bàn ${widget.tableNumber}',
          style: TextStyle(
            color: Colors.orange[400],
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: Stack(
                children: [
                  Icon(Icons.shopping_cart, color: Colors.orange[400], size: 32),
                  if (cart.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red[700],
                        child: Text(
                          '${cart.fold(0, (sum, item) => sum + (item['quantity'] as int? ?? 0))}',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                try {
                  Scaffold.of(context).openEndDrawer();
                } catch (e) {
                  print('Lỗi khi mở endDrawer: $e');
                }
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.exit_to_app, color: Colors.orange[400], size: 32),
            onPressed: () => _showSecretCodeDialog(context),
          ),
        ],
      ),
      endDrawer: Drawer(
        width: isLargeScreen ? MediaQuery.of(context).size.width * 0.4 : MediaQuery.of(context).size.width * 0.85,
        backgroundColor: Colors.grey[850],
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey[850]!, Colors.grey[800]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      'Danh Sách Món Đã Chọn',
                      style: TextStyle(
                        color: Colors.orange[400],
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: cart.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.remove_shopping_cart, size: 80, color: Colors.grey[600]),
                    SizedBox(height: 20),
                    Text(
                      'Giỏ hàng trống!',
                      style: TextStyle(fontSize: 20, color: Colors.grey[400], fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: cart.length,
                itemBuilder: (context, index) {
                  final item = cart[index];
                  int quantity = item['quantity'] ?? 1;

                  return Dismissible(
                    key: Key(item['item_id'].toString()),
                    background: Container(
                      color: Colors.red[700],
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) {
                      setState(() => cart.removeAt(index));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã xóa món ${item['name']}')),
                      );
                    },
                    child: Card(
                      elevation: 4,
                      color: Colors.grey[800],
                      margin: EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: item['img'] != null
                                  ? Image.asset(
                                item['img']!,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.broken_image,
                                  size: 70,
                                  color: Colors.grey[600],
                                ),
                              )
                                  : Icon(
                                Icons.fastfood,
                                size: 70,
                                color: Colors.orange[400],
                              ),
                            ),
                            SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.remove_circle, color: Colors.red[700], size: 28),
                                        onPressed: () {
                                          setState(() {
                                            if (quantity > 1) {
                                              cart[index]['quantity'] = quantity - 1;
                                            } else {
                                              cart.removeAt(index);
                                            }
                                          });
                                        },
                                      ),
                                      Text(
                                        '$quantity',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.add_circle, color: Colors.green[700], size: 28),
                                        onPressed: () {
                                          if (quantity < 5) {
                                            setState(() {
                                              cart[index]['quantity'] = quantity + 1;
                                            });
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Số lượng tối đa mỗi lần gọi cho món ${item['name']} là 5!'),
                                                backgroundColor: Colors.red[700],
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[400],
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  minimumSize: Size(double.infinity, 60),
                ),
                onPressed: cart.isEmpty || isConfirmLoading ? null : () => confirmOrder(context),
                child: isConfirmLoading
                    ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.orange[400],
                    strokeWidth: 3,
                  ),
                )
                    : Text(
                  'Xác Nhận (${cart.fold(0, (sum, item) => sum + (item['quantity'] as int? ?? 0))})',
                  style: TextStyle(fontSize: 20, color: Colors.black87, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[400]!),
        ),
      )
          : errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 60),
            SizedBox(height: 20),
            Text(
              errorMessage!,
              style: TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                fetchMenuItems();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[400],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Thử lại',
                style: TextStyle(color: Colors.black87, fontSize: 16),
              ),
            ),
          ],
        ),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            child: Wrap(
              spacing: MediaQuery.of(context).size.width < 600 ? 4 : 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(categories.length, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    label: Text(
                      categories[index],
                      style: const TextStyle(fontSize: 16),
                    ),
                    selected: selectedCategoryIndex == index,
                    onSelected: (selected) {
                      if (selected) setState(() => selectedCategoryIndex = index);
                    },
                    selectedColor: Colors.orange[400],
                    backgroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    labelStyle: TextStyle(
                      color: selectedCategoryIndex == index ? Colors.black87 : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                key: ValueKey(selectedCategoryIndex),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isLargeScreen ? 4 : 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: menuItems.where((item) => item['category'] == categories[selectedCategoryIndex]).length,
                itemBuilder: (context, index) {
                  final filteredItems =
                  menuItems.where((item) => item['category'] == categories[selectedCategoryIndex]).toList();
                  final item = filteredItems[index];

                  return GestureDetector(
                    onTap: item['available']
                        ? () {
                      setState(() {
                        int existingIndex = cart.indexWhere((cartItem) => cartItem['item_id'] == item['item_id']);
                        if (existingIndex != -1) {
                          int currentQuantity = cart[existingIndex]['quantity'] as int;
                          if (currentQuantity < 5) {
                            cart[existingIndex]['quantity'] = currentQuantity + 1;
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Số lượng tối đa cho món ${item['name']} là 5!'),
                                backgroundColor: Colors.red[700],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                            return;
                          }
                        } else {
                          cart.add({
                            'item_id': item['item_id'],
                            'quantity': 1,
                            'name': item['name'],
                            'img': item['img'],
                          });
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Đã thêm ${item['name']} vào giỏ hàng'),
                          backgroundColor: Colors.green[700],
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                        : null,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: item['available'] ? Colors.grey[800] : Colors.grey[600],
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              child: item['img'] != null
                                  ? Image.asset(
                                item['img']!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.broken_image,
                                  size: 60,
                                  color: Colors.grey[600],
                                ),
                              )
                                  : Container(
                                color: Colors.grey[700],
                                child: Center(
                                  child: Icon(
                                    Icons.fastfood,
                                    size: 60,
                                    color: Colors.orange[400],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name']!,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: item['available'] ? Colors.white : Colors.grey[400],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 8),
                                if (!item['available'])
                                  Text(
                                    'Hết hàng',
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if (item['available'])
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange[400],
                                        shape: CircleBorder(),
                                        padding: EdgeInsets.all(10),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          int existingIndex =
                                          cart.indexWhere((cartItem) => cartItem['item_id'] == item['item_id']);
                                          if (existingIndex != -1) {
                                            int currentQuantity = cart[existingIndex]['quantity'] as int;
                                            if (currentQuantity < 5) {
                                              cart[existingIndex]['quantity'] = currentQuantity + 1;
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Số lượng tối đa cho món ${item['name']} là 5!'),
                                                  backgroundColor: Colors.red[700],
                                                  behavior: SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                              );
                                              return;
                                            }
                                          } else {
                                            cart.add({
                                              'item_id': item['item_id'],
                                              'quantity': 1,
                                              'name': item['name'],
                                              'img': item['img'],
                                            });
                                          }
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('✅ Đã thêm ${item['name']} vào giỏ hàng'),
                                            backgroundColor: Colors.green[700],
                                            behavior: SnackBarBehavior.floating,
                                            duration: Duration(seconds: 2),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        );
                                      },
                                      child: Icon(Icons.add, color: Colors.black87, size: 24),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            color: Colors.grey[850],
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end, // Chỉ giữ nút Xem Giỏ
              children: [
                Builder(
                  builder: (context) {
                    return ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[400],
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: cart.isEmpty ? null : () => Scaffold.of(context).openEndDrawer(),
                      icon: Icon(Icons.shopping_cart, color: Colors.black87, size: 24),
                      label: Text(
                        'Xem Giỏ (${cart.fold(0, (sum, item) => sum + (item['quantity'] as int? ?? 0))})',
                        style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}