import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'order.dart';


class KitChen extends StatefulWidget {
  @override
  _KitChen createState() => _KitChen();
}

class _KitChen extends State<KitChen> {
  int selectedIndex = 0;
  bool _isMenuExpanded = false;

  final List<List<Map<String, dynamic>>> categoryItems = [
    [
      {'name': 'Buffet cao cấp', 'image': 'buffet.jpg', 'price': '1,500,000', 'isAvailable': 'true'},
      {'name': 'Buffet hải sản', 'image': 'buffet2.jpg', 'price': '1,200,000', 'isAvailable': 'true'},
      {'name': 'Mì Ý sốt kem', 'image': 'cahoi1.jpg', 'price': '500,000', 'isAvailable': 'true'},
      {'name': 'Pizza hải sản', 'image': 'trasua2.jpg', 'price': '600,000', 'isAvailable': 'true'},
      {'name': 'Mì Ý sốt kem', 'image': 'bo1.jpg', 'price': '500,000', 'isAvailable': 'true'},
      {'name': 'Bò Kobe', 'image': 'bo1.jpg', 'price': '2,000,000', 'isAvailable': 'true'},
      {'name': 'Thịt bò Úc', 'image': 'bo2.jpg', 'price': '1,000,000', 'isAvailable': 'true'},
    ],
    // Các danh mục khác giữ nguyên
  ];

  final List<Map<String, dynamic>> tables = List.generate(
    20,
        (index) => {
      'name': 'Bàn ${index + 1}',
      'newOrders': 0,
      'orders': <Map<String, dynamic>>[], // Danh sách order của bàn
      'isVisible': false,
    },
  );

  final ScrollController _scrollController = ScrollController();
  bool _showExclamationMark = false;
  double _exclamationMarkAngle = 0.0;
  bool _isAboveViewport = false;
  int _orderIdCounter = 1; // Biến đếm để tạo order_id
  int _orderItemIdCounter = 1; // Biến đếm để tạo order_item_id

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _addNewOrder(int tableIndex) {
    setState(() {
      tables[tableIndex]['newOrders'] = (tables[tableIndex]['newOrders'] as int) + 1;
      // Tạo một order mới với nhiều order_items
      tables[tableIndex]['orders'].add({
        'order_id': _orderIdCounter++,
        'session_id': 1, // Giả lập session_id
        'order_time': DateTime.now(),
        'order_items': [
          {
            'order_item_id': _orderItemIdCounter++,
            'item_id': 1, // Giả lập item_id
            'item': 'Mì Ý sốt kem',
            'quantity': 2,
            'status': 'ordered',
          },
          {
            'order_item_id': _orderItemIdCounter++,
            'item_id': 2,
            'item': 'Pizza hải sản',
            'quantity': 1,
            'status': 'ordered',
          },
        ],
      });
      _updateExclamationMark();
    });
  }

  void _updateExclamationMark() {
    bool hasUnseenNewOrders = false;
    int? targetTableIndex;

    for (int i = 0; i < tables.length; i++) {
      if (tables[i]['newOrders'] > 0 && !tables[i]['isVisible']) {
        hasUnseenNewOrders = true;
        targetTableIndex = i;
        break;
      }
    }

    if (hasUnseenNewOrders && targetTableIndex != null) {
      const double itemHeight = 100.0;
      final double scrollOffset = _scrollController.offset;
      final double viewportHeight = _scrollController.position.viewportDimension;

      double targetTableY = (targetTableIndex ~/ 4) * itemHeight;
      _isAboveViewport = targetTableY < scrollOffset;

      double dy = _isAboveViewport
          ? targetTableY - scrollOffset
          : targetTableY - (scrollOffset + viewportHeight - 80);
      double angle = math.atan2(dy, 0);

      setState(() {
        _showExclamationMark = true;
        _exclamationMarkAngle = angle;
      });
    } else {
      setState(() {
        _showExclamationMark = false;
      });
    }
  }

  void _onScroll() {
    const double itemHeight = 100.0;
    final double scrollOffset = _scrollController.offset;
    final double viewportHeight = _scrollController.position.viewportDimension;

    int firstVisibleIndex = (scrollOffset / itemHeight).floor() * 4;
    int lastVisibleIndex = ((scrollOffset + viewportHeight) / itemHeight).ceil() * 4;

    for (int i = 0; i < tables.length; i++) {
      tables[i]['isVisible'] = (i >= firstVisibleIndex && i <= lastVisibleIndex);
    }
    _updateExclamationMark();
  }

