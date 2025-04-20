import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math; // Để tạo dữ liệu giả
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart'; // Import for firstWhereOrNull
import 'package:intl/intl.dart'; // Để định dạng ngày và tiền tệ
// import 'package:data_table_2/data_table_2.dart'; // REMOVED DataTable2 - Still removed

// --- Constants ---
const double kCardElevation = 1.0;
const String BASE_API_URL = "https://soa-deploy.up.railway.app";

// Define fixed column widths ONLY
const double _colWidthId = 70.0;
const double _colWidthStatus = 140.0;
const double _colWidthDetails = 80.0;
// Flex factors cho các cột Expanded
const int _colFlexPaymentTime = 4; // TG Thanh Toán
const int _colFlexPaymentMethod = 3; // **PT THANH TOÁN (Mới)**
const int _colFlexAmount = 3; // Tổng Tiền

// --- Data Models (Giữ nguyên) ---
class Shift {
  final int shiftId;
  final DateTime startTime;
  final DateTime endTime;
  final String secretCode;
  Shift(
      {required this.shiftId,
      required this.startTime,
      required this.endTime,
      required this.secretCode});
  factory Shift.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(String? dtString) {
      if (dtString == null) return null;
      try {
        if (dtString.endsWith('Z')) {
          return DateTime.parse(dtString).toLocal();
        }
        return DateTime.tryParse(dtString)?.toLocal();
      } catch (e) {
        print("Error parsing shift date '$dtString': $e");
        return null;
      }
    }

    return Shift(
        shiftId: json['shift_id'] as int? ?? 0,
        startTime: parseDt(json['start_time'] as String?) ?? DateTime(1970),
        endTime: parseDt(json['end_time'] as String?) ?? DateTime(1970),
        secretCode: json['secret_code'] as String? ?? 'N/A');
  }
}

class Payment {
  final int paymentId;
  final double amount;
  final DateTime paymentTime;
  final DateTime? creationTime; // Vẫn giữ lại trong model nếu API trả về
  final String paymentMethod; // Đã có sẵn
  final int? tableSessionId;
  final int? tableNumber;
  Payment(
      {required this.paymentId,
      required this.amount,
      required this.paymentTime,
      this.creationTime,
      required this.paymentMethod,
      this.tableSessionId,
      this.tableNumber});

  factory Payment.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(String? dtString) {
      if (dtString == null) return null;
      try {
        if (dtString.endsWith('Z')) {
          return DateTime.parse(dtString).toLocal();
        }
        return DateTime.tryParse(dtString)?.toLocal();
      } catch (e) {
        print("Error parsing payment date '$dtString': $e");
        return null;
      }
    }

    final id = json['payment_id'] as int? ?? json['id'] as int? ?? 0;
    final paymentTime =
        parseDt(json['payment_time'] as String? ?? json['time'] as String?) ??
            DateTime(1970);
    final creationTime = // Vẫn parse nhưng không dùng trong bảng
        parseDt(json['created_time'] as String?) ?? paymentTime;

    return Payment(
        paymentId: id,
        amount: (json['amount'] as num? ?? 0).toDouble(),
        paymentTime: paymentTime,
        creationTime: creationTime, // Giữ lại giá trị
        paymentMethod: json['payment_method'] as String? ??
            'Tiền mặt', // Lấy PT Thanh Toán
        tableSessionId: json['table_session_id'] as int?,
        tableNumber: json['table_number'] as int?);
  }
}

class ShiftPaymentSummary {
  final int shiftId;
  final double totalRevenue;
  final List<Payment> payments;
  ShiftPaymentSummary(
      {required this.shiftId,
      required this.totalRevenue,
      required this.payments});
  factory ShiftPaymentSummary.fromJson(Map<String, dynamic> json) {
    var paymentList = json['payments'] as List? ?? [];
    List<Payment> parsedPayments = paymentList
        .map((p) => Payment.fromJson(p as Map<String, dynamic>))
        .where((p) => p.paymentTime.year > 1970)
        .toList();
    return ShiftPaymentSummary(
        shiftId: json['shift_id'] as int? ?? 0,
        totalRevenue: (json['total_revenue'] as num? ?? 0).toDouble(),
        payments: parsedPayments);
  }
}

