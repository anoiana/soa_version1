import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math; // Để tạo dữ liệu giả
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart'; // Import for firstWhereOrNull
import 'package:intl/intl.dart';

import 'openTable.dart'; // Để định dạng ngày và tiền tệ
// import 'package:data_table_2/data_table_2.dart'; // REMOVED DataTable2 - Still removed

// --- Constants ---
const double kCardElevation = 1.0;
const String BASE_API_URL =
    "https://soa-deploy.up.railway.app"; // Make sure this is correct

// Define fixed column widths ONLY
const double _colWidthId = 70.0;
const double _colWidthStatus = 140.0;
const double _colWidthDetails = 80.0;
// Flex factors cho các cột Expanded
const int _colFlexPaymentTime = 4; // TG Thanh Toán
const int _colFlexPaymentMethod = 3; // **PT THANH TOÁN (Mới)**
const int _colFlexAmount = 3; // Tổng Tiền

// --- Data Models ---
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
  final int? tableNumber; // This might be redundant if details API provides it
  final int? numberOfCustomersDirect;

  Payment(
      {required this.paymentId,
      required this.amount,
      required this.paymentTime,
      this.creationTime,
      required this.paymentMethod,
      this.tableSessionId,
      this.tableNumber,
      this.numberOfCustomersDirect});

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

    int? parseIntSafe(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
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
        tableNumber: parseIntSafe(json['table_number']), // Parse an toàn
        numberOfCustomersDirect: parseIntSafe(json['number_of_customers']));
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

// **Data Model for Payment Details**
class PaymentDetail {
  final int paymentId;
  final int? tableNumber;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? numberOfCustomers;
  final String buffetPackage;

  PaymentDetail({
    required this.paymentId,
    this.tableNumber,
    this.startTime,
    this.endTime,
    this.numberOfCustomers,
    required this.buffetPackage,
  });

  factory PaymentDetail.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(String? dtString) {
      if (dtString == null) return null;
      try {
        if (dtString.endsWith('Z')) {
          return DateTime.parse(dtString).toLocal();
        }
        return DateTime.tryParse(dtString)?.toLocal();
      } catch (e) {
        print("Error parsing detail date '$dtString': $e");
        return null;
      }
    }

    int? parseIntSafe(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value);
      }
      return null;
    }

    return PaymentDetail(
      paymentId: json['payment_id'] as int? ?? 0,
      tableNumber: parseIntSafe(json['table_number']),
      startTime: parseDt(json['start_time'] as String?),
      endTime: parseDt(json['end_time'] as String?),
      numberOfCustomers: parseIntSafe(json['number_of_customers']),
      buffetPackage: json['buffet_package'] as String? ?? "Không có",
    );
  }
}

// **NEW Data Model for Shift Customer Summary**
class ShiftCustomerSummary {
  final int shiftId;
  final int totalCustomers; // **Kiểu int (không nullable)**
  final int totalSessions; // **Kiểu int (không nullable)**

  ShiftCustomerSummary({
    required this.shiftId,
    required this.totalCustomers,
    required this.totalSessions,
  });

  factory ShiftCustomerSummary.fromJson(Map<String, dynamic> json) {
    int parseIntSafe(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0; // Mặc định là 0 nếu kiểu không hợp lệ
    }

    return ShiftCustomerSummary(
      shiftId: parseIntSafe(json['shift_id']), // Ép kiểu an toàn
      totalCustomers: parseIntSafe(json['total_customers']),
      totalSessions: parseIntSafe(json['total_sessions']),
    );
  }
}

// **NEW Data Model for Payment History Response**
class PaymentHistoryResponse {
  final int year;
  final int? month;
  final int? day;
  final double totalRevenue;
  final List<Payment> payments;

  PaymentHistoryResponse({
    required this.year,
    this.month,
    this.day,
    required this.totalRevenue,
    required this.payments,
  });

  factory PaymentHistoryResponse.fromJson(Map<String, dynamic> json) {
    var paymentList = json['payments'] as List? ?? [];
    List<Payment> parsedPayments = paymentList
        .map((p) => Payment.fromJson(p as Map<String, dynamic>))
        .where((p) =>
            p.paymentTime.year > 1970) // Vẫn kiểm tra payment time hợp lệ
        .toList();

    return PaymentHistoryResponse(
      year: json['year'] as int? ?? 0,
      month: json['month'] as int?, // Month có thể null
      day: json['day'] as int?, // Day có thể null
      totalRevenue: (json['total_revenue'] as num? ?? 0.0).toDouble(),
      payments: parsedPayments,
    );
  }
}

