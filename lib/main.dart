import 'package:flutter/material.dart';
import 'package:soa_version1/screens/signInScreen.dart';

import 'screens/openTable.dart';

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
      home: LoginScreen(),
    );
  }
}

// Màn hình chọn loại buffet