// --- Hàm main và MyApp (Giữ nguyên Theme) ---
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Theme definition remains the same
    return MaterialApp(
      title: 'POS Management',
      theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Color(0xFFF8F9FA),
          fontFamily: 'Poppins',
          cardTheme: CardTheme(
              elevation: kCardElevation,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
              margin: EdgeInsets.zero,
              color: Colors.white),
          dataTableTheme: DataTableThemeData(
              headingRowColor: MaterialStateProperty.all(Colors.blue.shade100),
              dataRowColor: MaterialStateProperty.resolveWith((states) {
                return Colors.white;
              }),
              dividerThickness: 1,
              horizontalMargin: 12,
              dataTextStyle: TextStyle(
                  color: Color(0xFF495057),
                  fontSize: 12.5,
                  fontFamily: 'Poppins'),
              headingTextStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF343A40),
                  fontSize: 12.5,
                  fontFamily: 'Poppins')),
          textTheme: TextTheme(
              titleLarge: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212529)),
              titleMedium: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF343A40)),
              titleSmall: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF343A40)),
              bodyMedium: TextStyle(color: Color(0xFF495057), fontSize: 12.5),
              bodySmall: TextStyle(color: Color(0xFF6C757D), fontSize: 10.5),
              labelSmall: TextStyle(
                  color: Color(0xFF6C757D),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500),
              labelMedium: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF495057))),
          inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Color(0xFFF1F3F5),
              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Color(0xFFDEE2E6))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Color(0xFFDEE2E6))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(
                      color: Colors.blueAccent.shade700, width: 1.5)),
              hintStyle: TextStyle(color: Color(0xFFADB5BD), fontSize: 13)),
          colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(
              secondary: Colors.blueAccent.shade700,
              onSecondary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF343A40),
              background: Color(0xFFF8F9FA),
              onBackground: Color(0xFF343A40),
              error: Colors.red.shade700,
              onError: Colors.white),
          chipTheme: ChipThemeData(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF495057),
                  fontFamily: 'Poppins'),
              secondaryLabelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  fontFamily: 'Poppins'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  side: BorderSide.none),
              elevation: 0,
              pressElevation: 1,
              brightness: Brightness.light),
          elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.shade700,
                  foregroundColor: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 13))),
          outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueAccent.shade700,
                  side: BorderSide(
                      color: Colors.blueAccent.shade700.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13))),
          textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Colors.blueAccent.shade700, padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10), textStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13))),
          appBarTheme: AppBarTheme(elevation: 0, backgroundColor: Colors.white, iconTheme: IconThemeData(color: Color(0xFF495057)), actionsIconTheme: IconThemeData(color: Color(0xFF495057)), titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF343A40), fontFamily: 'Poppins')),
          dividerTheme: DividerThemeData(
            color: Colors.grey.shade300,
            thickness: 1,
          ),
          datePickerTheme: DatePickerThemeData(headerBackgroundColor: Colors.blueAccent.shade700, headerForegroundColor: Colors.white, backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: kCardElevation)),
      debugShowCheckedModeBanner: false,
      home: ManagementScreen(),
    );
  }
}

// --- Management Screen Widget ---
class ManagementScreen extends StatefulWidget {
  const ManagementScreen({Key? key}) : super(key: key);
  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  // --- State Variables (Giữ nguyên) ---
  int _currentViewIndex = 0;
  DateTime? _selectedDate;
  bool _isLoadingHistory = false;
  List<Payment> _historicalBills = [];
  String? _historyError;
  bool _isLoadingShifts = true;
  String? _shiftError;
  List<Shift> _shifts = [];
  int? _selectedShiftId;
  bool _isLoadingShiftPayments = false;
  String? _paymentError;
  List<Payment> _shiftPayments = [];
  double _selectedShiftTotalRevenue = 0.0;

  // Formatters
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  final DateFormat _timeFormatter = DateFormat('HH:mm');
  final DateFormat _fullDateTimeFormatter = DateFormat('HH:mm:ss dd/MM/yyyy');
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');

  // --- Constants for Table Layout ---
  final double _tableRowHeight = 50.0;
  final double _tableHeaderHeight = 40.0;
  final double _tableCellHorizontalPadding = 5.0; // Padding bên trong cell

  @override
  void initState() {
    super.initState();
    _fetchShifts();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // --- Helper Methods ---

  Widget _buildStatsGrid(BuildContext context, ThemeData theme) {
    final kDefaultPadding = 12.0;
    return LayoutBuilder(builder: (context, constraints) {
      int crossAxisCount = 4;
      if (constraints.maxWidth < 1200) crossAxisCount = 4;
      if (constraints.maxWidth < 900) crossAxisCount = 2;
      if (constraints.maxWidth < 500) crossAxisCount = 1;
      double childAspectRatio = 2.4;
      if (crossAxisCount == 2) childAspectRatio = 2.8;
      if (crossAxisCount == 1) childAspectRatio = 4.0;
      final double crossAxisSpacing = kDefaultPadding;
      final double mainAxisSpacing = kDefaultPadding;
      return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          childAspectRatio: childAspectRatio,
          children: [
            _buildStatCard(
                theme: theme,
                icon: Icons.receipt_long,
                iconColor: Colors.green.shade600,
                title: 'Tổng phiếu (Ca)',
                value: _shiftPayments.length.toString(),
                change: '',
                changeColor: Colors.transparent,
                comparisonText: 'Trong ca hiện tại'),
            _buildStatCard(
                theme: theme,
                icon: Icons.attach_money,
                iconColor: Colors.blue.shade600,
                title: 'Doanh thu (Ca)',
                value: _currencyFormatter.format(_selectedShiftTotalRevenue),
                change: '',
                changeColor: Colors.transparent,
                comparisonText: 'Trong ca hiện tại'),
            _buildStatCard(
                theme: theme,
                icon: Icons.people_alt_outlined,
                iconColor: Colors.orange.shade700,
                title: 'Khách (Ước tính)',
                value: '...',
                change: '',
                changeColor: Colors.transparent,
                comparisonText: 'Chưa tính'),
            _buildStatCard(
                theme: theme,
                icon: Icons.access_time_filled,
                iconColor: Colors.purple.shade600,
                title: 'Thời gian còn lại (Ca)',
                value: '...',
                change: '',
                changeColor: Colors.transparent,
                comparisonText: 'Chưa tính')
          ]);
    });
  }

