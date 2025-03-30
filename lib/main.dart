import 'package:flutter/material.dart';

import 'openTable.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.teal[900], // Đậm hơn cho dark theme
        scaffoldBackgroundColor: Colors.grey[850], // Nền tối
        fontFamily: 'Roboto',
      ),
      home: TableSelectionScreen(),
    );
  }
}

// Màn hình chọn loại buffet
class BuffetSelectionScreen extends StatefulWidget {
  @override
  _BuffetSelectionScreenState createState() => _BuffetSelectionScreenState();
}

class _BuffetSelectionScreenState extends State<BuffetSelectionScreen> {
  final List<Map<String, String>> buffetTypes = [
    {'name': 'Buffet Thịt Nướng', 'price': '1,500,000', 'image': 'buffet.jpg'},
    {'name': 'Buffet Hải Sản', 'price': '1,200,000', 'image': 'buffet3.jpg'},
    {'name': 'Buffet Chay', 'price': '800,000', 'image': 'buffet4.jpg'},
    {'name': 'Buffet Bún Đậu', 'price': '600,000', 'image': 'buffet_bd.jpg'},
    {'name': 'Buffet Su Si', 'price': '700,000', 'image': 'uffett_suisi.jpg'},
    {'name': 'Buffet Trà Sữa', 'price': '500,000', 'image': 'buffet5.jpg'},
  ];

