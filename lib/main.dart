import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MenuScreen(),
    );
  }
}

class MenuScreen extends StatefulWidget {
  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int selectedIndex = 0;

  final List<List<Map<String, String>>> categoryItems = [
    [
      {'name': 'Buffet cao cấp', 'image': 'buffet.jpg', 'price': '1,500,000'},
      {'name': 'Buffet hải sản', 'image': 'buffet2.jpg', 'price': '1,200,000'},{'name': 'Mì Ý sốt kem', 'image': 'cahoi1.jpg', 'price': '500,000'},
      {'name': 'Pizza hải sản', 'image': 'trasua2.jpg', 'price': '600,000'},
      {'name': 'Mì Ý sốt kem', 'image': 'bo1.jpg', 'price': '500,000'},
      {'name': 'Bò Kobe', 'image': 'bo1.jpg', 'price': '2,000,000'},
      {'name': 'Thịt bò Úc', 'image': 'bo2.jpg', 'price': '1,000,000'}
    ],
    [
      {'name': 'Bò Kobe', 'image': 'bo1.jpg', 'price': '2,000,000'},
      {'name': 'Thịt bò Úc', 'image': 'bo2.jpg', 'price': '1,000,000'},{'name': 'Mì Ý sốt kem', 'image': 'cahoi1.jpg', 'price': '500,000'},
      {'name': 'Pizza hải sản', 'image': 'trasua2.jpg', 'price': '600,000'},
      {'name': 'Mì Ý sốt kem', 'image': 'bo1.jpg', 'price': '500,000'},
      {'name': 'Pizza hải sản', 'image': 'bo1.jpg', 'price': '600,000'},
      {'name': 'Mì Ý sốt kem', 'image': 'bo1.jpg', 'price': '500,000'},
    ],
    [
      {'name': 'Tôm hùm', 'image': 'tomhum.jpg', 'price': '1,800,000'},
      {'name': 'Cá hồi', 'image': 'cahoi1.jpg', 'price': '1,000,000'},{'name': 'Mì Ý sốt kem', 'image': 'cahoi1.jpg', 'price': '500,000'},
      {'name': 'Pizza hải sản', 'image': 'trasua2.jpg', 'price': '600,000'},
      {'name': 'Mì Ý sốt kem', 'image': 'bo1.jpg', 'price': '500,000'},
      {'name': 'Bò Kobe', 'image': 'bo1.jpg', 'price': '2,000,000'},
      {'name': 'Thịt bò Úc', 'image': 'bo2.jpg', 'price': '1,000,000'}
    ],
    [
      {'name': 'Trà sửa truyền thống', 'image': 'trasua1.jpg', 'price': '500,000'},
      {'name': 'Trà sửa trứng cút', 'image': 'trasua2.jpg', 'price': '600,000'},
      {'name': 'Mì Ý sốt kem', 'image': 'cahoi1.jpg', 'price': '500,000'},
      {'name': 'Pizza hải sản', 'image': 'trasua2.jpg', 'price': '600,000'},
      {'name': 'Mì Ý sốt kem', 'image': 'bo1.jpg', 'price': '500,000'},
      {'name': 'Bò Kobe', 'image': 'bo1.jpg', 'price': '2,000,000'},
      {'name': 'Thịt bò Úc', 'image': 'bo2.jpg', 'price': '1,000,000'}
    ],
    [
      {'name': 'Nấm đùi vịt', 'image': 'bo1.jpg', 'price': '500,000'},
      {'name': 'Nấm đùi gà', 'image': 'bo1.jpg', 'price': '600,000'},
      {'name': 'Mì Ý sốt kem', 'image': 'cahoi1.jpg', 'price': '500,000'},
      {'name': 'Pizza hải sản', 'image': 'trasua2.jpg', 'price': '600,000'},
      {'name': 'Mì Ý sốt kem', 'image': 'bo1.jpg', 'price': '500,000'},
      {'name': 'Pizza hải sản', 'image': 'bo1.jpg', 'price': '600,000'},
      {'name': 'Mì Ý sốt kem', 'image': 'bo1.jpg', 'price': '500,000'},
    ],
    [
      {'name': 'Heo quây sữa ông Thọ', 'image': 'cahoi1.jpg', 'price': '500,000'},
      {'name': 'Heo giả cầy', 'image': 'cahoi2.jpg', 'price': '600,000'},
      {'name': 'Mì Ý sốt kem', 'image': 'cahoi1.jpg', 'price': '500,000'},
      {'name': 'Pizza hải sản', 'image': 'trasua2.jpg', 'price': '600,000'},
      {'name': 'Mì Ý sốt kem', 'image': 'bo1.jpg', 'price': '500,000'},
      {'name': 'Pizza hải sản', 'image': 'bo1.jpg', 'price': '600,000'},
      {'name': 'Mì Ý sốt kem', 'image': 'bo1.jpg', 'price': '500,000'},
    ],
    [
      {'name': 'Mì Ý sốt kem', 'image': 'cahoi1.jpg', 'price': '500,000'},
      {'name': 'Pizza hải sản', 'image': 'trasua2.jpg', 'price': '600,000'},
      {'name': 'Mì Ý sốt kem', 'image': 'bo1.jpg', 'price': '500,000'},
      {'name': 'Pizza hải sản', 'image': 'bo1.jpg', 'price': '600,000'},
      {'name': 'Mì Ý sốt kem', 'image': 'bo1.jpg', 'price': '500,000'},
      {'name': 'Pizza hải sản', 'image': 'bo2.jpg', 'price': '600,000'},
      {'name': 'Mì Ý sốt kem', 'image': 'buffet.jpg', 'price': '500,000'},
      {'name': 'Pizza hải sản', 'image': 'cahoi1.jpg', 'price': '600,000'},
      {'name': 'Mì Ý sốt kem', 'image': 'buffet.jpg', 'price': '500,000'},
      {'name': 'Pizza hải sản', 'image': 'cahoi2.jpg', 'price': '600,000'},
    ],
  ];

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
                // mainAxisAlignment: MainAxisAlignment.center, // Căn giữa theo chiều dọc
                // crossAxisAlignment: CrossAxisAlignment.center, // Căn giữa theo chiều ngang
                children: [
                  Text(
                    'MENU',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10), // Khoảng cách giữa chữ và ảnh
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50), // Bo góc ảnh (nếu muốn)
                    child: Image.asset(
                      'spidermen.jpg', // Đường dẫn ảnh
                      width: 90, // Điều chỉnh kích thước
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),

