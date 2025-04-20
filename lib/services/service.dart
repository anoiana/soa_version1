import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String baseUrl = 'https://soa-deploy.up.railway.app';

  // Load món ăn
  static Future<List<Map<String, dynamic>>> fetchMenuItems(int packageId) async {
    final String apiUrl = '$baseUrl/menu/packages/$packageId/menu-items';
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((item) => {
          'name': item['name'] as String,
          'category': item['category'] as String,
          'available': item['available'] as bool,
          'img': item['img'] as String?,
          'item_id': item['item_id'] as int,
        }).toList();
      } else {
        throw Exception('Không thể tải danh sách món ăn: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  // Gửi yêu cầu xác nhận đơn hàng
  static Future<bool> confirmOrder(int tableNumber, List<Map<String, dynamic>> items) async {
    const String apiUrl = '$baseUrl/order/confirm';
    final body = {
      'table_number': tableNumber,
      'items': items.map((item) => {
        'item_id': item['item_id'],
        'quantity': item['quantity'],
      }).toList(),
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Xác nhận thất bại: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  // Mở bàn
  static Future<Map<String, dynamic>> openTable({
    required String tableNumber,
    required int numberOfCustomers,
    required String secretCode,
  }) async {
    const String apiUrl = '$baseUrl/order/open-table/';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'table_number': tableNumber,
          'number_of_customers': numberOfCustomers,
          'secret_code': secretCode,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body); // Lấy dữ liệu từ response body
        return {
          'success': true,
          'data': data, // Trả về toàn bộ dữ liệu, bao gồm session_id
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Có lỗi xảy ra',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối: $e',
      };
    }
  }

  // Lấy trạng thái bàn
  static Future<List<Map<String, dynamic>>> fetchTableStatus() async {
    const String apiUrl = '$baseUrl/menu/tables/status';
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => {
          'number': item['table_number'] as int,
          'status': item['status'] as String,
        }).toList();
      } else {
        throw Exception('Không thể tải trạng thái bàn: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  // Lấy danh sách buffet
  static Future<List<Map<String, dynamic>>> fetchBuffetMenu() async {
    const String apiUrl = '$baseUrl/menu/buffet/';
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((item) => {
          'name': item['name'] as String,
          'description': item['description'] as String,
          'price_per_person': item['price_per_person'] as String,
          'img': item['img'] as String,
          'package_id': item['package_id'] as int,
        }).toList();
      } else {
        throw Exception('Không thể tải danh sách buffet: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  // Cập nhật gói buffet cho bàn
  static Future<bool> updatePackage(String tableNumber, int packageId) async {
    const String apiUrl = '$baseUrl/order/table/update-package';
    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'table_number': tableNumber,
          'package_id': packageId,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Cập nhật gói thất bại: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  // Đóng bàn
  static Future<bool> closeTable(int tableNumber, String secretCode) async {
    final String apiUrl = '$baseUrl/order/close/$tableNumber';
    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'secret_code': secretCode}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Đóng bàn thất bại: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getTableStatus() async {
    const String apiUrl = '$baseUrl/tables/status';
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => {
          'number': item['table_number'] as int,
          'status': item['status'] as String,
        }).toList();
      } else {
        throw Exception('Không thể tải trạng thái bàn: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }
}