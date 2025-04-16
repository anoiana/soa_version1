import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../services/service.dart';
import 'buffetScreen.dart';

class TableSelectionScreen extends StatefulWidget {
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
          tables = data.map((item) => {
            'number': item['table_number'] as int,
            'status': item['status'] as String,
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Không thể tải trạng thái bàn: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Lỗi kết nối: $e';
        isLoading = false;
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
        bool isLoading = false; // Track loading state

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
                        peopleController.text = '10'; // Đặt lại giá trị nếu vượt quá
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
                      fillColor: Colors.grey[800]!.withAlpha(76),
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
                    setState(() => isLoading = true); // Bắt đầu loading
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
                      // Đảm bảo dialog đóng trước khi mở dialog mới
                      Navigator.pop(context);
                      // Chờ một chút để đảm bảo dialog hiện tại đóng hoàn toàn
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
                      setState(() => isLoading = false); // Kết thúc loading
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

  Future<void> _showCodeDialog(BuildContext context, int tableNumber, int numberOfCustomers) async {
    TextEditingController codeController = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool isLoading = false; // Track loading state

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
                          builder: (context) => BuffetSelectionScreen(tableNumber: tableNumber),
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
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Chọn Bàn',
          style: GoogleFonts.poppins(
            color: Colors.orange[400],
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(screenWidth > 800 ? 40.0 : 16.0),
        child: isLoading
            ? Shimmer.fromColors(
          baseColor: Colors.grey[700]!,
          highlightColor: Colors.grey[600]!,
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16.0,
              crossAxisSpacing: 16.0,
              childAspectRatio: 1.3,
            ),
            itemCount: 8,
            itemBuilder: (context, index) => Container(
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
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
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: loadTableStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[400],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'Thử lại',
                  style: GoogleFonts.poppins(color: Colors.black87),
                ),
              ),
            ],
          ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendChip('Ready', Colors.orange[400]!),
                _buildLegendChip('Eating', Colors.red[700]!),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Chọn bàn trống',
              style: GoogleFonts.poppins(
                color: Colors.orange[400],
                fontSize: screenWidth > 800 ? 28 : 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 16.0,
                  crossAxisSpacing: 16.0,
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
                      elevation: isSelected ? 8 : 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isOccupied
                              ? Colors.red[400]
                              : isSelected
                              ? Colors.orange[400]!.withOpacity(0.3)
                              : Colors.grey[850],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.orange[400]! : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isOccupied
                                  ? Icons.lock
                                  : Icons.table_restaurant,
                              color: isOccupied
                                  ? Colors.white
                                  : Colors.orange[400],
                              size: 30,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Bàn ${table['number']}',
                              style: GoogleFonts.poppins(
                                fontSize: screenWidth > 800 ? 20 : 18,
                                fontWeight: FontWeight.w600,
                                color: isOccupied || isSelected
                                    ? Colors.white
                                    : Colors.orange[400],
                              ),
                            ),
                            Text(
                              table['status'],
                              style: GoogleFonts.poppins(
                                fontSize: screenWidth > 800 ? 16 : 14,
                                color: isOccupied
                                    ? Colors.white
                                    : Colors.orange[400],
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
    );
  }

  Widget _buildLegendChip(String label, Color color) {
    return Chip(
      label: Text(
        label,
        style: GoogleFonts.abel(
          color: Colors.white,
          fontSize: 17, // Đảm bảo kích thước chữ phù hợp
        ),
      ),
      backgroundColor: color.withOpacity(0.9),
      side: BorderSide(color: color),
      labelPadding: EdgeInsets.symmetric(horizontal: 18.0), // Thêm padding cho chữ
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16.0), // Padding tổng thể
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Giảm kích thước vùng chạm
      visualDensity: VisualDensity.compact, // Giảm khoảng cách mặc định
    );
  }
}

class _MaxPeopleFormatter extends TextInputFormatter {
  final int maxPeople;

  _MaxPeopleFormatter(this.maxPeople);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    try {
      final int? value = int.parse(newValue.text);
      if ((value != null && value > maxPeople) || value! <= 0 ) {
        // Nếu giá trị lớn hơn 10, trả về giá trị cũ
        return oldValue;
      }
    } catch (e) {
      // Nếu không parse được, trả về giá trị cũ
      return oldValue;
    }

    return newValue;
  }
}