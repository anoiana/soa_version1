import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // Thêm import này
import 'openTable.dart';

class BuffetSelectionScreen extends StatefulWidget {
  @override
  _BuffetSelectionScreenState createState() => _BuffetSelectionScreenState();
}

class _BuffetSelectionScreenState extends State<BuffetSelectionScreen> {
  List<Map<String, dynamic>> buffetTypes = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchBuffetMenu();
  }

  Future<void> fetchBuffetMenu() async {
    const String apiUrl = 'https://soa-deploy.up.railway.app/menu/buffet/';
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          buffetTypes = data.map((item) => {
            'name': item['name'] as String,
            'description': item['description'] as String,
            'price_per_person': item['price_per_person'] as String,
            'img': item['img'] as String?,
            'package_id': item['package_id'] as int,
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Không thể tải danh sách buffet: ${response.statusCode}';
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
                      fontFamily: 'Lobster',
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
                NavigationRailDestination(
                  icon: Icon(Icons.info, color: Colors.white70),
                  label: Text('Thông Tin'),
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
                    'CHỌN LOẠI BUFFET',
                    style: TextStyle(
                      color: Colors.orange[400],
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Lobster',
                    ),
                  ),
                  elevation: 0,
                  actions: [
                    IconButton(
                      icon: Icon(Icons.exit_to_app, color: Colors.orange[400], size: 28),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => TableSelectionScreen()),
                        );
                      },
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
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MenuScreen(buffetIndex: index),
                              ),
                            );
                          },
                          child: AnimatedContainer(
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
                                        ? Image.network(
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
                                        '${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(int.parse(buffetTypes[index]['price_per_person']))} / người',
                                        style: TextStyle(
                                          color: Colors.orange[400],
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Giữ nguyên MenuScreen nếu không cần thay đổi
class MenuScreen extends StatefulWidget {
  final int buffetIndex;

  MenuScreen({required this.buffetIndex});

  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(); // Thay bằng mã gốc của bạn
  }
}