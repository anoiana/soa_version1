// lib/services/table_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class TableService {
  static const String _apiUrl = 'https://soa-deploy.up.railway.app/order/open-table/';

  static Future<Map<String, dynamic>> openTable({
    required String tableNumber,
    required int numberOfCustomers,
    required String secretCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
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
        return {'success': true};
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
}