  void _showOrderPopup(BuildContext context, int tableIndex) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.blueGrey[800],
          title: Text('Đơn hàng của ${tables[tableIndex]['name']}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Container(
            width: double.maxFinite,
            child: tables[tableIndex]['orders'].isEmpty
                ? Text('Chưa có đơn hàng nào.', style: TextStyle(color: Colors.white))
                : ListView.builder(
              shrinkWrap: true,
              itemCount: tables[tableIndex]['orders'].length,
              itemBuilder: (context, orderIndex) {
                final order = tables[tableIndex]['orders'][orderIndex];
                return Card(
                  color: Colors.blueGrey[700],
                  child: ListTile(
                    title: Text('Đơn hàng #${order['order_id']}', style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                      'Thời gian: ${order['order_time'].toString().substring(0, 16)}',
                      style: TextStyle(color: Colors.white70),
                    ),
                    onTap: () {
                      // Hiển thị popup chi tiết các order_items
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor: Colors.blueGrey[800],
                            title: Text('Chi tiết đơn hàng #${order['order_id']}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            content: Container(
                              width: double.maxFinite,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: order['order_items'].length,
                                itemBuilder: (context, itemIndex) {
                                  final item = order['order_items'][itemIndex];
                                  return Card(
                                    color: Colors.blueGrey[600],
                                    child: ListTile(
                                      title: Text('${item['item']} (x${item['quantity']})', style: TextStyle(color: Colors.white)),
                                      subtitle: Text('Trạng thái: ${item['status']}', style: TextStyle(color: Colors.white70)),
                                      trailing: item['status'] != 'served'
                                          ? ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                        onPressed: () {
                                          setState(() {
                                            order['order_items'][itemIndex]['status'] = 'served';
                                            // Cập nhật newOrders nếu tất cả items trong order đều "served"
                                            if (order['order_items'].every((item) => item['status'] == 'served')) {
                                              tables[tableIndex]['newOrders'] = (tables[tableIndex]['newOrders'] as int) - 1;
                                            }
                                          });
                                          Navigator.of(context).pop();
                                        },
                                        child: Text('Hoàn thành'),
                                      )
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text('Đóng', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Đóng', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      drawer: MediaQuery.of(context).size.width <= 800
          ? Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueGrey[800]),
              child: Column(
                children: [
                  Text('MENU', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.asset('spidermen.jpg', width: 90, height: 90, fit: BoxFit.cover),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.restaurant, color: Colors.white),
              title: Text('Danh sách bàn ăn', style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() {
                  selectedIndex = 0;
                  _isMenuExpanded = false;
                });
                Navigator.pop(context);
              },
            ),
            ExpansionTile(
              leading: Icon(Icons.local_dining, color: Colors.white),
              title: Text('Danh sách món ăn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              initiallyExpanded: _isMenuExpanded,
              onExpansionChanged: (bool expanded) => setState(() => _isMenuExpanded = expanded),
              children: [
                _buildMenuItem('Buffet', 1),
                _buildMenuItem('Bò', 2),
                _buildMenuItem('Hải sản', 3),
                _buildMenuItem('Trà sữa', 4),
                _buildMenuItem('Nấm', 5),
                _buildMenuItem('Thịt heo', 6),
                _buildMenuItem('Món khác', 7),
              ],
            ),
            ListTile(
              leading: Icon(Icons.list_alt, color: Colors.white),
              title: Text('Danh sách đơn hàng', style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() {
                  selectedIndex = 8;
                  _isMenuExpanded = false;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      )
          : null,
      body: Stack(
        children: [
          Row(
            children: [
              if (MediaQuery.of(context).size.width > 800)
                NavigationRail(
                  backgroundColor: Colors.blueGrey[800],
                  extended: true,
                  selectedLabelTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  unselectedLabelTextStyle: TextStyle(fontSize: 16, color: Colors.white70),
                  leading: Column(
                    children: [
                      SizedBox(height: 16),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black, width: 1),
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(17),
                            child: Image.asset('spidermen.jpg', width: 150, height: 100, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: Icon(Icons.restaurant, color: Colors.white, size: 32),
                      label: Text('Danh sách bàn ăn', style: TextStyle(color: Colors.white)),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.local_dining, color: Colors.white, size: 32),
                      label: Text('Danh sách món ăn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.list_alt, color: Colors.white, size: 32),
                      label: Text('Danh sách đơn hàng', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                  selectedIndex: selectedIndex == 0 ? 0 : (selectedIndex == 8 ? 2 : 1),
                  onDestinationSelected: (int index) {
                    setState(() {
                      if (index == 0) {
                        selectedIndex = 0;
                        _isMenuExpanded = false;
                      } else if (index == 2) {
                        selectedIndex = 8;
                        _isMenuExpanded = false;
                      } else {
                        _isMenuExpanded = !_isMenuExpanded;
                      }
                    });
                  },
                ),
              if (MediaQuery.of(context).size.width > 800 && _isMenuExpanded && selectedIndex != 8)
                Container(
                  width: 200,
                  color: Colors.blueGrey[700],
                  child: ListView(
                    children: [
                      _buildMenuItem('Buffet', 1),
                      _buildMenuItem('Bò', 2),
                      _buildMenuItem('Hải sản', 3),
                      _buildMenuItem('Trà sữa', 4),
                      _buildMenuItem('Nấm', 5),
                      _buildMenuItem('Thịt heo', 6),
                      _buildMenuItem('Món khác', 7),
                    ],
                  ),
                ),
              if (MediaQuery.of(context).size.width > 800)
                VerticalDivider(width: 3, thickness: 3, color: Colors.white),
              Expanded(
                child: Column(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppBar(
                          backgroundColor: Colors.blueGrey[800],
                          centerTitle: true,
                          title: Text(
                            'WELCOME',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                              fontFamily: 'Lobster',
                              shadows: [Shadow(blurRadius: 4.0, color: Colors.black45, offset: Offset(2, 2))],
                            ),
                          ),
                          actions: [
                            IconButton(icon: Icon(Icons.person, color: Colors.white), onPressed: () {}),
                            IconButton(icon: Icon(Icons.shopping_cart, color: Colors.white), onPressed: () {}),
                          ],
                        ),
                        Container(width: double.infinity, height: 2, color: Colors.white),
                      ],
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: selectedIndex == 0
                            ? _buildTableGrid()
                            : (selectedIndex == 8
                            ? OrderScreen(tables: tables)
                            : _buildMenuList()),
                      ),
                    ),
                    Container(
                      color: Colors.blueGrey[800],
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => _addNewOrder(1),
                            child: Text('Gọi nhân viên', style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () => _addNewOrder(3),
                            child: Text('Thanh toán ngay', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_showExclamationMark)
            Positioned(
              top: _isAboveViewport ? 80 : null,
              bottom: !_isAboveViewport ? 80 : null,
              right: 20,
              child: Transform.rotate(
                angle: _isAboveViewport ? _exclamationMarkAngle + math.pi + math.pi / 2 : _exclamationMarkAngle + math.pi / 2,
                child: Image.asset('assets/exclamation_mark.png', width: 40, height: 40, fit: BoxFit.contain),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, int index) {
    return MouseRegion(
      onEnter: (_) => setState(() {}),
      onExit: (_) => setState(() {}),
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedIndex = index;
            _isMenuExpanded = false;
          });
        },
        child: Container(
          color: selectedIndex == index ? Colors.blueGrey[600] : Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: selectedIndex == index ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableGrid() {
    return GridView.builder(
      controller: _scrollController,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 1.0,
      ),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        int newOrders = tables[index]['newOrders'] as int;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(Icons.restaurant, size: 40, color: Colors.white),
                  splashRadius: 24,
                  onPressed: () => _showOrderPopup(context, index),
                ),
                if (newOrders > 0)
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                      child: Center(
                        child: Text('$newOrders', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            Text(tables[index]['name'], style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        );
      },
    );
  }

  Widget _buildMenuList() {
    return ListView.builder(
      itemCount: categoryItems[selectedIndex - 1].length,
      itemBuilder: (context, index) {
        return Card(
          color: Colors.blueGrey[700],
          elevation: 5,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 100,
                height: 100,
                child: Image.asset(categoryItems[selectedIndex - 1][index]['image']!, fit: BoxFit.cover),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(categoryItems[selectedIndex - 1][index]['name']!, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('${categoryItems[selectedIndex - 1][index]['price']} VND', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ),
              StatefulBuilder(
                builder: (context, setState) {
                  bool isAvailable = categoryItems[selectedIndex - 1][index]['isAvailable'].toString() == 'true';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    child: Switch(
                      value: isAvailable,
                      onChanged: (value) {
                        setState(() {
                          categoryItems[selectedIndex - 1][index]['isAvailable'] = value.toString();
                        });
                        print("Món ${categoryItems[selectedIndex - 1][index]['name']} ${value ? 'có hàng' : 'hết hàng'}");
                      },
                      activeColor: Colors.green,
                      inactiveTrackColor: Colors.redAccent,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}