            ListTile(
              leading: Icon(Icons.fastfood,),
              title: Text('Buffet'),
              onTap: () {
                setState(() => selectedIndex = 0);
                Navigator.pop(context); // Đóng Drawer
              },
            ),
            ListTile(
              leading: Icon(Icons.local_dining),
              title: Text('Bò'),
              onTap: () {
                setState(() => selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.set_meal),
              title: Text('Hải sản'),
              onTap: () {
                setState(() => selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.fastfood),
              title: Text('Trà sữa'),
              onTap: () {
                setState(() => selectedIndex = 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.local_dining),
              title: Text('Nấm'),
              onTap: () {
                setState(() => selectedIndex = 4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.set_meal),
              title: Text('Thịt heo'),
              onTap: () {
                setState(() => selectedIndex = 5);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.more_horiz),
              title: Text('Món khác'),
              onTap: () {
                setState(() => selectedIndex = 6);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      )
          : null,
      body: Row(
        children: [


          if (MediaQuery.of(context).size.width > 800)
            NavigationRail(
              backgroundColor: Colors.blueGrey[800],
              extended: true,
              selectedLabelTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              unselectedLabelTextStyle: TextStyle(fontSize: 16, color: Colors.white70),
              leading: Column(
                children: [
                  SizedBox(height: 16), // Khoảng cách trên cùng
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10), // Thụt vào 10px hai bên
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20), // Bo tròn góc viền
                        border: Border.all(
                          color: Colors.black, // Màu viền
                          width: 1, // Độ dày viền
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26, // Đổ bóng nhẹ
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(17), // Giảm nhẹ để ảnh không bị lệch với viền ngoài
                        child: Image.asset(
                          'spidermen.jpg', // Đường dẫn chính xác
                          width: 150,
                          height: 100,
                          fit: BoxFit.cover, // Ảnh vừa khít không dư khoảng trắng
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20), // Khoảng cách giữa logo và danh sách menu
                ],
              ),
              destinations: [
                NavigationRailDestination(icon: Icon(Icons.fastfood, color: Colors.white, size: 32), label: Text('Buffet')),
                NavigationRailDestination(icon: Icon(Icons.local_dining, color: Colors.white, size: 32), label: Text('Bò')),
                NavigationRailDestination(icon: Icon(Icons.set_meal, color: Colors.white, size: 32), label: Text('Hải sản')),
                NavigationRailDestination(icon: Icon(Icons.fastfood, color: Colors.white, size: 32), label: Text('Trà sửa')),
                NavigationRailDestination(icon: Icon(Icons.local_dining, color: Colors.white, size: 32), label: Text('Nấm')),
                NavigationRailDestination(icon: Icon(Icons.set_meal, color: Colors.white, size: 32), label: Text('Thịt heo')),
                NavigationRailDestination(icon: Icon(Icons.more_horiz, color: Colors.white, size: 32), label: Text('Món khác')),
              ],
              selectedIndex: selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  selectedIndex = index;
                });
              },
            ),
          if (MediaQuery.of(context).size.width > 800)
            VerticalDivider(
              width: 3, // Chiều rộng của đường phân cách
              thickness: 3, // Độ dày của đường phân cách
              color: Colors.white, // Màu sắc của đường phân cách
            ),

          Expanded(
            child: Column(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min, // Giữ cho Column không chiếm toàn bộ chiều cao
                  children: [
                    AppBar(
                      backgroundColor: Colors.blueGrey[800],
                      centerTitle: true, // Căn giữa tiêu đề
                      title: Text(
                        'WELCOME',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          fontFamily: 'Lobster',
                          shadows: [
                            Shadow(
                              blurRadius: 4.0,
                              color: Colors.black45,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        IconButton(icon: Icon(Icons.person, color: Colors.white), onPressed: () {}),
                        IconButton(icon: Icon(Icons.shopping_cart, color: Colors.white), onPressed: () {}),
                      ],
                    ),
                    Container(
                      width: double.infinity, // Đảm bảo Divider chiếm hết chiều ngang
                      height: 2, // Độ dày của đường kẻ
                      color: Colors.white, // Màu sắc của đường kẻ
                    ),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = constraints.maxWidth > 800 ? 3 : 2;
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: 3 / 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: categoryItems[selectedIndex].length,
                          itemBuilder: (context, index) {
                            return Card(
                              color: Colors.blueGrey[700],
                              elevation: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Image.asset(
                                      categoryItems[selectedIndex][index]['image']!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              categoryItems[selectedIndex][index]['name']!,
                                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                            Text(
                                              '${categoryItems[selectedIndex][index]['price']} VND',
                                              style: TextStyle(color: Colors.redAccent),
                                            ),
                                          ],
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            // TODO: Xử lý khi nhấn vào dấu cộng
                                            print("Thêm ${categoryItems[selectedIndex][index]['name']} vào giỏ hàng");
                                          },
                                          icon: Icon(Icons.add_circle, color: Colors.green, size: 28),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
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
                        onPressed: () {},
                        child: Text('Gọi nhân viên', style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () {},
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
    );
  }
}
