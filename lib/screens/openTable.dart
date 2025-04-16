import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import '../services/service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'buffetScreen.dart';

class TableSelectionScreen extends StatefulWidget {
  @override
  _TableSelectionScreenState createState() => _TableSelectionScreenState();
}

class _TableSelectionScreenState extends State<TableSelectionScreen> {
  List<Map<String, dynamic>> tables = [];
  int? selectedTable;

  @override
  void initState() {
    super.initState();
    loadTableStatus();
  }

  Future<void> loadTableStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> openedTables = prefs.getStringList('openedTables') ?? [];

    setState(() {
      tables = List.generate(10, (index) {
        int tableNum = index + 1;
        return {
          'number': tableNum,
          'isOccupied': openedTables.contains(tableNum.toString()),
        };
      });
    });
  }

  void selectTable(BuildContext context, int tableNumber) {
    final table = tables.firstWhere((t) => t['number'] == tableNumber);

    if (!table['isOccupied']) {
      setState(() {
        selectedTable = tableNumber;
      });
      _showTableDialog(context, tableNumber);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bàn này đã có người, vui lòng chọn bàn khác'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  Future<void> _showTableDialog(BuildContext context, int tableNumber) async {
    TextEditingController peopleController = TextEditingController();

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.table_restaurant, color: Colors.orange[400], size: 28),
              SizedBox(width: 10),
              Text(
                'Mở Bàn $tableNumber',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: peopleController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Số người',
                  labelStyle: TextStyle(color: Colors.orange[400]),
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
              onPressed: () {
                setState(() => selectedTable = null);
                Navigator.pop(context);
              },
              child: Text('Hủy', style: TextStyle(color: Colors.red[600])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[400],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 5,
              ),
              onPressed: () {
                if (peopleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng nhập số người'), backgroundColor: Colors.red[700]),
                  );
                  return;
                }
                Navigator.pop(context);
                _showCodeDialog(
                  context,
                  tableNumber,
                  int.parse(peopleController.text),
                );
              },
              child: Text('Xác nhận', style: TextStyle(color: Colors.black87)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCodeDialog(BuildContext context, int tableNumber, int numberOfCustomers) async {
    TextEditingController codeController = TextEditingController();

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Xác Nhận Mã Code',
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
              onPressed: () {
                setState(() => selectedTable = null);
                Navigator.pop(context);
              },
              child: Text('Hủy', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[400],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 5,
              ),
              onPressed: () async {
                if (codeController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng nhập mã code'), backgroundColor: Colors.red[700]),
                  );
                  return;
                }

                final result = await TableService.openTable(
                  tableNumber: tableNumber.toString(),
                  numberOfCustomers: numberOfCustomers,
                  secretCode: codeController.text,
                );

                if (result['success']) {
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  List<String> openedTables = prefs.getStringList('openedTables') ?? [];
                  if (!openedTables.contains(tableNumber.toString())) {
                    openedTables.add(tableNumber.toString());
                    await prefs.setStringList('openedTables', openedTables);
                  }
                  await loadTableStatus();
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => BuffetSelectionScreen()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message']), backgroundColor: Colors.red[700]),
                  );
                }
              },
              child: Text('Xác nhận', style: TextStyle(color: Colors.black87)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Xác định số cột dựa trên kích thước màn hình
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 800 ? 4 : 2; // 4 cột cho màn lớn, 2 cột cho màn nhỏ

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Chọn Bàn',
          style: TextStyle(
            color: Colors.orange[400],
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(screenWidth > 800 ? 40.0 : 20.0), // Padding lớn hơn cho màn lớn
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chọn bàn trống',
              style: TextStyle(
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
                  childAspectRatio: screenWidth > 800 ? 1.5 : 1.3, // Tỷ lệ linh hoạt
                ),
                itemCount: tables.length,
                itemBuilder: (context, index) {
                  final table = tables[index];
                  final isOccupied = table['isOccupied'];
                  final isSelected = selectedTable == table['number'];

                  return GestureDetector(
                    onTap: () => selectTable(context, table['number']),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isOccupied
                            ? Colors.grey[700]
                            : isSelected
                            ? Colors.orange[400]
                            : Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Bàn ${table['number']}',
                          style: TextStyle(
                            fontSize: screenWidth > 800 ? 24 : 22,
                            fontWeight: FontWeight.bold,
                            color: isOccupied || isSelected ? Colors.white : Colors.orange[400],
                          ),
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
}