// --- Hàm main và MyApp ---
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
            labelMedium: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF495057)),
            labelSmall: TextStyle(
                color: Color(0xFF6C757D),
                fontSize: 11.5,
                fontWeight: FontWeight.w500),
          ),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 13))),
          textButtonTheme:
              TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Colors.blueAccent.shade700, padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10), textStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13))),
          appBarTheme: AppBarTheme(elevation: 0, backgroundColor: Colors.white, iconTheme: IconThemeData(color: Color(0xFF495057)), actionsIconTheme: IconThemeData(color: Color(0xFF495057)), titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF343A40), fontFamily: 'Poppins')),
          dividerTheme: DividerThemeData(
            color: Colors.grey.shade300,
            thickness: 1,
          ),
          dialogTheme: DialogTheme(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
            elevation: 4,
            titleTextStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF343A40),
                fontFamily: 'Poppins'),
            contentTextStyle: TextStyle(
                color: Color(0xFF495057),
                fontSize: 13.5,
                fontFamily: 'Poppins'),
          ),
          listTileTheme: ListTileThemeData(
            iconColor: Colors.blueGrey.shade400,
            minLeadingWidth: 30,
          ),
          datePickerTheme: DatePickerThemeData(headerBackgroundColor: Colors.blueAccent.shade700, headerForegroundColor: Colors.white, backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: kCardElevation)),
      debugShowCheckedModeBanner: false,
      home: ManagementScreen(role: "Quản lý"),
    );
  }
}

// --- Management Screen Widget ---
class ManagementScreen extends StatefulWidget {
  final String role;
  const ManagementScreen({Key? key, required this.role}) : super(key: key);
  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  // --- State Variables ---
  int _currentViewIndex = 0;

  // History State
  int? _selectedHistoryYear;
  int? _selectedHistoryMonth; // null = All months
  int? _selectedHistoryDay; // null = All days
  bool _isLoadingHistory = false;
  List<Payment> _historicalBills = [];
  String? _historyError;
  double _historyTotalRevenue = 0.0;

  // Shift State
  bool _isLoadingShifts = true;
  String? _shiftError;
  List<Shift> _shifts = [];
  int? _selectedShiftId;
  bool _isLoadingShiftPayments = false;
  String? _paymentError;
  List<Payment> _shiftPayments = [];
  double _selectedShiftTotalRevenue = 0.0;
  final Set<int> _fetchingDetailsForPaymentIds = {};
  int _selectedShiftTotalCustomers = 0;
  int _selectedShiftTotalSessions = 0;
  bool _isLoadingCustomerSummary = false;

  // Formatters
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  final DateFormat _timeFormatter = DateFormat('HH:mm');
  final DateFormat _fullDateTimeFormatter = DateFormat('HH:mm:ss dd/MM/yyyy');
  final DateFormat _dateTimeDetailFormatter = DateFormat('HH:mm dd/MM/yyyy');
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');

  // --- Constants for Table Layout ---
  final double _tableRowHeight = 50.0;
  final double _tableHeaderHeight = 40.0;
  final double _tableCellHorizontalPadding = 5.0;

  // List of years for dropdown
  final List<int> _years = List<int>.generate(
      DateTime.now().year - 2019, (i) => DateTime.now().year - i);

