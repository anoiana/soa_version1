import 'package:flutter/material.dart';

class OrderScreen extends StatefulWidget {
  final List<Map<String, dynamic>> tables;

  OrderScreen({required this.tables});

  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  late List<Map<String, dynamic>> allOrders;

  @override
  void initState() {
    super.initState();
    allOrders = [];
    for (var table in widget.tables) {
      for (var order in table['orders']) {
        allOrders.add({
          'tableName': table['name'],
          'order_id': order['order_id'],
          'session_id': order['session_id'],
          'order_time': order['order_time'],
          'order_items': List<Map<String, dynamic>>.from(order['order_items']),
        });
      }
    }
  }

  void _showOrderItemsPopup(BuildContext context, Map<String, dynamic> order, int orderIndex) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.blueGrey[800],
          title: Text('Chi tiết đơn hàng #${order['order_id']}',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Container(
            width: double.maxFinite,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setStateDialog) {
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: order['order_items'].length,
                  itemBuilder: (context, itemIndex) {
                    final item = order['order_items'][itemIndex];
                    return Card(
                      color: Colors.blueGrey[600],
                      child: ListTile(
                        title: Text('${item['item']} (x${item['quantity']})',
                            style: TextStyle(color: Colors.white)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Trạng thái: ${item['status']}',
                                style: TextStyle(color: Colors.white70)),
                            if (item['note'] != null && item['note'].isNotEmpty)
                              Text('Ghi chú: ${item['note']}',
                                  style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                        trailing: item['status'] != 'Hoàn thành'
                            ? ElevatedButton(
                          onPressed: () {
                            setState(() {
                              setStateDialog(() {
                                order['order_items'][itemIndex]['status'] = 'Hoàn thành';
                              });
                            });
                          },
                          child: Text('Hoàn thành'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        )
                            : Icon(Icons.check_circle, color: Colors.green),
                      ),
                    );
                  },
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

  bool _isOrderInProgress(Map<String, dynamic> order) {
    return order['order_items'].any((item) => item['status'] != 'Hoàn thành') &&
        order['order_items'].any((item) => item['status'] == 'Hoàn thành');
  }

  bool _isOrderCompleted(Map<String, dynamic> order) {
    return order['order_items'].every((item) => item['status'] == 'Hoàn thành');
  }

  @override
  Widget build(BuildContext context) {
    final inProgressOrders = allOrders.where((order) => !_isOrderCompleted(order)).toList();
    final completedOrders = allOrders.where(_isOrderCompleted).toList();

    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Danh Sách Đơn Hàng Đang Xử Lý',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              inProgressOrders.isEmpty
                  ? Center(
                child: Text(
                  'Chưa có đơn hàng nào đang xử lý.',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: inProgressOrders.length,
                itemBuilder: (context, index) {
                  final order = inProgressOrders[index];
                  return Card(
                    color: Colors.blueGrey[700],
                    elevation: 5,
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(
                        '${order['tableName']} - Đơn hàng #${order['order_id']}',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Thời gian: ${order['order_time'].toString().substring(0, 16)}',
                        style: TextStyle(color: Colors.white70),
                      ),
                      trailing: _isOrderInProgress(order)
                          ? Icon(Icons.hourglass_empty, color: Colors.yellow)
                          : null,
                      onTap: () => _showOrderItemsPopup(context, order, index),
                    ),
                  );
                },
              ),
              SizedBox(height: 24),
              Text(
                'Những Đơn Hàng Đã Hoàn Thành',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              completedOrders.isEmpty
                  ? Center(
                child: Text(
                  'Chưa có đơn hàng nào hoàn thành.',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: completedOrders.length,
                itemBuilder: (context, index) {
                  final order = completedOrders[index];
                  return Card(
                    color: Colors.blueGrey[700],
                    elevation: 5,
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(
                        '${order['tableName']} - Đơn hàng #${order['order_id']}',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Thời gian: ${order['order_time'].toString().substring(0, 16)}',
                        style: TextStyle(color: Colors.white70),
                      ),
                      trailing: Icon(Icons.check_circle, color: Colors.green),
                      onTap: () => _showOrderItemsPopup(context, order, index),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}