  @override
  Widget build(BuildContext context) {
    bool isLargeScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Row(
        children: [
          if (isLargeScreen)
            NavigationRail(
              backgroundColor: Colors.teal[900], // Đậm hơn cho dark theme
              extended: true,
              selectedIndex: 0,
              onDestinationSelected: (int index) {},
              labelType: NavigationRailLabelType.none,
              selectedLabelTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              unselectedLabelTextStyle: TextStyle(fontSize: 16, color: Colors.white70),
              leading: Column(
                children: [
                  SizedBox(height: 20),
                  Text(
                    'MENU BUFFET',
                    style: TextStyle(
                      color: Colors.white,
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
                  icon: Icon(Icons.fastfood, color: Colors.white),
                  label: Text('Chọn Buffet'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.info, color: Colors.white),
                  label: Text('Thông Tin'),
                ),
              ],
            ),
          Expanded(
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.teal[900], // Đậm hơn cho dark theme
                  centerTitle: true,
                  title: Text(
                    'CHỌN LOẠI BUFFET',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Lobster',
                    ),
                  ),
                  elevation: 0,
                  actions: [
                    IconButton(
                      icon: Icon(Icons.exit_to_app, color: Colors.white, size: 28),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => TableSelectionScreen()),
                        ); // Quay lại màn hình trước đó
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: GridView.builder(
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
                                colors: [Colors.teal[800]!, Colors.teal[600]!], // Đậm hơn
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black54, // Bóng tối đậm hơn
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
                                    child: Image.asset(
                                      buffetTypes[index]['image']!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
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
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        '${buffetTypes[index]['price']} VND',
                                        style: TextStyle(
                                          color: Colors.yellow[700], // Vàng đậm hơn
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

class MenuScreen extends StatefulWidget {
  final int buffetIndex;

  MenuScreen({required this.buffetIndex});

  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int selectedCategoryIndex = 0;

  final List<List<List<Map<String, String>>>> buffetItems = [
    // Buffet Thịt Nướng
    [
      [
        {'name': 'Sườn Heo Nướng', 'image': 'suon.jpg'},
        {'name': 'Ba Chỉ Nướng', 'image': 'bachi.jpg'},
      ],
      [
        {'name': 'Bò Kobe', 'image': 'bo1.jpg'},
        {'name': 'Thịt Bò Úc', 'image': 'bo2.jpg'},
      ],
      [
        {'name': 'Sườn Cừu Nướng', 'image': 'cuu1.jpg'},
        {'name': 'Đùi Cừu', 'image': 'cuu2.jpg'},
      ],
      [
        {'name': 'Sườn Dê Nướng', 'image': 'cuu1.jpg'},
        {'name': 'Đùi Dê', 'image': 'cuu2.jpg'},
      ],
    ],
    // Buffet Hải Sản
    [
      [
        {'name': 'Tôm Hùm', 'image': 'tomhum.jpg'},
        {'name': 'Tôm Sú', 'image': 'tomsu.jpg'},
      ],
      [
        {'name': 'Cá Hồi', 'image': 'cahoi1.jpg'},
        {'name': 'Cá Ngừ', 'image': 'cangu.jpg'},
      ],
      [
        {'name': 'Pizza Hải Sản', 'image': 'trasua2.jpg'},
        {'name': 'Mực Nướng', 'image': 'muc.jpg'},
      ],
      [
        {'name': 'Pizza Hải Sản', 'image': 'trasua2.jpg'},
        {'name': 'Mực Xào', 'image': 'muc.jpg'},
      ],
    ],
    // Buffet Chay
    [
      [
        {'name': 'Nấm Đùi Gà', 'image': 'nam1.jpg'},
        {'name': 'Rau Củ Nướng', 'image': 'raucu.jpg'},
      ],
      [
        {'name': 'Đậu Hũ Nướng', 'image': 'dauhu.jpg'},
        {'name': 'Đậu Hũ Chiên', 'image': 'dauhu2.jpg'},
      ],
      [
        {'name': 'Đậu Hũ Kho', 'image': 'dauhu.jpg'},
        {'name': 'Rau Muốn Xào', 'image': 'dauhu2.jpg'},
      ],
    ],
    // Buffet Trà Sữa
    [
      [
        {'name': 'Matcha Trà Xanh', 'image': 'nam1.jpg'},
        {'name': 'Trà Sữa Truyền Thống', 'image': 'raucu.jpg'},
      ],
      [
        {'name': 'Bánh Plan', 'image': 'dauhu.jpg'},
        {'name': 'Trà Sữa Socola', 'image': 'dauhu2.jpg'},
      ],
      [
        {'name': 'Soda Chanh Dây', 'image': 'dauhu.jpg'},
        {'name': 'Soda Dâu', 'image': 'dauhu2.jpg'},
      ],
      [
        {'name': 'Trà Sữa Khoai Môn', 'image': 'dauhu.jpg'},
        {'name': 'Trà Sữa Bắp', 'image': 'dauhu2.jpg'},
      ],
    ],
  ];

  List<Map<String, dynamic>> cart = [];

  @override
  Widget build(BuildContext context) {
    bool isLargeScreen = MediaQuery.of(context).size.width > 800;
    String buffetName = widget.buffetIndex == 0
        ? "Buffet Thịt Nướng"
        : widget.buffetIndex == 1
        ? "Buffet Hải Sản"
        : widget.buffetIndex == 2
        ? "Buffet Chay"
        : "Buffet Bún Đậu";

    List<String> categoryNames = widget.buffetIndex == 0
        ? ['Thịt Heo', 'Thịt Bò', 'Thịt Cừu', 'Thịt Dê']
        : widget.buffetIndex == 1
        ? ['Tôm', 'Cá', 'Hải Sản Khác', 'Món Khác']
        : widget.buffetIndex == 2
        ? ['Rau Củ', 'Đậu Hũ', 'Món Khác']
        : ['Trà Sữa', 'Bánh', 'Soda', 'Khác'];

    return Scaffold(
      backgroundColor: Colors.grey[900], // Nền tối đậm hơn chút
      appBar: AppBar(
        backgroundColor: Colors.teal[900],
        centerTitle: true,
        title: Text(
          'CHỌN MÓN - $buffetName',
          style: TextStyle(
            color: Colors.white,
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
                  Icon(Icons.shopping_cart, color: Colors.white, size: 32),
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
                  colors: [Colors.teal[900]!, Colors.teal[700]!],
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
                        color: Colors.white,
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
                              child: Image.asset(
                                item['image'],
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
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
                  backgroundColor: Colors.teal[700],
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
                  style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
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
                children: List.generate(categoryNames.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ChoiceChip(
                      label: Text(categoryNames[index], style: TextStyle(fontSize: 16)),
                      selected: selectedCategoryIndex == index,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => selectedCategoryIndex = index);
                        }
                      },
                      selectedColor: Colors.teal[600],
                      backgroundColor: Colors.grey[700],
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      labelStyle: TextStyle(
                        color: selectedCategoryIndex == index ? Colors.white : Colors.white70,
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
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isLargeScreen ? 4 : 2,
                  childAspectRatio: 0.75, // Giảm tỷ lệ để card rộng rãi hơn
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: buffetItems[widget.buffetIndex][selectedCategoryIndex].length,
                itemBuilder: (context, index) {
                  final item = buffetItems[widget.buffetIndex][selectedCategoryIndex][index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        int existingIndex = cart.indexWhere((cartItem) => cartItem['name'] == item['name']);
                        if (existingIndex != -1) {
                          cart[existingIndex]['quantity'] = (cart[existingIndex]['quantity'] as int) + 1;
                        } else {
                          cart.add({'name': item['name'], 'image': item['image'], 'quantity': 1});
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✅ Đã thêm ${item['name']} vào giỏ hàng',
                            style: TextStyle(fontSize: 16),
                          ),
                          backgroundColor: Colors.teal[700],
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
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
                              child: Hero(
                                tag: item['name']!,
                                child: Image.asset(
                                  item['image']!,
                                  fit: BoxFit.cover,
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
                                    color: Colors.teal[300],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal[700],
                                      shape: CircleBorder(),
                                      padding: EdgeInsets.all(10),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        int existingIndex = cart.indexWhere((cartItem) => cartItem['name'] == item['name']);
                                        if (existingIndex != -1) {
                                          cart[existingIndex]['quantity'] = (cart[existingIndex]['quantity'] as int) + 1;
                                        } else {
                                          cart.add({'name': item['name'], 'image': item['image'], 'quantity': 1});
                                        }
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '✅ Đã thêm ${item['name']} vào giỏ hàng',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          backgroundColor: Colors.teal[700],
                                          behavior: SnackBarBehavior.floating,
                                          duration: Duration(seconds: 2),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      );
                                    },
                                    child: Icon(Icons.add, color: Colors.white, size: 24),
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
                        backgroundColor: Colors.teal[700],
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: cart.isEmpty
                          ? null
                          : () => Scaffold.of(context).openEndDrawer(),
                      icon: Icon(Icons.shopping_cart, color: Colors.white, size: 24),
                      label: Text(
                        'Xem Giỏ (${cart.fold(0, (sum, item) => sum + (item['quantity'] as int))})',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}