  @override
  void initState() {
    super.initState();
    _selectedHistoryYear = DateTime.now().year;
    _fetchShifts();
    _fetchPaymentHistory(); // Fetch history for the default year on init
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Helper to safely call setState only if the widget is still mounted
  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
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
      if (crossAxisCount == 1) childAspectRatio = 3.5;
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
                value: _isLoadingShiftPayments && _shiftPayments.isEmpty
                    ? '...'
                    : _shiftPayments.length.toString(),
                change: '',
                changeColor: Colors.transparent,
                comparisonText: 'Trong ca hiện tại'),
            _buildStatCard(
                theme: theme,
                icon: Icons.attach_money,
                iconColor: Colors.blue.shade600,
                title: 'Doanh thu (Ca)',
                value:
                    _isLoadingShiftPayments && _selectedShiftTotalRevenue == 0.0
                        ? '...'
                        : _currencyFormatter.format(_selectedShiftTotalRevenue),
                change: '',
                changeColor: Colors.transparent,
                comparisonText: 'Trong ca hiện tại'),
            _buildStatCard(
                theme: theme,
                icon: Icons.people_alt_outlined,
                iconColor: Colors.orange.shade700,
                title: 'Khách (Ước tính)',
                value: _isLoadingCustomerSummary
                    ? '...'
                    : _selectedShiftTotalCustomers.toString(),
                change: '',
                changeColor: Colors.transparent,
                comparisonText: 'Trong ca hiện tại'),
            _buildStatCard(
                theme: theme,
                icon: Icons.table_restaurant_outlined,
                iconColor: Colors.purple.shade600,
                title: 'Tổng số phiên (Ca)',
                value: _isLoadingCustomerSummary
                    ? '...'
                    : _selectedShiftTotalSessions.toString(),
                change: '',
                changeColor: Colors.transparent,
                comparisonText: 'Trong ca hiện tại'),
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
    setStateIfMounted(() {
      _isLoadingShifts = true;
      _shiftError = null;
      _shifts = [];
      _selectedShiftId = null;
      _shiftPayments = [];
      _selectedShiftTotalRevenue = 0.0;
      _paymentError = null;
      _selectedShiftTotalCustomers = 0;
      _selectedShiftTotalSessions = 0;
      _isLoadingCustomerSummary = false;
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

        setStateIfMounted(() {
          _shifts = fetchedShifts;
          _isLoadingShifts = false;
          _shiftError = null;
        });
        _autoSelectCurrentOrLatestShift();

        print("Fetched ${_shifts.length} valid shifts.");
      } else {
        setStateIfMounted(() {
          _shiftError = 'Lỗi tải ca (${response.statusCode})';
          _isLoadingShifts = false;
        });
        print("Error fetching shifts: ${response.statusCode}");
      }
    } catch (e) {
      print("Exception fetching shifts: $e");
      setStateIfMounted(() {
        _shiftError = 'Lỗi kết nối hoặc xử lý dữ liệu ca.';
        _isLoadingShifts = false;
      });
    }
  }

  void _autoSelectCurrentOrLatestShift() {
    if (_shifts.isEmpty) {
      print("No shifts available to auto-select.");
      if (_isLoadingShifts) setStateIfMounted(() => _isLoadingShifts = false);
      return;
    }
    final now = DateTime.now();
    Shift? currentShift = _shifts.firstWhereOrNull((shift) =>
        !now.isBefore(shift.startTime) && now.isBefore(shift.endTime));
    final shiftToSelect = currentShift ?? _shifts.last;

    if (_selectedShiftId != shiftToSelect.shiftId ||
        (_selectedShiftId == shiftToSelect.shiftId &&
            ((_shiftPayments.isEmpty &&
                    !_isLoadingShiftPayments &&
                    _paymentError == null) ||
                (!_isLoadingCustomerSummary &&
                    _selectedShiftTotalSessions == 0)))) {
      print("Auto-selecting or re-selecting shift: ${shiftToSelect.shiftId}");
      _selectShift(shiftToSelect.shiftId);
    } else {
      print(
          "Shift ${shiftToSelect.shiftId} already selected/current and has data or is loading.");
    }
  }

  void _selectShift(int shiftId) {
    if (_selectedShiftId == shiftId &&
        (_isLoadingShiftPayments || _isLoadingCustomerSummary)) {
      print("Shift $shiftId is already loading data. Selection ignored.");
      return;
    }

    print("Shift selected: $shiftId");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setStateIfMounted(() {
        _selectedShiftId = shiftId;
        _isLoadingShiftPayments = true;
        _isLoadingCustomerSummary = true;
        _shiftPayments = [];
        _selectedShiftTotalRevenue = 0.0;
        _paymentError = null;
        _selectedShiftTotalCustomers = 0;
        _selectedShiftTotalSessions = 0;
        _fetchingDetailsForPaymentIds.clear();
      });
      _fetchPaymentsForShift(shiftId);
      _fetchShiftCustomerSummary(shiftId);
    });
  }

  Future<void> _fetchPaymentsForShift(int shiftId) async {
    if (!mounted) return;

    if (_selectedShiftId == shiftId && !_isLoadingShiftPayments) {
      setStateIfMounted(() => _isLoadingShiftPayments = true);
    } else if (_selectedShiftId != shiftId) {
      print(
          "Fetch payments for shift $shiftId aborted, selection changed to $_selectedShiftId");
      return;
    }

    print("Fetching payments for shift: $shiftId");
    final url = Uri.parse('$BASE_API_URL/payment/shift/$shiftId');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (!mounted) return;

      if (_selectedShiftId == shiftId) {
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final summary = ShiftPaymentSummary.fromJson(data);
          summary.payments
              .sort((a, b) => b.paymentTime.compareTo(a.paymentTime));

          setStateIfMounted(() {
            _shiftPayments = summary.payments;
            _selectedShiftTotalRevenue = summary.totalRevenue;
            _paymentError = null;
            _isLoadingShiftPayments = false;
          });
          print(
              "Fetched ${summary.payments.length} payments for shift $shiftId. Total: ${summary.totalRevenue}.");
        } else {
          setStateIfMounted(() {
            _shiftPayments = [];
            _selectedShiftTotalRevenue = 0.0;
            _paymentError = response.statusCode == 404
                ? null
                : 'Lỗi tải phiếu (${response.statusCode})';
            _isLoadingShiftPayments = false;
          });
          print(
              "Error or Not Found fetching payments (${response.statusCode}) for shift $shiftId.");
        }
      } else {
        print(
            "Ignoring stale payment data for shift $shiftId, current selection is $_selectedShiftId");
      }
    } catch (e) {
      print("Exception fetching payments for shift $shiftId: $e");
      if (mounted && _selectedShiftId == shiftId) {
        setStateIfMounted(() {
          _paymentError = 'Lỗi kết nối hoặc xử lý dữ liệu phiếu.';
          _isLoadingShiftPayments = false;
          _shiftPayments = [];
          _selectedShiftTotalRevenue = 0.0;
        });
      }
    }
  }

  Future<void> _fetchShiftCustomerSummary(int shiftId) async {
    if (!mounted) return;

    if (_selectedShiftId == shiftId && !_isLoadingCustomerSummary) {
      setStateIfMounted(() => _isLoadingCustomerSummary = true);
    } else if (_selectedShiftId != shiftId) {
      print(
          "Fetch summary for shift $shiftId aborted, selection changed to $_selectedShiftId");
      return;
    }

    final url =
        Uri.parse('$BASE_API_URL/payment/shift/$shiftId/total-customers');
    print("Fetching customer summary for shift: $shiftId from $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (!mounted) return;

      if (_selectedShiftId == shiftId) {
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final summary = ShiftCustomerSummary.fromJson(data);
          setStateIfMounted(() {
            _selectedShiftTotalCustomers = summary.totalCustomers;
            _selectedShiftTotalSessions = summary.totalSessions;
            _isLoadingCustomerSummary = false;
          });
          print(
              "Fetched customer summary for shift $shiftId: Customers=${summary.totalCustomers}, Sessions=${summary.totalSessions}");
        } else {
          setStateIfMounted(() {
            _selectedShiftTotalCustomers = 0;
            _selectedShiftTotalSessions = 0;
            _isLoadingCustomerSummary = false;
          });
          print(
              "Error or Not Found fetching customer summary (${response.statusCode}) for shift $shiftId");
        }
      } else {
        print(
            "Ignoring stale customer summary data for shift $shiftId, current selection is $_selectedShiftId");
      }
    } catch (e) {
      print("Exception fetching customer summary for shift $shiftId: $e");
      if (mounted && _selectedShiftId == shiftId) {
        setStateIfMounted(() {
          _selectedShiftTotalCustomers = 0;
          _selectedShiftTotalSessions = 0;
          _isLoadingCustomerSummary = false;
        });
      }
    }
  }

  Future<PaymentDetail> _fetchPaymentDetails(int paymentId) async {
    final url = Uri.parse('$BASE_API_URL/payment/$paymentId/detail');
    print("Fetching payment details for ID: $paymentId from $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (!mounted) throw Exception("Component unmounted during fetch");

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print("Payment details fetched: $data");
        return PaymentDetail.fromJson(data);
      } else if (response.statusCode == 404) {
        print("Payment details not found (404) for ID: $paymentId");
        throw Exception('Không tìm thấy chi tiết (404)');
      } else {
        print(
            "Error fetching payment details (${response.statusCode}) for ID: $paymentId");
        throw Exception('Lỗi tải chi tiết (${response.statusCode})');
      }
    } catch (e) {
      print("Exception fetching payment details for ID $paymentId: $e");
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Lỗi kết nối');
    }
  }

  Future<void> _showPaymentDetailsDialog(
      BuildContext context, PaymentDetail details) async {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    Widget buildDetailTile(IconData icon, String label, String value) {
      return ListTile(
        leading: Icon(icon,
            size: 20,
            color: theme.listTileTheme.iconColor ?? Colors.blueGrey.shade400),
        title: Text(label,
            style:
                textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(value,
            style: textTheme.bodyMedium?.copyWith(
                color: textTheme.bodyMedium?.color?.withOpacity(0.9))),
        dense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 2, horizontal: 0),
      );
    }

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Chi tiết Hóa đơn #${details.paymentId}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              buildDetailTile(Icons.table_restaurant_outlined, 'Số bàn',
                  details.tableNumber?.toString() ?? 'N/A'),
              Divider(height: 10, thickness: 0.5),
              buildDetailTile(
                  Icons.access_time_filled_rounded,
                  'Giờ bắt đầu',
                  details.startTime != null
                      ? _dateTimeDetailFormatter.format(details.startTime!)
                      : 'N/A'),
              buildDetailTile(
                  Icons.access_time_rounded,
                  'Giờ kết thúc',
                  details.endTime != null
                      ? _dateTimeDetailFormatter.format(details.endTime!)
                      : 'N/A'),
              Divider(height: 10, thickness: 0.5),
              buildDetailTile(Icons.people_alt_outlined, 'Số khách',
                  details.numberOfCustomers?.toString() ?? 'N/A'),
              buildDetailTile(Icons.restaurant_menu_rounded, 'Gói buffet',
                  details.buffetPackage),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Đóng'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
          contentPadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0),
          titlePadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          shape: theme.dialogTheme.shape,
        );
      },
    );
  }

  // **CẬP NHẬT HÀM FETCH LỊCH SỬ**
  Future<void> _fetchPaymentHistory({int? year, int? month, int? day}) async {
    // Sử dụng giá trị từ state nếu không có tham số nào được truyền vào
    year ??= _selectedHistoryYear;
    month ??= _selectedHistoryMonth;
    day ??= _selectedHistoryDay;

    if (year == null) {
      setStateIfMounted(() {
        _historyError = "Vui lòng chọn Năm để lọc.";
        _isLoadingHistory = false;
        _historicalBills = [];
        _historyTotalRevenue = 0.0;
      });
      return;
    }

    setStateIfMounted(() {
      _isLoadingHistory = true;
      _historicalBills = [];
      _historyError = null;
      _historyTotalRevenue = 0.0;
    });

    final Map<String, String> queryParams = {'year': year.toString()};
    if (month != null) {
      queryParams['month'] = month.toString();
    }
    if (day != null && month != null) {
      queryParams['day'] = day.toString();
    }

    final url = Uri.parse('$BASE_API_URL/payment/history/')
        .replace(queryParameters: queryParams);
    print("Fetching payment history from: $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final historyResponse = PaymentHistoryResponse.fromJson(data);
        historyResponse.payments
            .sort((a, b) => b.paymentTime.compareTo(a.paymentTime));

        setStateIfMounted(() {
          _historicalBills = historyResponse.payments;
          _historyTotalRevenue = historyResponse.totalRevenue;
          _historyError = null;
          _isLoadingHistory = false;
        });
        print(
            "Fetched ${historyResponse.payments.length} historical payments. Total Revenue: ${historyResponse.totalRevenue}");
      } else if (response.statusCode == 404) {
        setStateIfMounted(() {
          _historicalBills = [];
          _historyTotalRevenue = 0.0;
          _historyError = null;
          _isLoadingHistory = false;
        });
        print("No payment history found for the selected period (404).");
      } else {
        setStateIfMounted(() {
          _historicalBills = [];
          _historyTotalRevenue = 0.0;
          _historyError = 'Lỗi tải lịch sử (${response.statusCode})';
          _isLoadingHistory = false;
        });
        print("Error fetching payment history (${response.statusCode}).");
      }
    } catch (e) {
      print("Exception fetching payment history: $e");
      setStateIfMounted(() {
        _historicalBills = [];
        _historyTotalRevenue = 0.0;
        _historyError = 'Lỗi kết nối hoặc xử lý lịch sử.';
        _isLoadingHistory = false;
      });
    }
  }

  // **Bỏ hàm _generateDummyData**

  // **Bỏ hàm _selectDateForHistory cũ dùng DatePicker**

  // --- Build Method Chính ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kPagePadding = 18.0;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: theme.iconTheme.color),
            tooltip: 'Mở menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        leadingWidth: 70,
        title: Text('Quản Lý Bán Hàng', style: theme.appBarTheme.titleTextStyle),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none_outlined, size: 22),
            tooltip: 'Thông báo',
            onPressed: () {/* Handle notifications */},
          ),
          // Nút thoát
          IconButton(
            icon: Icon(Icons.exit_to_app, color: theme.iconTheme.color),
            tooltip: 'Thoát',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => TableSelectionScreen(
                    role: widget.role,
                  ),
                ),
              ); // Quay lại trang trước
            },
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: kPagePadding / 1.5)
                .copyWith(right: kPagePadding),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey.shade300,
                  child: Icon(Icons.person_outline,
                      color: Colors.grey.shade700, size: 20),
                  radius: 16,
                ),
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
                              ?.copyWith(fontSize: 10.5)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(color: theme.colorScheme.secondary),
              child: Text(
                'MENU QUẢN LÝ',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSecondary,
                  fontSize: 20,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.schedule_rounded,
                color: _currentViewIndex == 0 ? theme.colorScheme.secondary : null,
                size: 20,
              ),
              title: Text(
                'Ca Trực Hiện Tại',
                style: TextStyle(
                  fontWeight:
                  _currentViewIndex == 0 ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              selected: _currentViewIndex == 0,
              selectedTileColor: theme.colorScheme.secondary.withOpacity(0.1),
              onTap: () {
                if (_currentViewIndex != 0) {
                  setState(() => _currentViewIndex = 0);
                }
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.history_rounded,
                color: _currentViewIndex == 1 ? theme.colorScheme.secondary : null,
                size: 20,
              ),
              title: Text(
                'Lịch Sử Bán Hàng',
                style: TextStyle(
                  fontWeight:
                  _currentViewIndex == 1 ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              selected: _currentViewIndex == 1,
              selectedTileColor: theme.colorScheme.secondary.withOpacity(0.1),
              onTap: () {
                if (_currentViewIndex != 1) {
                  setState(() => _currentViewIndex = 1);
                }
                Navigator.pop(context);
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.dashboard_outlined, size: 20),
              title: Text('Dashboard', style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, size: 20),
              title: Text('Cài đặt', style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
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
                _buildTableRow(
                  theme: theme,
                  height: _tableHeaderHeight,
                  isHeader: true,
                  backgroundColor: headerBackgroundColor,
                  cells: [
                    Text('MÃ HĐ'), // 0
                    Text('TRẠNG THÁI'), // 1
                    Text('TG THANH TOÁN'), // 2
                    Text('PT THANH TOÁN'), // 3
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
                          !_isLoadingShiftPayments &&
                          !_isLoadingCustomerSummary) {
                        await Future.wait([
                          _fetchPaymentsForShift(_selectedShiftId!),
                          _fetchShiftCustomerSummary(_selectedShiftId!),
                        ]);
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
                  _buildTableRow(
                    theme: theme,
                    height: _tableHeaderHeight,
                    isHeader: true,
                    backgroundColor: headerBackgroundColor,
                    cells: [
                      Text('MÃ HĐ'), // 0
                      Text('TRẠNG THÁI'), // 1
                      Text('TG THANH TOÁN'), // 2
                      Text('PT THANH TOÁN'), // 3
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
    if ((_isLoadingShiftPayments || _isLoadingCustomerSummary) &&
        _selectedShiftId != null) {
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
        !_isLoadingCustomerSummary &&
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

    // --- Display Data Rows ---
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
          final bool isLoadingDetails =
              _fetchingDetailsForPaymentIds.contains(payment.paymentId);

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
              // 3: PT THANH TOÁN
              Text(payment.paymentMethod,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              // 4: TỔNG TIỀN
              Text(_currencyFormatter.format(payment.amount)),
              // 5: CHI TIẾT
              OutlinedButton(
                onPressed: isLoadingDetails
                    ? null
                    : () async {
                        if (!mounted) return;
                        setStateIfMounted(() => _fetchingDetailsForPaymentIds
                            .add(payment.paymentId));

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.onPrimary)),
                                SizedBox(width: 15),
                                Text('Đang tải chi tiết...',
                                    style: TextStyle(
                                        color: theme.colorScheme.onPrimary)),
                              ],
                            ),
                            duration: Duration(seconds: 30),
                            backgroundColor:
                                theme.colorScheme.secondary.withOpacity(0.9),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        );

                        try {
                          final details =
                              await _fetchPaymentDetails(payment.paymentId);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          _showPaymentDetailsDialog(context, details);
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lỗi: ${e.toString()}'),
                              backgroundColor: theme.colorScheme.error,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          );
                        } finally {
                          setStateIfMounted(() => _fetchingDetailsForPaymentIds
                              .remove(payment.paymentId));
                        }
                      },
                style: theme.outlinedButtonTheme.style?.copyWith(
                    padding: MaterialStateProperty.all(
                        EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    textStyle: MaterialStateProperty.all(theme
                        .textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w500, fontSize: 11)),
                    minimumSize: MaterialStateProperty.all(Size(40, 26))),
                child: isLoadingDetails
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: theme.colorScheme.primary))
                    : const Text('Xem'),
              ),
            ],
          );
        },
      );
    }
    return const SizedBox.shrink();
  }

  // --- Widget xây dựng View cho Lịch Sử ---
  Widget _buildHistoryView(ThemeData theme) {
    final headerBackgroundColor =
        theme.dataTableTheme.headingRowColor?.resolve({}) ??
            Colors.blue.shade100;
    final dividerColor = theme.dividerTheme.color ?? Colors.grey.shade300;
    final dividerThickness = theme.dividerTheme.thickness ?? 1.0;
    final kFilterSpacing = 10.0;

    // Tạo danh sách tháng (1-12 và "Tất cả")
    final List<DropdownMenuItem<int?>> monthItems = [
      const DropdownMenuItem<int?>(value: null, child: Text("Tất cả tháng")),
      ...List.generate(
          12,
          (i) => DropdownMenuItem<int?>(
              value: i + 1, child: Text("Tháng ${i + 1}"))),
    ];

    // Tạo danh sách ngày (1-31 và "Tất cả" - chỉ hiển thị nếu tháng được chọn)
    List<DropdownMenuItem<int?>> dayItems = [
      const DropdownMenuItem<int?>(value: null, child: Text("Tất cả ngày")),
    ];
    if (_selectedHistoryMonth != null && _selectedHistoryYear != null) {
      try {
        final daysInMonth = DateUtils.getDaysInMonth(
            _selectedHistoryYear!, _selectedHistoryMonth!);
        dayItems.addAll(List.generate(
            daysInMonth,
            (i) => DropdownMenuItem<int?>(
                value: i + 1, child: Text("Ngày ${i + 1}"))));
      } catch (e) {
        print("Lỗi tính ngày trong tháng: $e");
      }
    }

    return Column(
      children: [
        // **BỘ LỌC MỚI**
        Padding(
          padding: EdgeInsets.only(bottom: _tableCellHorizontalPadding * 2),
          child: Wrap(
            // Dùng Wrap để tự xuống dòng nếu không đủ chỗ
            spacing: kFilterSpacing,
            runSpacing: kFilterSpacing,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween, // Căn đều các item filter
            children: [
              // Phần Text mô tả bộ lọc
              Text(
                _isLoadingHistory
                    ? 'Đang tải lịch sử...'
                    : 'Lịch sử (${_buildFilterDescription()}): ${_historicalBills.length} phiếu - ${_currencyFormatter.format(_historyTotalRevenue)}',
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
              ),

              // Phần các Dropdown và nút Lọc
              Row(
                // Gom các dropdown và nút lọc lại
                mainAxisSize: MainAxisSize.min, // Thu gọn Row
                children: [
                  // Dropdown Năm
                  _buildHistoryFilterDropdown<int>(
                    theme: theme,
                    value: _selectedHistoryYear ??
                        _years.first, // Cung cấp giá trị mặc định
                    items: _years
                        .map((year) => DropdownMenuItem<int>(
                            value: year, child: Text(year.toString())))
                        .toList(),
                    onChanged: (int? newValue) {
                      if (newValue != null &&
                          newValue != _selectedHistoryYear) {
                        setState(() {
                          _selectedHistoryYear = newValue;
                          _selectedHistoryMonth = null;
                          _selectedHistoryDay = null;
                        });
                        // Có thể fetch ngay nếu chỉ muốn lọc theo năm
                        // _fetchPaymentHistory();
                      }
                    },
                  ),
                  SizedBox(width: kFilterSpacing),

                  // Dropdown Tháng
                  _buildHistoryFilterDropdown<int?>(
                    theme: theme,
                    value: _selectedHistoryMonth,
                    items: monthItems,
                    onChanged: (int? newValue) {
                      if (newValue != _selectedHistoryMonth) {
                        setState(() {
                          _selectedHistoryMonth = newValue;
                          _selectedHistoryDay = null;
                        });
                      }
                    },
                  ),
                  SizedBox(width: kFilterSpacing),

                  // Dropdown Ngày
                  IgnorePointer(
                    ignoring: _selectedHistoryMonth == null,
                    child: Opacity(
                      opacity: _selectedHistoryMonth == null ? 0.5 : 1.0,
                      child: _buildHistoryFilterDropdown<int?>(
                        theme: theme,
                        value: _selectedHistoryDay,
                        items: dayItems,
                        onChanged: _selectedHistoryMonth == null
                            ? null
                            : (int? newValue) {
                                if (newValue != _selectedHistoryDay) {
                                  setState(() {
                                    _selectedHistoryDay = newValue;
                                  });
                                }
                              },
                      ),
                    ),
                  ),
                  SizedBox(width: kFilterSpacing),

                  // Nút Lọc
                  ElevatedButton.icon(
                    icon: Icon(Icons.filter_list, size: 16),
                    label: Text('Lọc'),
                    onPressed: _isLoadingHistory
                        ? null
                        : () =>
                            _fetchPaymentHistory(), // Gọi fetch khi nhấn nút
                    style: theme.elevatedButtonTheme.style?.copyWith(
                      padding: MaterialStateProperty.all(
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      textStyle: MaterialStateProperty.all(
                          theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Phần Bảng dữ liệu
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTableRow(
                  theme: theme,
                  height: _tableHeaderHeight,
                  isHeader: true,
                  backgroundColor: headerBackgroundColor,
                  cells: [
                    Text('MÃ HĐ'), // 0
                    Text('TRẠNG THÁI'), // 1
                    Text('TG THANH TOÁN'), // 2
                    Text('PT THANH TOÁN'), // 3
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
                    onRefresh: (_selectedHistoryYear == null ||
                            _isLoadingHistory) // Dùng _selectedHistoryYear để kiểm tra
                        ? () async {}
                        : () =>
                            _fetchPaymentHistory(), // Fetch theo bộ lọc hiện tại
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
                  _buildTableRow(
                    theme: theme,
                    height: _tableHeaderHeight,
                    isHeader: true,
                    backgroundColor: headerBackgroundColor,
                    cells: [
                      Text('MÃ HĐ'), // 0
                      Text('TRẠNG THÁI'), // 1
                      Text('TG THANH TOÁN'), // 2
                      Text('PT THANH TOÁN'), // 3
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

  // **Hàm helper để tạo Dropdown cho bộ lọc**
  Widget _buildHistoryFilterDropdown<T>({
    required ThemeData theme,
    required T value,
    required List<DropdownMenuItem<T>> items,
    // **SỬA KIỂU Ở ĐÂY:** Dùng ValueChanged<T?>?
    required ValueChanged<T?>? onChanged,
  }) {
    return Container(
      height: 38,
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          color: theme.inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
                  theme.inputDecorationTheme.enabledBorder?.borderSide.color ??
                      Colors.grey)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: _isLoadingHistory ? null : onChanged,
          style: theme.textTheme.bodyMedium,
          icon: Icon(Icons.arrow_drop_down,
              size: 20, color: _isLoadingHistory ? Colors.grey : null),
          isExpanded: false,
          focusColor: Colors.transparent,
          // menuMaxHeight: 300, // Có thể giới hạn chiều cao menu nếu cần
        ),
      ),
    );
  }

  // **Hàm helper để tạo mô tả bộ lọc hiện tại**
  String _buildFilterDescription() {
    if (_selectedHistoryYear == null) return "Chưa chọn";
    String desc = _selectedHistoryYear.toString();
    if (_selectedHistoryMonth != null) {
      desc += "/${_selectedHistoryMonth.toString().padLeft(2, '0')}";
      if (_selectedHistoryDay != null) {
        desc += "/${_selectedHistoryDay.toString().padLeft(2, '0')}";
      } else {
        desc += "/Tất cả ngày";
      }
    } else {
      desc += "/Tất cả"; // Ngắn gọn hơn khi chỉ chọn năm
    }
    return desc;
  }

  // --- Helper to build content inside RefreshIndicator for History Bills ---
  Widget _buildHistoryBillsContent(ThemeData theme) {
    final dividerColor = theme.dividerTheme.color ?? Colors.grey.shade300;
    final dividerThickness = theme.dividerTheme.thickness ?? 1.0;
    final Color oddRowColor = Colors.grey.shade200;

    // --- Handle Loading, Error, Empty States ---
    if (_isLoadingHistory && _historicalBills.isEmpty) {
      return Center(
          child: CircularProgressIndicator(color: theme.colorScheme.secondary));
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
        _historicalBills.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Không có phiếu cho khoảng thời gian đã chọn.',
                      style: theme.textTheme.bodyMedium)),
            ),
          ),
        ),
      );
    }

    // --- Display Data Rows ---
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
          final bool isLoadingDetails =
              _fetchingDetailsForPaymentIds.contains(payment.paymentId);

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
              // 3: PT THANH TOÁN
              Text(payment.paymentMethod,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              // 4: TỔNG TIỀN
              Text(_currencyFormatter.format(payment.amount)),
              // 5: CHI TIẾT
              OutlinedButton(
                onPressed: isLoadingDetails
                    ? null
                    : () async {
                        if (!mounted) return;
                        setStateIfMounted(() => _fetchingDetailsForPaymentIds
                            .add(payment.paymentId));

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.onPrimary)),
                                SizedBox(width: 15),
                                Text('Đang tải chi tiết...',
                                    style: TextStyle(
                                        color: theme.colorScheme.onPrimary)),
                              ],
                            ),
                            duration: Duration(seconds: 30),
                            backgroundColor:
                                theme.colorScheme.secondary.withOpacity(0.9),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        );

                        try {
                          final details =
                              await _fetchPaymentDetails(payment.paymentId);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          _showPaymentDetailsDialog(context, details);
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lỗi: ${e.toString()}'),
                              backgroundColor: theme.colorScheme.error,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          );
                        } finally {
                          setStateIfMounted(() => _fetchingDetailsForPaymentIds
                              .remove(payment.paymentId));
                        }
                      },
                style: theme.outlinedButtonTheme.style?.copyWith(
                    padding: MaterialStateProperty.all(
                        EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    textStyle: MaterialStateProperty.all(theme
                        .textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w500, fontSize: 11)),
                    minimumSize: MaterialStateProperty.all(Size(40, 26))),
                child: isLoadingDetails
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: theme.colorScheme.primary))
                    : const Text('Xem'),
              ),
            ],
          );
        },
      );
    }
    // Nếu không rơi vào các trường hợp trên (vd: đang load shift ban đầu)
    return const SizedBox.shrink();
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