  Widget _buildStatCard(
      {required ThemeData theme,
      required IconData icon,
      required Color iconColor,
      required String title,
      required String value,
      required String change,
      required Color changeColor,
      required String comparisonText}) {
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title,
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.textTheme.labelSmall?.color
                                    ?.withOpacity(0.9),
                                fontWeight: FontWeight.w600)),
                        Icon(icon, size: 18, color: iconColor.withOpacity(0.8))
                      ]),
                  Text(value,
                      style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.titleLarge?.color)),
                  if (change.isNotEmpty || comparisonText.isNotEmpty)
                    Row(children: [
                      if (change.isNotEmpty) ...[
                        Icon(
                            change.startsWith('+')
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 12,
                            color: changeColor),
                        SizedBox(width: 3),
                        Text(change,
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: changeColor,
                                fontSize: 11.5)),
                        SizedBox(width: 6)
                      ],
                      Expanded(
                          child: Text(comparisonText,
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis))
                    ])
                ])));
  }

  // --- _buildTableRow (Sử dụng Spacer) ---
  Widget _buildTableRow({
    required List<Widget> cells, // **LƯU Ý: List này giờ có 6 widgets**
    required ThemeData theme,
    Color? backgroundColor,
    required double height,
    bool isHeader = false,
  }) {
    final headerStyle =
        theme.dataTableTheme.headingTextStyle ?? const TextStyle();
    final dataStyle = theme.dataTableTheme.dataTextStyle ?? const TextStyle();
    final cellPadding = EdgeInsets.symmetric(
        horizontal: _tableCellHorizontalPadding, vertical: 4.0);

    Widget buildCellWrapper(Widget content, Alignment alignment) {
      return Padding(
        padding: cellPadding,
        child: Align(
          alignment: alignment,
          child: DefaultTextStyle(
            style: isHeader ? headerStyle : dataStyle,
            child: content,
          ),
        ),
      );
    }

    // THỨ TỰ MONG MUỐN (6 cột data): MÃ HĐ, TRẠNG THÁI, TG THANH TOÁN, PT THANH TOÁN, TỔNG TIỀN, CHI TIẾT
    return Container(
      height: height,
      color: backgroundColor,
      padding: EdgeInsets.symmetric(horizontal: _tableCellHorizontalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // MÃ HĐ (Fixed Width, Left Align) - cells[0]
          SizedBox(
            width: _colWidthId,
            child: buildCellWrapper(cells[0], Alignment.centerLeft),
          ),
          const Spacer(), // Spacer 1
          // TRẠNG THÁI (Fixed Width, Center Align) - cells[1]
          SizedBox(
            width: _colWidthStatus,
            child: buildCellWrapper(cells[1], Alignment.center),
          ),
          const Spacer(), // Spacer 2
          // TG THANH TOÁN (Expanded, Left Align) - cells[2]
          Expanded(
            flex: _colFlexPaymentTime, // Cân đối flex
            child: buildCellWrapper(cells[2], Alignment.centerLeft),
          ),
          const Spacer(), // Spacer 3
          // PT THANH TOÁN (Expanded, Left Align) - cells[3]
          Expanded(
            flex: _colFlexPaymentMethod, // Cân đối flex
            child: buildCellWrapper(cells[3], Alignment.centerLeft),
          ),
          const Spacer(), // Spacer 4
          // TỔNG TIỀN (Expanded, Left Align) - cells[4]
          Expanded(
            flex: _colFlexAmount, // Cân đối flex
            child: buildCellWrapper(cells[4], Alignment.centerLeft),
          ),
          const Spacer(), // Spacer 5
          // CHI TIẾT (Fixed Width, Center Align) - cells[5]
          SizedBox(
            width: _colWidthDetails,
            child: buildCellWrapper(cells[5], Alignment.center),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, String statusText) {
    Color backgroundColor;
    Color textColor;
    IconData? iconData;
    switch (statusText.toLowerCase()) {
      case 'hoàn thành':
      case 'delivered':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        iconData = Icons.check_circle_outline_rounded;
        break;
      case 'processing':
      case 'đang xử lý':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        iconData = Icons.hourglass_top_rounded;
        break;
      case 'shipped':
      case 'đã gửi':
        backgroundColor = Colors.purple.shade100;
        textColor = Colors.purple.shade900;
        iconData = Icons.local_shipping_outlined;
        break;
      default:
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade800;
        iconData = Icons.help_outline_rounded;
    }
    return Chip(
        avatar: iconData != null
            ? Icon(iconData, size: 14, color: textColor)
            : null,
        label: Text(statusText, overflow: TextOverflow.ellipsis),
        labelStyle: theme.chipTheme.labelStyle
            ?.copyWith(color: textColor, fontSize: 11.5),
        backgroundColor: backgroundColor,
        padding: theme.chipTheme.padding,
        shape: theme.chipTheme.shape,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact);
  }

  // --- Fetch Functions ---
  Future<void> _fetchShifts() async {
    if (!mounted) return;
    setState(() {
      _isLoadingShifts = true;
      _shiftError = null;
      _shifts = [];
      _selectedShiftId = null;
      _shiftPayments = [];
      _selectedShiftTotalRevenue = 0.0;
      _paymentError = null;
    });
    print("Fetching shifts...");
    final url = Uri.parse('$BASE_API_URL/shifts/');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<Shift> fetchedShifts = data
            .map((s) => Shift.fromJson(s))
            .where((s) => s.startTime.year > 1970)
            .toList();
        fetchedShifts.sort((a, b) => a.startTime.compareTo(b.startTime));
        if (mounted) {
          setState(() {
            _shifts = fetchedShifts;
            _isLoadingShifts = false;
            _shiftError = null;
            _autoSelectCurrentOrLatestShift();
          });
        }
        print("Fetched ${_shifts.length} valid shifts.");
      } else {
        if (mounted) {
          setState(() {
            _shiftError = 'Lỗi tải ca (${response.statusCode})';
            _isLoadingShifts = false;
          });
        }
        print("Error fetching shifts: ${response.statusCode}");
      }
    } catch (e) {
      print("Exception fetching shifts: $e");
      if (mounted)
        setState(() {
          _shiftError = 'Lỗi kết nối hoặc xử lý dữ liệu ca.';
          _isLoadingShifts = false;
        });
    }
  }

  void _autoSelectCurrentOrLatestShift() {
    if (_shifts.isEmpty) {
      print("No shifts available to auto-select.");
      return;
    }
    final now = DateTime.now();
    Shift? currentShift = _shifts.firstWhereOrNull((shift) =>
        !now.isBefore(shift.startTime) && now.isBefore(shift.endTime));
    final shiftToSelect = currentShift ?? _shifts.last;

    if (_selectedShiftId != shiftToSelect.shiftId ||
        (_selectedShiftId == shiftToSelect.shiftId &&
            _shiftPayments.isEmpty &&
            !_isLoadingShiftPayments &&
            _paymentError == null)) {
      print("Auto-selecting or re-selecting shift: ${shiftToSelect.shiftId}");
      _selectShift(shiftToSelect.shiftId);
    } else {
      print(
          "Shift ${shiftToSelect.shiftId} already selected/current and has payments or is loading.");
    }
  }

  void _selectShift(int shiftId) {
    if (_selectedShiftId == shiftId && _isLoadingShiftPayments) {
      print("Shift $shiftId is already loading payments. Selection ignored.");
      return;
    }

    print("Shift selected: $shiftId");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _selectedShiftId = shiftId;
          _isLoadingShiftPayments = true;
          _shiftPayments = [];
          _selectedShiftTotalRevenue = 0.0;
          _paymentError = null;
        });
      }
      _fetchPaymentsForShift(shiftId);
    });
  }

  Future<void> _fetchPaymentsForShift(int shiftId) async {
    if (!mounted) return;

    if (_selectedShiftId == shiftId && !_isLoadingShiftPayments) {
      if (mounted) {
        setState(() => _isLoadingShiftPayments = true);
      } else {
        return;
      }
    } else if (_selectedShiftId != shiftId) {
      print(
          "Fetch for shift $shiftId aborted, selection changed to $_selectedShiftId");
      return;
    }

    print("Fetching payments for shift: $shiftId");
    final url = Uri.parse('$BASE_API_URL/payment/shift/$shiftId');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (!mounted) return;

      if (_selectedShiftId == shiftId) {
        // Re-check after await
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final summary = ShiftPaymentSummary.fromJson(data);
          summary.payments
              .sort((a, b) => b.paymentTime.compareTo(a.paymentTime));
          if (mounted) {
            setState(() {
              _shiftPayments = summary.payments;
              _selectedShiftTotalRevenue = summary.totalRevenue;
              _paymentError = null;
              _isLoadingShiftPayments = false;
            });
          }
          print(
              "Fetched ${summary.payments.length} payments for shift $shiftId. Total: ${summary.totalRevenue}");
        } else if (response.statusCode == 404) {
          if (mounted) {
            setState(() {
              _shiftPayments = [];
              _selectedShiftTotalRevenue = 0.0;
              _paymentError = null;
              _isLoadingShiftPayments = false;
            });
          }
          print("No payments found for shift $shiftId (404).");
        } else {
          if (mounted) {
            setState(() {
              _paymentError = 'Lỗi tải phiếu (${response.statusCode})';
              _isLoadingShiftPayments = false;
              _shiftPayments = [];
              _selectedShiftTotalRevenue = 0.0;
            });
          }
          print(
              "Error fetching payments for shift $shiftId: ${response.statusCode}");
        }
      } else {
        print(
            "Ignoring stale payment data for shift $shiftId, current selection is $_selectedShiftId");
      }
    } catch (e) {
      print("Exception fetching payments for shift $shiftId: $e");
      if (mounted && _selectedShiftId == shiftId) {
        setState(() {
          _paymentError = 'Lỗi kết nối hoặc xử lý dữ liệu phiếu.';
          _isLoadingShiftPayments = false;
          _shiftPayments = [];
          _selectedShiftTotalRevenue = 0.0;
        });
      }
    }
  }

  Future<void> _fetchHistoricalBills(DateTime date) async {
    if (!mounted) return;
    setState(() {
      _isLoadingHistory = true;
      _historicalBills = [];
      _historyError = null;
    });
    print("Fetching historical bills for: ${_dateFormatter.format(date)}");

    try {
      await Future.delayed(
          Duration(milliseconds: 300 + math.Random().nextInt(400)));
      _generateDummyData(forDate: date);
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      print("Error during historical bill fetch/generation: $e");
      if (mounted) {
        setState(() {
          _historyError = 'Lỗi tạo/tải dữ liệu lịch sử.';
          _isLoadingHistory = false;
          _historicalBills = [];
        });
      }
    }
  }

  void _generateDummyData({DateTime? forDate}) {
    if (forDate == null) return;
    print(
        "Generating dummy historical bills for ${_dateFormatter.format(forDate)}.");
    try {
      final random = math.Random();
      final int numberOfBills = random.nextInt(15) + 5;
      final List<Map<String, dynamic>> dummyMapList =
          List.generate(numberOfBills, (index) {
        final baseTime = forDate.add(Duration(
            hours: random.nextInt(20) + 2,
            minutes: random.nextInt(60),
            seconds: random.nextInt(60)));
        final paymentTime = baseTime;
        final creationTime = baseTime.subtract(
            Duration(minutes: random.nextInt(5), seconds: random.nextInt(30)));
        return {
          'payment_id': 1000 + index + forDate.day * 100 + forDate.month * 10,
          'table_session_id': 500 + index + forDate.day * 10,
          'table_number': random.nextInt(20) + 1,
          'payment_time': paymentTime.toIso8601String() + 'Z',
          'created_time': creationTime.toIso8601String() + 'Z',
          'amount': (random.nextDouble() * 600 + 50) * 1000,
          'payment_method': random.nextBool() ? 'Tiền mặt' : 'Chuyển khoản',
        };
      });

      if (mounted) {
        setState(() {
          _historicalBills =
              dummyMapList.map((map) => Payment.fromJson(map)).toList();
          _historicalBills
              .sort((a, b) => b.paymentTime.compareTo(a.paymentTime));
          _historyError = null;
        });
        print("Generated ${_historicalBills.length} dummy historical bills.");
      }
    } catch (e) {
      print("Error inside _generateDummyData: $e");
      if (mounted) {
        setState(() {
          _historyError = 'Lỗi tạo dữ liệu giả.';
          _historicalBills = [];
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        locale: const Locale('vi', 'VN'));

    if (picked != null && picked != _selectedDate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedDate = picked;
            _isLoadingHistory = true;
            _historicalBills = [];
            _historyError = null;
          });
        }
        _fetchHistoricalBills(picked);
      });
    }
  }

  // --- Build Method Chính ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kPagePadding = 18.0;

    return Scaffold(
      appBar: AppBar(
          // **THÊM LẠI LEADING ĐỂ MỞ DRAWER**
          leading: Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu_rounded, color: theme.iconTheme.color),
              tooltip: 'Mở menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          leadingWidth: 70,
          title:
              Text('Quản Lý Bán Hàng', style: theme.appBarTheme.titleTextStyle),
          actions: [
            IconButton(
                icon: Icon(Icons.notifications_none_outlined, size: 22),
                tooltip: 'Thông báo',
                onPressed: () {/* Handle notifications */}),
            Padding(
                padding: EdgeInsets.symmetric(horizontal: kPagePadding / 1.5)
                    .copyWith(right: kPagePadding),
                child: Row(children: [
                  CircleAvatar(
                      backgroundColor: Colors.grey.shade300,
                      child: Icon(Icons.person_outline,
                          color: Colors.grey.shade700, size: 20),
                      radius: 16),
                  SizedBox(width: 8),
                  if (MediaQuery.of(context).size.width > 600)
                    Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Thu Ngân 1',
                              style: theme.appBarTheme.titleTextStyle
                                  ?.copyWith(fontSize: 13)),
                          Text('ID: 12345',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(fontSize: 10.5))
                        ])
                ]))
          ]),
      drawer: Drawer(
          child: ListView(padding: EdgeInsets.zero, children: <Widget>[
        DrawerHeader(
            decoration: BoxDecoration(color: theme.colorScheme.secondary),
            child: Text('MENU QUẢN LÝ',
                style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSecondary, fontSize: 20))),
        ListTile(
            leading: Icon(Icons.schedule_rounded,
                color:
                    _currentViewIndex == 0 ? theme.colorScheme.secondary : null,
                size: 20),
            title: Text('Ca Trực Hiện Tại',
                style: TextStyle(
                    fontWeight: _currentViewIndex == 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14)),
            selected: _currentViewIndex == 0,
            selectedTileColor: theme.colorScheme.secondary.withOpacity(0.1),
            onTap: () {
              if (_currentViewIndex != 0) {
                setState(() => _currentViewIndex = 0);
              }
              Navigator.pop(context);
            }),
        ListTile(
            leading: Icon(Icons.history_rounded,
                color:
                    _currentViewIndex == 1 ? theme.colorScheme.secondary : null,
                size: 20),
            title: Text('Lịch Sử Bán Hàng',
                style: TextStyle(
                    fontWeight: _currentViewIndex == 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14)),
            selected: _currentViewIndex == 1,
            selectedTileColor: theme.colorScheme.secondary.withOpacity(0.1),
            onTap: () {
              if (_currentViewIndex != 1) {
                setState(() => _currentViewIndex = 1);
                if (_selectedDate == null) {
                  final today = DateTime.now();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _selectedDate = today;
                        _isLoadingHistory = true;
                        _historicalBills = [];
                        _historyError = null;
                      });
                    }
                    _fetchHistoricalBills(today);
                  });
                }
              }
              Navigator.pop(context);
            }),
        Divider(),
        ListTile(
            leading: Icon(Icons.dashboard_outlined, size: 20),
            title: Text('Dashboard', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
            }),
        ListTile(
            leading: Icon(Icons.settings_outlined, size: 20),
            title: Text('Cài đặt', style: TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
            })
      ])),
      body: Padding(
        padding: EdgeInsets.all(kPagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsGrid(context, theme),
            SizedBox(height: kPagePadding),
            Expanded(
              child: IndexedStack(
                index: _currentViewIndex,
                children: [
                  _buildCurrentShiftView(theme),
                  _buildHistoryView(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widget xây dựng View cho Ca Trực ---
  Widget _buildCurrentShiftView(ThemeData theme) {
    final headerBackgroundColor =
        theme.dataTableTheme.headingRowColor?.resolve({}) ??
            Colors.blue.shade100;
    final dividerColor = theme.dividerTheme.color ?? Colors.grey.shade300;
    final dividerThickness = theme.dividerTheme.thickness ?? 1.0;

    return Column(
      children: [
        _buildShiftSelector(theme, _tableCellHorizontalPadding * 2),
        SizedBox(height: _tableCellHorizontalPadding * 2),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Table Header ---
                // **THÊM LABEL 'PT THANH TOÁN'**
                _buildTableRow(
                  theme: theme,
                  height: _tableHeaderHeight,
                  isHeader: true,
                  backgroundColor: headerBackgroundColor,
                  cells: [
                    Text('MÃ HĐ'), // 0
                    Text('TRẠNG THÁI'), // 1
                    Text('TG THANH TOÁN'), // 2
                    Text('PT THANH TOÁN'), // 3 **(Mới)**
                    Text('TỔNG TIỀN'), // 4
                    Text('CHI TIẾT'), // 5
                  ],
                ),
                Divider(
                    height: dividerThickness,
                    thickness: dividerThickness,
                    color: dividerColor),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      if (_selectedShiftId != null &&
                          !_isLoadingShiftPayments) {
                        await _fetchPaymentsForShift(_selectedShiftId!);
                      }
                    },
                    color: theme.colorScheme.secondary,
                    backgroundColor: theme.cardTheme.color ?? Colors.white,
                    child: _buildShiftPaymentsContent(theme),
                  ),
                ),
                if (!_isLoadingShiftPayments &&
                    _paymentError == null &&
                    _shiftPayments.isNotEmpty) ...[
                  Divider(
                      height: dividerThickness,
                      thickness: dividerThickness,
                      color: dividerColor),
                  // **THÊM LABEL 'PT THANH TOÁN'**
                  _buildTableRow(
                    theme: theme,
                    height: _tableHeaderHeight,
                    isHeader: true,
                    backgroundColor: headerBackgroundColor,
                    cells: [
                      Text('MÃ HĐ'), // 0
                      Text('TRẠNG THÁI'), // 1
                      Text('TG THANH TOÁN'), // 2
                      Text('PT THANH TOÁN'), // 3 **(Mới)**
                      Text('TỔNG TIỀN'), // 4
                      Text('CHI TIẾT'), // 5
                    ],
                  ),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Helper to build content inside RefreshIndicator for Shift Payments ---
  Widget _buildShiftPaymentsContent(ThemeData theme) {
    final dividerColor = theme.dividerTheme.color ?? Colors.grey.shade300;
    final dividerThickness = theme.dividerTheme.thickness ?? 1.0;
    final Color oddRowColor = Colors.grey.shade200;

    // --- Handle Loading, Error, Empty States ---
    if (_isLoadingShiftPayments && _selectedShiftId != null) {
      if (_shiftPayments.isEmpty) {
        return Center(
            child:
                CircularProgressIndicator(color: theme.colorScheme.secondary));
      }
    }
    if (_paymentError != null && _selectedShiftId != null) {
      return Center(
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_paymentError!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center)),
      );
    }
    if (_isLoadingShifts && _shifts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_shiftError != null && _shifts.isEmpty) {
      return Center(
          child: Text(_shiftError!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center));
    }
    if (_selectedShiftId == null && !_isLoadingShifts) {
      return Center(
          child:
              Text("Vui lòng chọn một ca.", style: theme.textTheme.bodyMedium));
    }
    if (!_isLoadingShiftPayments &&
        _shiftPayments.isEmpty &&
        _paymentError == null &&
        _selectedShiftId != null) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text("Chưa có phiếu trong ca này.",
                      style: theme.textTheme.bodyMedium)),
            ),
          ),
        ),
      );
    }
    if (_isLoadingShiftPayments && _shiftPayments.isEmpty) {
      return const SizedBox.shrink();
    }

    // --- Display Data Rows ---
    // **SỬA LỖI: THÊM RETURN WIDGET CUỐI CÙNG**
    if (_shiftPayments.isNotEmpty && _paymentError == null) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _shiftPayments.length,
        separatorBuilder: (context, index) => Divider(
            height: dividerThickness,
            thickness: dividerThickness,
            color: dividerColor.withOpacity(0.6)),
        itemBuilder: (context, index) {
          final payment = _shiftPayments[index];
          final statusText = "Hoàn thành";
          // **THÊM DATA 'PT THANH TOÁN' VÀO LIST CELLS**
          return _buildTableRow(
            theme: theme,
            height: _tableRowHeight,
            backgroundColor: index % 2 != 0 ? oddRowColor : null,
            cells: [
              // 0: MÃ HĐ
              Text(payment.paymentId.toString(),
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.secondary)),
              // 1: TRẠNG THÁI
              _buildStatusChip(theme, statusText),
              // 2: TG THANH TOÁN
              Text(_fullDateTimeFormatter.format(payment.paymentTime),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              // 3: PT THANH TOÁN **(Mới)**
              Text(payment.paymentMethod,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              // 4: TỔNG TIỀN
              Text(_currencyFormatter.format(payment.amount)),
              // 5: CHI TIẾT
              OutlinedButton(
                onPressed: () {/* Handle view details */},
                style: theme.outlinedButtonTheme.style?.copyWith(
                    padding: MaterialStateProperty.all(
                        EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    textStyle: MaterialStateProperty.all(theme
                        .textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w500, fontSize: 11)),
                    minimumSize: MaterialStateProperty.all(Size(40, 26))),
                child: const Text('Xem'),
              ),
            ],
          );
        },
      );
    }
    // **THÊM RETURN CUỐI CÙNG ĐỂ FIX LỖI**
    return const SizedBox
        .shrink(); // Trả về widget trống nếu không có trường hợp nào khớp
  }

  // --- Widget xây dựng View cho Lịch Sử ---
  Widget _buildHistoryView(ThemeData theme) {
    final headerBackgroundColor =
        theme.dataTableTheme.headingRowColor?.resolve({}) ??
            Colors.blue.shade100;
    final dividerColor = theme.dividerTheme.color ?? Colors.grey.shade300;
    final dividerThickness = theme.dividerTheme.thickness ?? 1.0;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: _tableCellHorizontalPadding * 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedDate == null
                      ? 'Chọn ngày xem lịch sử:'
                      : _isLoadingHistory
                          ? 'Đang tải lịch sử ngày: ${_dateFormatter.format(_selectedDate!)}...'
                          : 'Lịch sử ngày: ${_dateFormatter.format(_selectedDate!)} (${_historicalBills.length} phiếu)',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: _tableCellHorizontalPadding * 2),
              ElevatedButton.icon(
                onPressed:
                    _isLoadingHistory ? null : () => _selectDate(context),
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Chọn Ngày'),
                style: theme.elevatedButtonTheme.style?.copyWith(
                  padding: MaterialStateProperty.all(
                      EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  textStyle: MaterialStateProperty.all(
                    theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Table Header ---
                // **THÊM LABEL 'PT THANH TOÁN'**
                _buildTableRow(
                  theme: theme,
                  height: _tableHeaderHeight,
                  isHeader: true,
                  backgroundColor: headerBackgroundColor,
                  cells: [
                    Text('MÃ HĐ'), // 0
                    Text('TRẠNG THÁI'), // 1
                    Text('TG THANH TOÁN'), // 2
                    Text('PT THANH TOÁN'), // 3 **(Mới)**
                    Text('TỔNG TIỀN'), // 4
                    Text('CHI TIẾT'), // 5
                  ],
                ),
                Divider(
                    height: dividerThickness,
                    thickness: dividerThickness,
                    color: dividerColor),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: (_selectedDate == null || _isLoadingHistory)
                        ? () async {}
                        : () => _fetchHistoricalBills(_selectedDate!),
                    color: theme.colorScheme.secondary,
                    backgroundColor: theme.cardTheme.color ?? Colors.white,
                    child: _buildHistoryBillsContent(theme),
                  ),
                ),
                if (!_isLoadingHistory &&
                    _historyError == null &&
                    _historicalBills.isNotEmpty) ...[
                  Divider(
                      height: dividerThickness,
                      thickness: dividerThickness,
                      color: dividerColor),
                  // **THÊM LABEL 'PT THANH TOÁN'**
                  _buildTableRow(
                    theme: theme,
                    height: _tableHeaderHeight,
                    isHeader: true,
                    backgroundColor: headerBackgroundColor,
                    cells: [
                      Text('MÃ HĐ'), // 0
                      Text('TRẠNG THÁI'), // 1
                      Text('TG THANH TOÁN'), // 2
                      Text('PT THANH TOÁN'), // 3 **(Mới)**
                      Text('TỔNG TIỀN'), // 4
                      Text('CHI TIẾT'), // 5
                    ],
                  ),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- **CHỈNH SỬA _buildHistoryBillsContent** ---
  Widget _buildHistoryBillsContent(ThemeData theme) {
    final dividerColor = theme.dividerTheme.color ?? Colors.grey.shade300;
    final dividerThickness = theme.dividerTheme.thickness ?? 1.0;
    final Color oddRowColor = Colors.grey.shade200;

    // --- Handle Loading, Error, Empty States ---
    if (_isLoadingHistory &&
        _historicalBills.isEmpty &&
        _historyError == null) {
      return Center(
          child: CircularProgressIndicator(color: theme.colorScheme.secondary));
    }
    if (_selectedDate == null && !_isLoadingHistory) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.date_range_outlined,
                      size: 40, color: theme.iconTheme.color?.withOpacity(0.4)),
                  SizedBox(height: _tableCellHorizontalPadding * 2),
                  Text('Vui lòng chọn ngày.', style: theme.textTheme.bodyMedium)
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_historyError != null) {
      return Center(
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_historyError!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center)),
      );
    }
    if (!_isLoadingHistory &&
        _historyError == null &&
        _historicalBills.isEmpty &&
        _selectedDate != null) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Không có phiếu cho ngày đã chọn.',
                      style: theme.textTheme.bodyMedium)),
            ),
          ),
        ),
      );
    }

    // --- Display Data Rows ---
    // Chỉ hiển thị ListView nếu có dữ liệu và không gặp lỗi
    if (_historicalBills.isNotEmpty && _historyError == null) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _historicalBills.length,
        separatorBuilder: (context, index) => Divider(
            height: dividerThickness,
            thickness: dividerThickness,
            color: dividerColor.withOpacity(0.6)),
        itemBuilder: (context, index) {
          final payment = _historicalBills[index];
          final statusText = "Hoàn thành";
          // **THÊM DATA 'PT THANH TOÁN' VÀO LIST CELLS**
          return _buildTableRow(
            theme: theme,
            height: _tableRowHeight,
            backgroundColor: index % 2 != 0 ? oddRowColor : null,
            cells: [
              // 0: MÃ HĐ
              Text(payment.paymentId.toString(),
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.secondary)),
              // 1: TRẠNG THÁI
              _buildStatusChip(theme, statusText),
              // 2: TG THANH TOÁN
              Text(_fullDateTimeFormatter.format(payment.paymentTime),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              // 3: PT THANH TOÁN **(Mới)**
              Text(payment.paymentMethod,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              // 4: TỔNG TIỀN
              Text(_currencyFormatter.format(payment.amount)),
              // 5: CHI TIẾT
              OutlinedButton(
                onPressed: () {/* Handle view details */},
                style: theme.outlinedButtonTheme.style?.copyWith(
                    padding: MaterialStateProperty.all(
                        EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    textStyle: MaterialStateProperty.all(theme
                        .textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w500, fontSize: 11)),
                    minimumSize: MaterialStateProperty.all(Size(40, 26))),
                child: const Text('Xem'),
              ),
            ],
          );
        },
      );
    }
    // **THÊM RETURN CUỐI CÙNG ĐỂ FIX LỖI**
    return const SizedBox
        .shrink(); // Trả về widget trống nếu không có trường hợp nào khớp
  }

  // --- Widget chọn ca ---
  Widget _buildShiftSelector(ThemeData theme, double horizontalPadding) {
    if (_isLoadingShifts && _shifts.isEmpty) {
      return Container(
          padding: EdgeInsets.symmetric(vertical: horizontalPadding / 1.5),
          height: 45,
          child: const Center(child: LinearProgressIndicator(minHeight: 2)));
    }
    if (_shiftError != null && _shifts.isEmpty) {
      return Container(
          padding: EdgeInsets.symmetric(
              vertical: horizontalPadding / 1.5, horizontal: horizontalPadding),
          height: 45,
          child: Center(
              child: Text(
            _shiftError!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            textAlign: TextAlign.center,
          )));
    }
    if (_shifts.isEmpty && !_isLoadingShifts) {
      return Container(
          padding: EdgeInsets.symmetric(vertical: horizontalPadding / 1.5),
          height: 45,
          child: Center(
              child: Text("Không có ca trực nào.",
                  style: theme.textTheme.bodySmall)));
    }

    return Container(
        padding: EdgeInsets.symmetric(vertical: horizontalPadding / 1.5),
        height: 45,
        child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _shifts.length,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final shift = _shifts[index];
              final bool isSelected = _selectedShiftId == shift.shiftId;
              final formatTime = _timeFormatter;

              return ChoiceChip(
                  label: Text(
                      'Ca ${formatTime.format(shift.startTime)} - ${formatTime.format(shift.endTime)}'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      _selectShift(shift.shiftId);
                    }
                  },
                  selectedColor: theme.colorScheme.secondary,
                  backgroundColor: theme.chipTheme.backgroundColor ??
                      theme.cardTheme.color?.withOpacity(0.7),
                  labelStyle: theme.chipTheme.labelStyle?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onSecondary
                          : theme.chipTheme.labelStyle?.color,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal),
                  avatar: Icon(Icons.access_time_filled_rounded,
                      size: 14,
                      color: isSelected
                          ? theme.colorScheme.onSecondary.withOpacity(0.8)
                          : theme.chipTheme.labelStyle?.color
                              ?.withOpacity(0.7)),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                  shape: theme.chipTheme.shape,
                  elevation: isSelected ? 1.5 : 0.5,
                  pressElevation: 2.5);
            }));
  }
} // End of _ManagementScreenState
