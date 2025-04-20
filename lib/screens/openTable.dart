import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:midterm/screens/signInScreen.dart';
import 'package:shimmer/shimmer.dart';
import '../services/service.dart';
import 'buffetScreen.dart';
import 'management_screen.dart';

// Placeholder cho màn hình thống kê
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Thống Kê',
          style: GoogleFonts.poppins(
            color: Colors.orange[400],
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.grey[850],
        elevation: 0,
      ),
      body: Center(
        child: Text(
          'Màn hình thống kê (Chưa triển khai)',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

class TableSelectionScreen extends StatefulWidget {
  final String role;
  const TableSelectionScreen({Key? key, required this.role}) : super(key: key);

  @override
  _TableSelectionScreenState createState() => _TableSelectionScreenState();
}

class _TableSelectionScreenState extends State<TableSelectionScreen> {
  List<Map<String, dynamic>> tables = [];
  int? selectedTable;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadTableStatus();
  }

  Future<void> loadTableStatus() async {
    const String EXTERNAL_API_URL = 'https://soa-deploy.up.railway.app/menu/tables/status';
    try {
      final response = await http.get(
        Uri.parse(EXTERNAL_API_URL),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          tables = data
              .where((item) =>
          item['table_number'] is int && item['status'] is String)
              .map((item) => {
            'number': item['table_number'] as int,
            'status': item['status'] as String,
          })
              .toList();
          isLoading = false;
        });
      } else {
        setState(() => {
          errorMessage = 'Không thể tải trạng thái bàn: ${response.statusCode}',
          isLoading = false,
        });
      }
    } catch (e) {
      setState(() => {
        errorMessage = 'Lỗi kết nối: Vui lòng kiểm tra mạng',
        isLoading = false,
      });
    }
  }

  void selectTable(BuildContext context, int tableNumber) {
    final table = tables.firstWhere((t) => t['number'] == tableNumber);

    if (table['status'] == 'ready') {
      setState(() {
        selectedTable = tableNumber;
      });
      _showTableDialog(context, tableNumber);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bàn này đang ${table['status'] == 'eating' ? 'có người' : 'dọn dẹp'}, vui lòng chọn bàn khác',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _showTableDialog(BuildContext context, int tableNumber) async {
    TextEditingController peopleController = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.table_restaurant, color: Colors.orange[400], size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Mở Bàn $tableNumber',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: peopleController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(color: Colors.white),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                      _MaxPeopleFormatter(10),
                    ],
                    onChanged: (value) {
                      if (value.isNotEmpty && int.parse(value) > 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Số người tối đa là 10!')),
                        );
                        peopleController.text = '10';
                        peopleController.selection = TextSelection.fromPosition(
                          TextPosition(offset: peopleController.text.length),
                        );
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Số người (tối đa 10)',
                      labelStyle: GoogleFonts.poppins(color: Colors.orange[400]),
                      prefixIcon: Icon(Icons.people, color: Colors.orange[400]),
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
                  onPressed: isLoading
                      ? null
                      : () {
                    setState(() => selectedTable = null);
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Hủy',
                    style: GoogleFonts.poppins(color: Colors.red[600]),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[400],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 5,
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                    setState(() => isLoading = true);
                    if (peopleController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Vui lòng nhập số người',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.red[700],
                        ),
                      );
                      setState(() => isLoading = false);
                      return;
                    }
                    try {
                      int numberOfPeople = int.parse(peopleController.text);
                      Navigator.pop(context);
                      await Future.delayed(Duration(milliseconds: 100));
                      await _showCodeDialog(context, tableNumber, numberOfPeople);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Vui lòng nhập số hợp lệ',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.red[700],
                        ),
                      );
                    } finally {
                      setState(() => isLoading = false);
                    }
                  },
                  child: isLoading
                      ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.black87,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    'Xác nhận',
                    style: GoogleFonts.poppins(color: Colors.black87),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6), // Làm nền mờ đậm hơn
      builder: (BuildContext context) {
        return TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: AlertDialog(
            backgroundColor: Colors.grey[900]!.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.orange[400]!.withOpacity(0.3), width: 1),
            ),
            elevation: 10,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.logout,
                  color: Colors.orange[400],
                  size: 30,
                  shadows: [
                    Shadow(
                      color: Colors.orange[400]!.withOpacity(0.5),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                SizedBox(width: 12),
                Text(
                  'Xác nhận đăng xuất',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            content: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: EdgeInsets.only(bottom: 16, top: 8),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Đóng dialog
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red[600]!.withOpacity(0.5)),
                  ),
                ),
                child: Text(
                  'Hủy',
                  style: GoogleFonts.poppins(
                    color: Colors.red[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.orange[400]!.withOpacity(0.5),
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  foregroundColor: Colors.white,
                ).copyWith(
                  backgroundColor: MaterialStateProperty.all(Colors.transparent),
                  overlayColor: MaterialStateProperty.all(Colors.orange[700]!.withOpacity(0.2)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                        (route) => false,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange[400]!,
                        Colors.orange[600]!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Đồng ý',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCodeDialog(BuildContext context, int tableNumber, int numberOfCustomers) async {
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
                'Xác Nhận Mã Code',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nhập mã code',
                      labelStyle: GoogleFonts.poppins(color: Colors.orange[400]),
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
                  onPressed: isLoading
                      ? null
                      : () {
                    setState(() => selectedTable = null);
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Hủy',
                    style: GoogleFonts.poppins(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[400],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 5,
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                    setState(() => isLoading = true);
                    if (codeController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Vui lòng nhập mã code',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.red[700],
                        ),
                      );
                      setState(() => isLoading = false);
                      return;
                    }

                    final result = await ApiService.openTable(
                      tableNumber: tableNumber.toString(),
                      numberOfCustomers: numberOfCustomers,
                      secretCode: codeController.text,
                    );

                    setState(() => isLoading = false);
                    if (result['success']) {
                      await loadTableStatus();
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BuffetSelectionScreen(
                            tableNumber: tableNumber,
                            numberOfCustomers: numberOfCustomers,
                            sessionId: result['data']['session_id'],
                            role: widget.role,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result['message'],
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.red[700],
                        ),
                      );
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
                    style: GoogleFonts.poppins(color: Colors.black87),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 800 ? 4 : screenWidth > 600 ? 3 : 2;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('image/br4.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.3),
              BlendMode.darken,
            ),
          ),
        ),
        child: Column(
          children: [
            // Custom AppBar
            ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Container(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[850]!.withOpacity(0.9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.role == 'Quản lý')
                      IconButton(
                        icon: Icon(
                          Icons.bar_chart,
                          color: Colors.orange[400],
                          size: 28,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MyApp(),
                            ),
                          );
                        },
                        tooltip: 'Xem Thống Kê',
                      ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Chọn Bàn',
                          style: GoogleFonts.poppins(
                            color: Colors.orange[400],
                            fontSize: screenWidth > 800 ? 30 : 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.logout,
                        color: Colors.orange[400],
                        size: 28,
                      ),
                      onPressed: () {
                        _showLogoutDialog(context);
                      },
                      tooltip: 'Đăng xuất',
                    ),
                  ],
                ),
              ),
            ),
            // Main content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(screenWidth > 800 ? 48.0 : 24.0),
                child: isLoading
                    ? Shimmer.fromColors(
                  baseColor: Colors.grey[700]!,
                  highlightColor: Colors.grey[600]!,
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 20.0,
                      crossAxisSpacing: 20.0,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: 8,
                    itemBuilder: (context, index) => Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
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
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: loadTableStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[400],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 6,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          'Thử lại',
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16),
                    Text(
                      'Chọn bàn trống',
                      style: GoogleFonts.poppins(
                        color: Colors.orange[400],
                        fontSize: screenWidth > 800 ? 30 : 26,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 20.0,
                          crossAxisSpacing: 20.0,
                          childAspectRatio: 1.3,
                        ),
                        itemCount: tables.length,
                        itemBuilder: (context, index) {
                          final table = tables[index];
                          final isOccupied = table['status'] == 'eating';
                          final isSelected = selectedTable == table['number'];

                          return GestureDetector(
                            onTap: () => selectTable(context, table['number']),
                            child: Card(
                              elevation: isSelected ? 10 : 6,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                    colors: [
                                      Colors.orange[400]!.withOpacity(0.5),
                                      Colors.orange[600]!.withOpacity(0.3),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                      : isOccupied
                                      ? LinearGradient(
                                    colors: [
                                      Colors.red[400]!,
                                      Colors.red[600]!,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                      : null,
                                  color: isSelected || isOccupied ? null : Colors.grey[850],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? Colors.orange[400]! : Colors.transparent,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.cyan.withOpacity(0.4),
                                      spreadRadius: 3,
                                      blurRadius: 10,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isOccupied ? Icons.lock : Icons.table_restaurant,
                                      color: isOccupied ? Colors.white : Colors.orange[400],
                                      size: screenWidth > 800 ? 36 : 32,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Bàn ${table['number']}',
                                      style: GoogleFonts.poppins(
                                        fontSize: screenWidth > 800 ? 22 : 20,
                                        fontWeight: FontWeight.w700,
                                        color: isOccupied || isSelected ? Colors.white : Colors.orange[400],
                                        shadows: [
                                          Shadow(
                                            color: Colors.black45,
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      table['status'],
                                      style: GoogleFonts.poppins(
                                        fontSize: screenWidth > 800 ? 16 : 14,
                                        fontWeight: FontWeight.w500,
                                        color: isOccupied ? Colors.white : Colors.orange[400],
                                        shadows: [
                                          Shadow(
                                            color: Colors.black45,
                                            blurRadius: 2,
                                            offset: Offset(0, 1),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaxPeopleFormatter extends TextInputFormatter {
  final int maxPeople;

  _MaxPeopleFormatter(this.maxPeople);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    try {
      final int? value = int.parse(newValue.text);
      if ((value != null && value > maxPeople) || value! <= 0) {
        return oldValue;
      }
    } catch (e) {
      return oldValue;
    }

    return newValue;
  }
}