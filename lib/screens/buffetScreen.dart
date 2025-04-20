import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/service.dart';
import 'menuScreen.dart';
import 'openTable.dart';
import 'package:intl/intl.dart';

class BuffetSelectionScreen extends StatefulWidget {
  final int tableNumber;
  final int numberOfCustomers;
  final int sessionId;
  final String role;

  BuffetSelectionScreen({
    required this.tableNumber,
    required this.numberOfCustomers,
    required this.sessionId,
    required this.role,
  });

  @override
  _BuffetSelectionScreenState createState() => _BuffetSelectionScreenState();
}

class _BuffetSelectionScreenState extends State<BuffetSelectionScreen> {
  List<Map<String, dynamic>> buffetTypes = [];
  bool isLoading = true;
  String? errorMessage;
  Map<int, bool> _itemLoadingStates = {}; // Theo dõi trạng thái loading cho từng mục

  @override
  void initState() {
    super.initState();
    fetchBuffetMenu();
  }

  Future<void> fetchBuffetMenu() async {
    try {
      final buffetData = await ApiService.fetchBuffetMenu();
      setState(() {
        buffetTypes = buffetData;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> closeTable(BuildContext context) async {
    TextEditingController codeController = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false, // Ngăn đóng dialog khi nhấn ngoài
      builder: (BuildContext context) {
        bool isLoading = false; // Trạng thái loading

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
                      ? null // Vô hiệu hóa khi đang loading
                      : () async {
                    if (codeController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Vui lòng nhập mã code'), backgroundColor: Colors.red[700]),
                      );
                      return;
                    }

                    setState(() {
                      isLoading = true; // Bắt đầu loading
                    });

                    try {
                      final success = await ApiService.closeTable(widget.tableNumber, codeController.text);
                      if (success) {
                        Navigator.pop(context); // Đóng dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã đóng bàn thành công'), backgroundColor: Colors.green[700]),
                        );
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TableSelectionScreen(role: widget.role),
                          ),
                              (route) => false, // Xóa toàn bộ stack
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red[700]),
                      );
                    } finally {
                      setState(() {
                        isLoading = false; // Kết thúc loading
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

  // Hàm format giá an toàn
  String formatPrice(dynamic price) {
    try {
      // Xử lý các trường hợp giá có thể là String, int, hoặc double
      int priceInt;
      if (price is String) {
        priceInt = int.parse(price.replaceAll(RegExp(r'[^\d]'), '')); // Loại bỏ ký tự không phải số
      } else if (price is int) {
        priceInt = price;
      } else if (price is double) {
        priceInt = price.toInt();
      } else {
        return 'N/A';
      }
      return NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(priceInt);
    } catch (e) {
      return 'N/A'; // Giá trị mặc định nếu lỗi
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLargeScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Row(
        children: [
          if (isLargeScreen)
            NavigationRail(
              backgroundColor: Colors.grey[900],
              extended: true,
              selectedIndex: 0,
              onDestinationSelected: (int index) {},
              labelType: NavigationRailLabelType.none,
              selectedLabelTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[400]),
              unselectedLabelTextStyle: TextStyle(fontSize: 16, color: Colors.white70),
              leading: Column(
                children: [
                  SizedBox(height: 20),
                  Text(
                    'MENU BUFFET',
                    style: TextStyle(
                      color: Colors.orange[400],
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
              destinations: [
                NavigationRailDestination(
                  icon: Icon(Icons.fastfood, color: Colors.orange[400]),
                  label: Text('Chọn Buffet'),
                ),
              ],
            ),
          Expanded(
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.grey[850],
                  centerTitle: true,
                  title: Text(
                    'CHỌN LOẠI BUFFET - Bàn ${widget.tableNumber}',
                    style: TextStyle(
                      color: Colors.orange[400],
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  elevation: 0,
                  actions: [
                    IconButton(
                      icon: Icon(Icons.exit_to_app, color: Colors.orange[400], size: 28),
                      onPressed: () => closeTable(context), // Gọi hàm closeTable
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: isLoading
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
                              fetchBuffetMenu();
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
                        : GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isLargeScreen ? 3 : 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      itemCount: buffetTypes.length,
                      itemBuilder: (context, index) {
                        bool isItemLoading = _itemLoadingStates[index] ?? false;
                        return GestureDetector(
                          onTap: isItemLoading
                              ? null // Vô hiệu hóa khi đang loading
                              : () async {
                            setState(() {
                              _itemLoadingStates[index] = true; // Bắt đầu loading cho mục này
                            });
                            try {
                              bool success = await ApiService.updatePackage(
                                widget.tableNumber.toString(),
                                buffetTypes[index]['package_id'],
                              );
                              if (success) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MenuScreen(
                                      packageId: buffetTypes[index]['package_id'],
                                      tableNumber: widget.tableNumber,
                                      numberOfCustomers: widget.numberOfCustomers,
                                      buffetPrice: buffetTypes[index]['price_per_person'],
                                      sessionId: widget.sessionId,
                                      role: widget.role, // Truyền role vào MenuScreen
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Cập nhật gói thất bại'),
                                    backgroundColor: Colors.red[700],
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: Colors.red[700],
                                ),
                              );
                            } finally {
                              setState(() {
                                _itemLoadingStates[index] = false; // Kết thúc loading
                              });
                            }
                          },
                          child: Stack(
                            children: [
                              AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: [Colors.grey[850]!, Colors.grey[800]!],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black54,
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                        child: buffetTypes[index]['img'] != null
                                            ? Image.asset(
                                          buffetTypes[index]['img']!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
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
                                        children: [
                                          Text(
                                            buffetTypes[index]['name']!,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                              color: Colors.white,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            '${formatPrice(buffetTypes[index]['price_per_person'])} / người',
                                            style: TextStyle(
                                              color: Colors.orange[400],
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Roboto',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Hiển thị loading overlay khi isItemLoading là true
                              if (isItemLoading)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.orange[400],
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}