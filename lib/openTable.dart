import 'package:flutter/material.dart';
import 'main.dart';

class TableSelectionScreen extends StatefulWidget {
  @override
  _TableSelectionScreenState createState() => _TableSelectionScreenState();
}

class _TableSelectionScreenState extends State<TableSelectionScreen> {
  final List<Map<String, dynamic>> tables = List.generate(
    10,
        (index) => {
      'number': index + 1,
      'isOccupied': index % 2 == 0,
    },
  );

  int? selectedTable;

  Future<void> _showCodeDialog(BuildContext context) async {
    TextEditingController codeController = TextEditingController();

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900], // Màu nền tối cho dialog
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
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.vpn_key, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.grey[800], // Màu nền tối cho TextField
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
                setState(() {
                  selectedTable = null;
                });
                Navigator.pop(context);
              },
              child: Text('Hủy', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700], // Nút xanh đậm hơn
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (codeController.text == '1234') {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => BuffetSelectionScreen()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Mã code không đúng')),
                  );
                }
              },
              child: Text('Xác nhận', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void selectTable(BuildContext context, int tableNumber) {
    if (!tables[tableNumber - 1]['isOccupied']) {
      setState(() {
        selectedTable = tableNumber;
      });
      _showTableDialog(context, tableNumber);
    }
  }

  Future<void> _showTableDialog(BuildContext context, int tableNumber) async {
    TextEditingController peopleController = TextEditingController();

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900], // Màu nền tối cho dialog
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.table_restaurant, color: Colors.teal[300], size: 28),
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
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.people, color: Colors.teal[300]),
                  filled: true,
                  fillColor: Colors.grey[800], // Màu nền tối cho TextField
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
                setState(() {
                  selectedTable = null;
                });
                Navigator.pop(context);
              },
              child: Text('Hủy', style: TextStyle(color: Colors.red[400])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700], // Nút teal đậm hơn
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (peopleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng nhập số người')),
                  );
                  return;
                }
                Navigator.pop(context);
                _showCodeDialog(context);
              },
              child: Text('Xác nhận', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isLargeScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: Colors.grey[850], // Màu nền tối cho toàn màn hình
      appBar: AppBar(
        backgroundColor: Colors.teal[900], // AppBar màu teal đậm
        centerTitle: true,
        title: Text(
          'Chọn Bàn',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chọn bàn trống',
              style: TextStyle(
                color: Colors.white, // Chữ trắng cho dark theme
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isLargeScreen ? 5 : 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: tables.length,
                itemBuilder: (context, index) {
                  bool isOccupied = tables[index]['isOccupied'];
                  return GestureDetector(
                    onTap: () => selectTable(context, tables[index]['number']),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: isOccupied ? Colors.red[900] : Colors.green[900], // Màu đậm hơn cho dark theme
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: selectedTable == tables[index]['number']
                              ? Colors.yellow[700] ?? Colors.yellow // Nếu null, dùng Colors.yellow
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black54, // Bóng tối đậm hơn
                            blurRadius: 6,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isOccupied ? Icons.lock : Icons.table_restaurant,
                            color: Colors.white,
                            size: 35,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Bàn ${tables[index]['number']}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            isOccupied ? 'Đã có người' : 'Còn trống',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
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