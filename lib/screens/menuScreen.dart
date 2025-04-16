import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MenuScreen extends StatefulWidget {
  final int packageId; // Nhận package_id từ BuffetSelectionScreen

  MenuScreen({required this.packageId});

  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<Map<String, dynamic>> menuItems = [];
  List<Map<String, dynamic>> cart = [];
  bool isLoading = true;
  String? errorMessage;
  int selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    fetchMenuItems();
  }

  // Hàm lấy danh sách món ăn từ API
  Future<void> fetchMenuItems() async {
    final String apiUrl = 'https://soa-deploy.up.railway.app/menu/packages/${widget.packageId}/menu-items'; // Thay bằng URL thực tế

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
          menuItems = data.map((item) => {
            'name': item['name'] as String,
            'category': item['category'] as String,
            'available': item['available'] as bool,
            'img': item['img'] as String?,
            'item_id': item['item_id'] as int,
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Không thể tải danh sách món ăn: ${response.statusCode}';
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

  // Lấy danh sách category duy nhất từ menuItems
  List<String> getUniqueCategories() {
    return menuItems.map((item) => item['category'] as String).toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    bool isLargeScreen = MediaQuery.of(context).size.width > 800;
    List<String> categories = getUniqueCategories();
    String buffetName = widget.packageId.toString(); // Có thể thay bằng tên từ API nếu cần

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        centerTitle: true,
        title: Text(
          'CHỌN MÓN - Buffet $buffetName',
          style: TextStyle(
            color: Colors.orange[400],
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'Lobster',
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
                          '${cart.fold(0, (sum, item) => sum + (item['quantity'] as int))}',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
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
                        fontFamily: 'Lobster',
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
                    key: Key(item['name']),
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
                        SnackBar(content: Text('${item['name']} đã bị xóa')),
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
                                          setState(() {
                                            cart[index]['quantity'] = quantity + 1;
                                          });
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
                onPressed: cart.isEmpty
                    ? null
                    : () {
                  int totalItems = cart.fold(0, (sum, item) => sum + (item['quantity'] as int));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã xác nhận $totalItems món!', style: TextStyle(fontSize: 16)),
                      backgroundColor: Colors.green[700],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  Navigator.pop(context);
                },
                child: Text(
                  'Xác Nhận (${cart.fold(0, (sum, item) => sum + (item['quantity'] as int))})',
                  style: TextStyle(fontSize: 20, color: Colors.black87, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(categories.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ChoiceChip(
                      label: Text(categories[index], style: TextStyle(fontSize: 16)),
                      selected: selectedCategoryIndex == index,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => selectedCategoryIndex = index);
                        }
                      },
                      selectedColor: Colors.orange[400],
                      backgroundColor: Colors.grey[700],
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      labelStyle: TextStyle(
                        color: selectedCategoryIndex == index ? Colors.black87 : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
                  : GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isLargeScreen ? 4 : 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: menuItems
                    .where((item) => item['category'] == categories[selectedCategoryIndex])
                    .length,
                itemBuilder: (context, index) {
                  final filteredItems =
                  menuItems.where((item) => item['category'] == categories[selectedCategoryIndex]).toList();
                  final item = filteredItems[index];
                  return GestureDetector(
                    onTap: item['available']
                        ? () {
                      setState(() {
                        int existingIndex = cart.indexWhere((cartItem) => cartItem['name'] == item['name']);
                        if (existingIndex != -1) {
                          cart[existingIndex]['quantity'] = (cart[existingIndex]['quantity'] as int) + 1;
                        } else {
                          cart.add({'name': item['name'], 'image': item['img'], 'quantity': 1});
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✅ Đã thêm ${item['name']} vào giỏ hàng',
                            style: TextStyle(fontSize: 16),
                          ),
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
                                          cart.indexWhere((cartItem) => cartItem['name'] == item['name']);
                                          if (existingIndex != -1) {
                                            cart[existingIndex]['quantity'] =
                                                (cart[existingIndex]['quantity'] as int) + 1;
                                          } else {
                                            cart.add({'name': item['name'], 'image': item['img'], 'quantity': 1});
                                          }
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '✅ Đã thêm ${item['name']} vào giỏ hàng',
                                              style: TextStyle(fontSize: 16),
                                            ),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {},
                  icon: Icon(Icons.call, color: Colors.white, size: 24),
                  label: Text(
                    'Gọi Nhân Viên',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
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
                        'Xem Giỏ (${cart.fold(0, (sum, item) => sum + (item['quantity'] as int))})',
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