import 'package:flutter/material.dart';
import 'dart:math' as math; // Để tạo dữ liệu giả
import 'package:intl/intl.dart'; // Để định dạng ngày và tiền tệ
import 'package:google_fonts/google_fonts.dart'; // Sử dụng font từ theme (nếu có)

// --- Constants (Có thể dùng chung hoặc định nghĩa riêng) ---
const double kDefaultPadding = 8.0;
const double kCardElevation = 4.0; // Có thể dùng giá trị riêng

// --- Management Screen Widget ---

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({Key? key}) : super(key: key);

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  DateTime? _selectedDate; // Ngày được chọn cho tab Lịch sử
  bool _isLoadingHistory = false; // Trạng thái tải lịch sử
  bool _isLoadingCurrentShift = false; // Trạng thái tải ca trực
  List<Map<String, dynamic>> _currentShiftBills = []; // Dữ liệu ca trực
  List<Map<String, dynamic>> _historicalBills = []; // Dữ liệu lịch sử

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Tải dữ liệu ban đầu khi màn hình được tạo
    _fetchCurrentShiftSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Tải/Tạo dữ liệu giả lập ---
  void _generateDummyData({DateTime? forDate}) {
    // Dữ liệu giả cho ca trực hiện tại (chỉ tạo nếu forDate là null)
    if (forDate == null) {
      _currentShiftBills = List.generate(5, (index) => {
        'id': 30 + index,
        'table': math.Random().nextInt(20) + 1,
        'time': DateTime.now().subtract(Duration(minutes: math.Random().nextInt(120))), // Thời gian trong 2 tiếng gần đây
        'amount': (math.Random().nextDouble() * 500 + 100) * 1000,
        'status': math.Random().nextBool() ? 'paid' : 'unpaid', // Trạng thái giả
      });
    }

    // Dữ liệu giả cho lịch sử (chỉ tạo nếu forDate có giá trị)
    if (forDate != null) {
      _historicalBills = List.generate(math.Random().nextInt(8) + 3, (index) => {
        'id': 100 + index + forDate.day,
        'table': math.Random().nextInt(20) + 1,
        'time': forDate.add(Duration(hours: math.Random().nextInt(20)+1, minutes: math.Random().nextInt(60))),
        'amount': (math.Random().nextDouble() * 600 + 50) * 1000,
        'status': 'paid',
      });
    }
  }

  // --- Hàm fetch dữ liệu thật (Thay thế bằng API calls) ---
  Future<void> _fetchCurrentShiftSummary() async {
    if (!mounted) return;
    setState(() => _isLoadingCurrentShift = true );
    print("Fetching current shift summary...");
    await Future.delayed(Duration(seconds: 1)); // Giả lập độ trễ mạng
    // TODO: Gọi API thật để lấy dữ liệu ca trực
    _generateDummyData(); // Tạo lại data giả
    if(mounted) {
       setState(() => _isLoadingCurrentShift = false );
    }
    print("Fetched current shift summary.");
  }

  Future<void> _fetchHistoricalBills(DateTime date) async {
    if (!mounted) return;
    setState(() { _isLoadingHistory = true; _historicalBills = []; });
    print("Fetching historical bills for: ${DateFormat('dd/MM/yyyy').format(date)}");
    await Future.delayed(Duration(seconds: 1)); // Giả lập độ trễ mạng
    // TODO: Gọi API thật để lấy dữ liệu lịch sử theo ngày `date`
    _generateDummyData(forDate: date); // Tạo data giả theo ngày
    if(mounted) {
       setState(() { _isLoadingHistory = false; });
    }
    print("Fetched historical bills.");
  }

  // --- Hàm chọn ngày ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
       builder: (context, child) {
         // Lấy theme hiện tại để custom DatePicker
         final currentTheme = Theme.of(context);
         return Theme(
           data: currentTheme.copyWith(
             colorScheme: currentTheme.colorScheme.copyWith(
               primary: currentTheme.colorScheme.secondary, // Màu header
               onPrimary: Colors.black, // Chữ trên header
               surface: currentTheme.dialogTheme.backgroundColor ?? currentTheme.scaffoldBackgroundColor, // Nền dialog
               onSurface: Colors.white, // Chữ chính
             ),
             dialogBackgroundColor: currentTheme.dialogTheme.backgroundColor ?? currentTheme.scaffoldBackgroundColor,
             textButtonTheme: TextButtonThemeData(
               style: TextButton.styleFrom(
                 foregroundColor: currentTheme.colorScheme.secondary, // Màu chữ nút
               ),
             ),
           ),
           child: child!,
         );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked );
      _fetchHistoricalBills(picked); // Fetch dữ liệu cho ngày mới chọn
    }
  }

  // --- Build Method Chính ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // AppBar riêng cho màn hình quản lý
      appBar: AppBar(
        title: Text('Quản Lý Nhà Hàng', style: theme.appBarTheme.titleTextStyle), // Dùng style từ theme
        leading: IconButton( // Thêm nút Back nếu màn hình này được push vào
           icon: Icon(Icons.arrow_back),
           onPressed: () => Navigator.of(context).pop(), // Quay lại màn hình trước
        ),
        bottom: TabBar(
            controller: _tabController,
            indicatorColor: theme.colorScheme.secondary,
            labelColor: theme.colorScheme.secondary,
            unselectedLabelColor: Colors.white70,
            labelStyle: GoogleFonts.oswald(fontWeight: FontWeight.w600, fontSize: 15),
            unselectedLabelStyle: GoogleFonts.oswald(fontWeight: FontWeight.w500, fontSize: 15),
            tabs: const [
              Tab(text: 'CA TRỰC', icon: Icon(Icons.schedule, size: 20)),
              Tab(text: 'LỊCH SỬ', icon: Icon(Icons.history, size: 20)),
            ],
          ),
      ),
      // Body với TabBarView
      body: Container(
         decoration: BoxDecoration( // Thêm nền gradient nếu muốn
           gradient: LinearGradient(
             begin: Alignment.topCenter, end: Alignment.bottomCenter,
             colors: [ theme.scaffoldBackgroundColor, theme.scaffoldBackgroundColor.withBlue(theme.scaffoldBackgroundColor.blue + 5).withGreen(theme.scaffoldBackgroundColor.green + 2), ],
             stops: const [0.3, 1.0],
           ),
         ),
         child: TabBarView(
           controller: _tabController,
           children: [
             _buildCurrentShiftTab(theme),
             _buildHistoryTab(theme),
           ],
         ),
      ),
    );
  }

  // --- Widget cho Tab Ca Trực ---
  Widget _buildCurrentShiftTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _fetchCurrentShiftSummary,
      color: theme.colorScheme.secondary,
      backgroundColor: theme.scaffoldBackgroundColor,
      child: _isLoadingCurrentShift && _currentShiftBills.isEmpty // Hiển thị loading nếu đang tải và chưa có dữ liệu
        ? Center(child: CircularProgressIndicator(color: theme.colorScheme.secondary))
        : ListView.builder(
          // Thêm physics để luôn có thể kéo refresh ngay cả khi ít item
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(kDefaultPadding),
          itemCount: _currentShiftBills.isNotEmpty ? _currentShiftBills.length : 1,
          itemBuilder: (context, index) {
            if (_currentShiftBills.isEmpty) {
              return Center( child: Padding( padding: const EdgeInsets.symmetric(vertical: 50.0),
                  child: Text('Không có phiếu tính tiền nào trong ca trực.', style: theme.textTheme.bodyMedium), ),
              );
            }
            final bill = _currentShiftBills[index];
            return _buildBillCard(theme, bill);
          },
        ),
    );
  }

  // --- Widget cho Tab Lịch Sử ---
  Widget _buildHistoryTab(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kDefaultPadding * 1.5, kDefaultPadding*1.5, kDefaultPadding*1.5, kDefaultPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Đẩy nút chọn ngày sang phải
            children: [
              Text(
                _selectedDate == null
                    ? 'Chọn ngày xem:'
                    : 'Lịch sử ngày: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                 style: theme.textTheme.titleMedium?.copyWith(fontSize: 15.5),
              ),
              ElevatedButton.icon( // Dùng ElevatedButton cho đẹp hơn
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text('Chọn Ngày'),
                style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding * 1.5, vertical: kDefaultPadding * 0.8),
                   textStyle: const TextStyle(fontSize: 13),
                   backgroundColor: theme.colorScheme.secondary.withOpacity(0.8)
                ),
                onPressed: () => _selectDate(context),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 0.5, indent: kDefaultPadding, endIndent: kDefaultPadding),
        Expanded(
          child: _isLoadingHistory
              ? Center(child: CircularProgressIndicator(color: theme.colorScheme.secondary))
              : _selectedDate == null
                 ? Center(child: Column( // Hướng dẫn rõ hơn
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                        Icon(Icons.date_range_outlined, size: 50, color: Colors.grey[600]),
                        SizedBox(height: kDefaultPadding),
                        Text('Vui lòng chọn ngày để xem lịch sử.', style: theme.textTheme.bodyMedium),
                     ],
                   ))
                 : RefreshIndicator(
                     onRefresh: () => _fetchHistoricalBills(_selectedDate!),
                     color: theme.colorScheme.secondary,
                     backgroundColor: theme.scaffoldBackgroundColor,
                     child: ListView.builder(
                       physics: const AlwaysScrollableScrollPhysics(),
                       padding: const EdgeInsets.all(kDefaultPadding),
                       itemCount: _historicalBills.isNotEmpty ? _historicalBills.length : 1,
                       itemBuilder: (context, index) {
                          if (_historicalBills.isEmpty) {
                             return Center( child: Padding( padding: const EdgeInsets.symmetric(vertical: 50.0),
                                 child: Text('Không có phiếu tính tiền nào cho ngày đã chọn.', style: theme.textTheme.bodyMedium), ),
                             );
                          }
                          final bill = _historicalBills[index];
                          return _buildBillCard(theme, bill);
                       },
                     ),
                  ),
        ),
      ],
    );
  }

  // --- Hàm build Card chung cho phiếu tính tiền ---
  Widget _buildBillCard(ThemeData theme, Map<String, dynamic> billData) {
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final bool isPaid = billData['status'] == 'paid';

    return Card(
      elevation: kCardElevation * 0.8,
      margin: const EdgeInsets.only(bottom: kDefaultPadding * 1.2),
      shape: RoundedRectangleBorder( // Thêm viền nhẹ nếu chưa thanh toán
         borderRadius: BorderRadius.circular(10),
         side: BorderSide(
             color: isPaid ? Colors.transparent : Colors.orangeAccent.withOpacity(0.5),
             width: 1
         )
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: kDefaultPadding * 1.8, vertical: kDefaultPadding),
        leading: Tooltip( // Thêm tooltip cho trạng thái
          message: isPaid ? 'Đã thanh toán' : 'Chưa thanh toán',
          child: CircleAvatar(
            backgroundColor: isPaid ? Colors.green[700]?.withOpacity(0.8) : Colors.orange[700]?.withOpacity(0.8),
            child: Icon(
              isPaid ? Icons.check_circle_outline : Icons.receipt_long_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        title: Text(
          'Phiếu #${billData['id']} - Bàn ${billData['table']}',
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 15.5),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5.0),
          child: Text(
            'TG: ${DateFormat('HH:mm - dd/MM/yy').format(billData['time'] as DateTime)}',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[300]),
          ),
        ),
        trailing: Text(
          formatCurrency.format(billData['amount']),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.secondary,
            fontSize: 15
          ),
        ),
        onTap: () {
          // TODO: Implement xem chi tiết hóa đơn
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Xem chi tiết phiếu #${billData['id']} (chưa cài đặt)'), duration: Duration(seconds: 1)),
          );
        },
      ),
    );
  }

} // End of _ManagementScreenState