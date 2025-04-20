import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math; // Để tạo dữ liệu giả
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart'; // Import for firstWhereOrNull
import 'package:intl/intl.dart'; // Để định dạng ngày và tiền tệ
import 'package:intl/date_symbol_data_local.dart'; // **IMPORT NÀY QUAN TRỌNG**

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
  final DateTime? creationTime;
  final String paymentMethod;
  final int? tableSessionId;
  final int? tableNumber;
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
    final creationTime =
        parseDt(json['created_time'] as String?) ?? paymentTime;

    return Payment(
        paymentId: id,
        amount: (json['amount'] as num? ?? 0).toDouble(),
        paymentTime: paymentTime,
        creationTime: creationTime,
        paymentMethod: json['payment_method'] as String? ?? 'Tiền mặt',
        tableSessionId: json['table_session_id'] as int?,
        tableNumber: parseIntSafe(json['table_number']),
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

class ShiftCustomerSummary {
  final int shiftId;
  final int totalCustomers;
  final int totalSessions;

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
      return 0;
    }

    return ShiftCustomerSummary(
      shiftId: parseIntSafe(json['shift_id']),
      totalCustomers: parseIntSafe(json['total_customers']),
      totalSessions: parseIntSafe(json['total_sessions']),
    );
  }
}

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
        .where((p) => p.paymentTime.year > 1970)
        .toList();

    return PaymentHistoryResponse(
      year: json['year'] as int? ?? 0,
      month: json['month'] as int?,
      day: json['day'] as int?,
      totalRevenue: (json['total_revenue'] as num? ?? 0.0).toDouble(),
      payments: parsedPayments,
    );
  }
}

class HistoryCustomerSummary {
  final int year;
  final int? month;
  final int? day;
  final int totalCustomers;
  final int totalSessions;

  HistoryCustomerSummary({
    required this.year,
    this.month,
    this.day,
    required this.totalCustomers,
    required this.totalSessions,
  });

  factory HistoryCustomerSummary.fromJson(Map<String, dynamic> json) {
    int parseIntSafe(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return HistoryCustomerSummary(
      year: parseIntSafe(json['year']),
      month: json['month'] as int?,
      day: json['day'] as int?,
      totalCustomers: parseIntSafe(json['total_customers']),
      totalSessions: parseIntSafe(json['total_sessions']),
    );
  }
}

// --- Hàm main và MyApp ---
// void main() {
//   // **TRẢ LẠI HÀM MAIN GỐC**
//   runApp(MyApp());
// }

class MyApp extends StatelessWidget {
  // **SỬ DỤNG FUTUREBUILDER ĐỂ KHỞI TẠO LOCALE**
  final Future<void> _localeInitialization = _initializeLocale();

  // Hàm khởi tạo locale riêng
  static Future<void> _initializeLocale() async {
    try {
      print("Initializing locale...");
      // Đảm bảo Flutter binding sẵn sàng trước khi gọi initializeDateFormatting
      // WidgetsFlutterBinding.ensureInitialized(); // Không cần gọi ở đây nữa nếu main không async
      await initializeDateFormatting('vi_VN', null);
      print("Locale initialized successfully.");
    } catch (e) {
      print("Error initializing locale in MyApp: $e");
      // Có thể ném lại lỗi để FutureBuilder bắt được
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _localeInitialization,
      builder: (context, snapshot) {
        // Kiểm tra trạng thái Future
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Đang chờ khởi tạo locale
          return MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            debugShowCheckedModeBanner: false,
          );
        } else if (snapshot.hasError) {
          // Có lỗi xảy ra
          return MaterialApp(
            home: Scaffold(
              body: Center(
                  child: Text('Lỗi khởi tạo ngôn ngữ: ${snapshot.error}')),
            ),
            debugShowCheckedModeBanner: false,
          );
        } else {
          // Khởi tạo locale thành công, build MaterialApp chính
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
                    headingRowColor:
                        MaterialStateProperty.all(Colors.blue.shade100),
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
                  bodyMedium:
                      TextStyle(color: Color(0xFF495057), fontSize: 12.5),
                  bodySmall:
                      TextStyle(color: Color(0xFF6C757D), fontSize: 10.5),
                  labelMedium: TextStyle(
                      // Slightly bigger label for dialog
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF495057)),
                  labelSmall: TextStyle(
                      // Keep for other uses if needed
                      color: Color(0xFF6C757D),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500),
                ),
                inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: Color(0xFFF1F3F5),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 0, horizontal: 12),
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
                    hintStyle:
                        TextStyle(color: Color(0xFFADB5BD), fontSize: 13)),
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
                        padding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        textStyle: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 13))),
                outlinedButtonTheme: OutlinedButtonThemeData(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent.shade700,
                        side: BorderSide(color: Colors.blueAccent.shade700.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        textStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13))),
                textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Colors.blueAccent.shade700, padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10), textStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13))),
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
            home: ManagementScreen(), // Widget chính của bạn
          );
        }
      },
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
  // --- State Variables ---
  int _currentViewIndex = 0;

  // History State
  int? _selectedHistoryYear;
  int? _selectedHistoryMonth;
  int? _selectedHistoryDay;
  bool _isLoadingHistory = false;
  List<Payment> _historicalBills = [];
  String? _historyError;
  double _historyTotalRevenue = 0.0;
  int _historyTotalBills = 0;
  int _historyTotalCustomers = 0;
  int _historyTotalSessions = 0;
  String? _historySummaryError;
  double _prevHistoryTotalRevenue = 0.0;
  int _prevHistoryTotalBills = 0;
  int _prevHistoryTotalCustomers = 0;
  int _prevHistoryTotalSessions = 0;
  bool _isLoadingPrevHistory = false;

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
  final NumberFormat _percentFormatter = NumberFormat("##0.#%", "vi_VN");
  final DateFormat _timeFormatter = DateFormat('HH:mm');
  final DateFormat _fullDateTimeFormatter = DateFormat('HH:mm:ss dd/MM/yyyy');
  final DateFormat _dateTimeDetailFormatter = DateFormat('HH:mm dd/MM/yyyy');
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  final DateFormat _monthYearFormatter = DateFormat('MM/yyyy', 'vi_VN');
  final DateFormat _yearFormatter = DateFormat('yyyy', 'vi_VN');

  // --- Constants for Table Layout ---
  final double _tableRowHeight = 50.0;
  final double _tableHeaderHeight = 40.0;
  final double _tableCellHorizontalPadding = 5.0;

  final List<int> _years = List<int>.generate(
      DateTime.now().year - 2019, (i) => DateTime.now().year - i);

  @override
  void initState() {
    super.initState();
    _selectedHistoryYear = DateTime.now().year;
    // **KHÔNG GỌI KHỞI TẠO LOCALE Ở ĐÂY NỮA**
    _fetchShifts();
    _triggerHistoryFetch();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  // --- Helper Methods ---

  Widget _buildStatsGrid(BuildContext context, ThemeData theme) {
    final kDefaultPadding = 12.0;
    final bool isHistoryView = _currentViewIndex == 1;

    String totalBills = isHistoryView
        ? (_isLoadingHistory ? '...' : _historyTotalBills.toString())
        : (_isLoadingShiftPayments && _shiftPayments.isEmpty
            ? '...'
            : _shiftPayments.length.toString());
    String totalRevenue = isHistoryView
        ? (_isLoadingHistory
            ? '...'
            : _currencyFormatter.format(_historyTotalRevenue))
        : (_isLoadingShiftPayments && _selectedShiftTotalRevenue == 0.0
            ? '...'
            : _currencyFormatter.format(_selectedShiftTotalRevenue));
    String displayCustomers = isHistoryView
        ? (_isLoadingHistory ? '...' : _historyTotalCustomers.toString())
        : (_isLoadingCustomerSummary
            ? '...'
            : _selectedShiftTotalCustomers.toString());
    String displaySessions = isHistoryView
        ? (_isLoadingHistory ? '...' : _historyTotalSessions.toString())
        : (_isLoadingCustomerSummary
            ? '...'
            : _selectedShiftTotalSessions.toString());
    String historyComparisonPeriodText = '';
    String historyRevenueChange = '';
    String historyBillsChange = '';
    String historyCustomersChange = '';
    String historySessionsChange = '';

    if (isHistoryView &&
        !_isLoadingHistory &&
        !_isLoadingPrevHistory &&
        _historyError == null) {
      final comparisonData = _getComparisonPeriodTextAndCalculateChanges();
      historyComparisonPeriodText = comparisonData['text'] ?? '';
      historyRevenueChange = comparisonData['revenueChange'] ?? '';
      historyBillsChange = comparisonData['billsChange'] ?? '';
      historyCustomersChange = comparisonData['customersChange'] ?? '';
      historySessionsChange = comparisonData['sessionsChange'] ?? '';
    } else if (isHistoryView && (_isLoadingHistory || _isLoadingPrevHistory)) {
      historyComparisonPeriodText = 'Đang tải so sánh...';
    }

    final String displayComparisonText =
        isHistoryView ? historyComparisonPeriodText : 'Trong ca hiện tại';
    final String displayRevenueChange =
        isHistoryView ? historyRevenueChange : '';
    final String displayBillsChange = isHistoryView ? historyBillsChange : '';
    final String displayCustomersChange =
        isHistoryView ? historyCustomersChange : '';
    final String displaySessionsChange =
        isHistoryView ? historySessionsChange : '';
    final String billsTitle = isHistoryView ? 'Tổng phiếu' : 'Tổng phiếu (Ca)';
    final String revenueTitle = isHistoryView ? 'Doanh thu' : 'Doanh thu (Ca)';
    final String customersTitle = isHistoryView ? 'Khách' : 'Khách (Ca)';
    final String sessionsTitle =
        isHistoryView ? 'Tổng số phiên' : 'Tổng số phiên (Ca)';

    return LayoutBuilder(builder: (context, constraints) {
      int crossAxisCount = 4;
      if (constraints.maxWidth < 1200) crossAxisCount = 4;
      if (constraints.maxWidth < 900) crossAxisCount = 2;
      if (constraints.maxWidth < 500) crossAxisCount = 1;
      double childAspectRatio = isHistoryView ? 2.2 : 2.4;
      if (crossAxisCount == 2) childAspectRatio = isHistoryView ? 2.6 : 2.8;
      if (crossAxisCount == 1) childAspectRatio = isHistoryView ? 3.2 : 3.5;
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
                title: billsTitle,
                value: totalBills,
                change: displayBillsChange,
                changeColor: _getChangeColor(displayBillsChange),
                comparisonText: displayComparisonText),
            _buildStatCard(
                theme: theme,
                icon: Icons.attach_money,
                iconColor: Colors.blue.shade600,
                title: revenueTitle,
                value: totalRevenue,
                change: displayRevenueChange,
                changeColor: _getChangeColor(displayRevenueChange),
                comparisonText: displayComparisonText),
            _buildStatCard(
                theme: theme,
                icon: Icons.people_alt_outlined,
                iconColor: Colors.orange.shade700,
                title: customersTitle,
                value: displayCustomers,
                change: displayCustomersChange,
                changeColor: _getChangeColor(displayCustomersChange),
                comparisonText: displayComparisonText),
            _buildStatCard(
                theme: theme,
                icon: Icons.table_restaurant_outlined,
                iconColor: Colors.purple.shade600,
                title: sessionsTitle,
                value: displaySessions,
                change: displaySessionsChange,
                changeColor: _getChangeColor(displaySessionsChange),
                comparisonText: displayComparisonText),
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
    final textTheme = theme.textTheme;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: textTheme.labelSmall?.copyWith(
                                color: textTheme.labelSmall?.color
                                    ?.withOpacity(0.9),
                                fontWeight: FontWeight.w600)),
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Icon(icon,
                              size: 18, color: iconColor.withOpacity(0.8)),
                        )
                      ]),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(value,
                              style: textTheme.titleLarge?.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textTheme.titleLarge?.color)),
                          if (change.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                    change.startsWith('+') ||
                                            change.startsWith('↑')
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 12,
                                    color: changeColor),
                                SizedBox(width: 3),
                                Text(change,
                                    style: textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: changeColor,
                                        fontSize: 11.5)),
                              ],
                            ),
                          if (change.isEmpty && comparisonText.isNotEmpty)
                            const SizedBox(height: 15),
                        ],
                      ),
                      if (comparisonText.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              comparisonText,
                              style: textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      if (comparisonText.isEmpty)
                        SizedBox(
                            height:
                                textTheme.bodySmall?.fontSize ?? 10.5 + 2.0),
                    ],
                  ),
                ])));
  }

  Color _getChangeColor(String change) {
    if (change.startsWith('+') || change.startsWith('↑')) {
      return Colors.green.shade700;
    } else if (change.startsWith('-') || change.startsWith('↓')) {
      return Colors.red.shade700;
    }
    return Colors.grey.shade600;
  }

  String _calculatePercentChange(num currentValue, num previousValue) {
    if (previousValue == 0) {
      if (currentValue > 0) return '↑ Mới';
      return '';
    }
    if (currentValue == previousValue) {
      return '0%';
    }
    double change = (currentValue.toDouble() - previousValue.toDouble()) /
        previousValue.abs();
    String prefix = change > 0 ? '+' : '';
    NumberFormat formatter = NumberFormat("##0.#%", "vi_VN");
    return prefix + formatter.format(change); // Return with sign
  }

  Map<String, String> _getComparisonPeriodTextAndCalculateChanges() {
    String text = '';
    int? prevYear = _selectedHistoryYear;
    int? prevMonth = _selectedHistoryMonth;
    int? prevDay = _selectedHistoryDay;
    bool canCompare = false;
    DateTime? previousPeriodDate;

    if (prevDay != null && prevMonth != null && prevYear != null) {
      try {
        final current = DateTime(prevYear, prevMonth, prevDay);
        previousPeriodDate = current.subtract(const Duration(days: 1));
        text = 'so với ${_dateFormatter.format(previousPeriodDate)}';
        canCompare = true;
      } catch (e) {
        prevYear = null;
      }
    } else if (prevMonth != null && prevYear != null) {
      try {
        final current = DateTime(prevYear, prevMonth);
        previousPeriodDate = DateTime(current.year, current.month - 1);
        text =
            'so với T${_monthYearFormatter.format(previousPeriodDate).split('/')[0]}';
        canCompare = true;
      } catch (e) {
        prevYear = null;
      }
    } else if (prevYear != null) {
      try {
        previousPeriodDate = DateTime(prevYear - 1);
        text = 'so với ${_yearFormatter.format(previousPeriodDate)}';
        canCompare = true;
      } catch (e) {
        prevYear = null;
      }
    } else {
      text = '';
      canCompare = false;
    }

    String revenueChange = '';
    String billsChange = '';
    String customersChange = '';
    String sessionsChange = '';

    if (canCompare && !_isLoadingPrevHistory) {
      revenueChange = _calculatePercentChange(
          _historyTotalRevenue, _prevHistoryTotalRevenue);
      billsChange =
          _calculatePercentChange(_historyTotalBills, _prevHistoryTotalBills);
      customersChange = _calculatePercentChange(
          _historyTotalCustomers, _prevHistoryTotalCustomers);
      sessionsChange = _calculatePercentChange(
          _historyTotalSessions, _prevHistoryTotalSessions);
    }

    return {
      'text': text,
      'revenueChange': revenueChange,
      'billsChange': billsChange,
      'customersChange': customersChange,
      'sessionsChange': sessionsChange,
    };
  }

  // --- _buildTableRow (Sử dụng Spacer) ---
  Widget _buildTableRow({
    required List<Widget> cells,
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

    return Container(
      height: height,
      color: backgroundColor,
      padding: EdgeInsets.symmetric(horizontal: _tableCellHorizontalPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _colWidthId,
            child: buildCellWrapper(cells[0], Alignment.centerLeft),
          ),
          const Spacer(),
          SizedBox(
            width: _colWidthStatus,
            child: buildCellWrapper(cells[1], Alignment.center),
          ),
          const Spacer(),
          Expanded(
            flex: _colFlexPaymentTime,
            child: buildCellWrapper(cells[2], Alignment.centerLeft),
          ),
          const Spacer(),
          Expanded(
            flex: _colFlexPaymentMethod,
            child: buildCellWrapper(cells[3], Alignment.centerLeft),
          ),
          const Spacer(),
          Expanded(
            flex: _colFlexAmount,
            child: buildCellWrapper(cells[4], Alignment.centerLeft),
          ),
          const Spacer(),
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
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        iconData = Icons.check_circle_outline_rounded;
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

  // **CẬP NHẬT HÀM TRIGGER FETCH LỊCH SỬ**
  Future<void> _triggerHistoryFetch({int? year, int? month, int? day}) async {
    year ??= _selectedHistoryYear;
    month ??= _selectedHistoryMonth;
    day ??= _selectedHistoryDay;

    if (year == null) {
      setStateIfMounted(() => _historyError = "Vui lòng chọn Năm để lọc.");
      return;
    }

    setStateIfMounted(() {
      _isLoadingHistory = true;
      _isLoadingPrevHistory = true;
      _historyError = null;
      _historySummaryError = null;
      _historicalBills = [];
      _historyTotalRevenue = 0.0;
      _historyTotalBills = 0;
      _historyTotalCustomers = 0;
      _historyTotalSessions = 0;
      _prevHistoryTotalRevenue = 0.0;
      _prevHistoryTotalBills = 0;
      _prevHistoryTotalCustomers = 0;
      _prevHistoryTotalSessions = 0;
    });

    // Xác định kỳ trước đó
    int? prevYear;
    int? prevMonth;
    int? prevDay;
    if (day != null && month != null) {
      try {
        final current = DateTime(year, month, day);
        final previous = current.subtract(const Duration(days: 1));
        prevYear = previous.year;
        prevMonth = previous.month;
        prevDay = previous.day;
      } catch (e) {
        prevYear = null;
      }
    } else if (month != null) {
      try {
        final current = DateTime(year, month);
        final previous = DateTime(current.year, current.month - 1);
        prevYear = previous.year;
        prevMonth = previous.month;
        prevDay = null;
      } catch (e) {
        prevYear = null;
      }
    } else {
      try {
        prevYear = year - 1;
        prevMonth = null;
        prevDay = null;
      } catch (e) {
        prevYear = null;
      }
    }

    // Gọi song song các API
    List<Future> fetches = [
      _fetchPaymentHistoryData(year: year, month: month, day: day),
      _fetchHistoryCustomerSummaryData(year: year, month: month, day: day),
    ];
    if (prevYear != null) {
      fetches.add(_fetchPaymentHistoryData(
          year: prevYear, month: prevMonth, day: prevDay, isPrevious: true));
      fetches.add(_fetchHistoryCustomerSummaryData(
          year: prevYear, month: prevMonth, day: prevDay, isPrevious: true));
    } else {
      setStateIfMounted(() => _isLoadingPrevHistory = false);
    }

    try {
      await Future.wait(fetches);
      // Gộp lỗi sau khi cả hai hoàn thành
      if (_historySummaryError != null && _historyError == null) {
        if (mounted) {
          setState(() => _historyError = _historySummaryError);
        }
      }
    } catch (e) {
      print("Error during parallel history fetch: $e");
      if (mounted) {
        setState(() {
          _historyError ??= 'Lỗi khi tải dữ liệu lịch sử.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
          if (prevYear != null) {
            _isLoadingPrevHistory = false;
          }
        });
      }
    }
  }

  // **CẬP NHẬT HÀM FETCH LỊCH SỬ ĐỂ LƯU DỮ LIỆU KỲ TRƯỚC**
  Future<void> _fetchPaymentHistoryData(
      {required int year,
      int? month,
      int? day,
      bool isPrevious = false}) async {
    final Map<String, String> queryParams = {'year': year.toString()};
    if (month != null) {
      queryParams['month'] = month.toString();
    }
    if (day != null && month != null) {
      queryParams['day'] = day.toString();
    }

    final url = Uri.parse('$BASE_API_URL/payment/history/')
        .replace(queryParameters: queryParams);
    final periodDesc = isPrevious ? "previous" : "current";
    print("Fetching $periodDesc payment history data from: $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (!mounted) return; // Check mounted sau await

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final historyResponse = PaymentHistoryResponse.fromJson(data);

        if (!isPrevious) {
          setStateIfMounted(() {
            _historicalBills = historyResponse.payments;
            _historyTotalRevenue = historyResponse.totalRevenue;
            _historyTotalBills = historyResponse.payments.length;
          });
        } else {
          setStateIfMounted(() {
            _prevHistoryTotalRevenue = historyResponse.totalRevenue;
            _prevHistoryTotalBills = historyResponse.payments.length;
          });
        }
        print(
            "Fetched ${historyResponse.payments.length} $periodDesc historical payments data. Total Revenue: ${historyResponse.totalRevenue}");
      } else {
        if (!isPrevious) {
          setStateIfMounted(() {
            _historicalBills = [];
            _historyTotalRevenue = 0.0;
            _historyTotalBills = 0;
            if (response.statusCode != 404) {
              _historyError =
                  'Lỗi tải danh sách phiếu (${response.statusCode})';
            }
          });
        } else {
          setStateIfMounted(() {
            _prevHistoryTotalRevenue = 0.0;
            _prevHistoryTotalBills = 0;
          });
        }
        print(
            "Error or Not Found fetching $periodDesc payment history data (${response.statusCode}).");
      }
    } catch (e) {
      print("Exception fetching $periodDesc payment history data: $e");
      if (!isPrevious) {
        setStateIfMounted(() {
          _historicalBills = [];
          _historyTotalRevenue = 0.0;
          _historyTotalBills = 0;
          _historyError = 'Lỗi kết nối (danh sách phiếu).';
        });
      } else {
        setStateIfMounted(() {
          _prevHistoryTotalRevenue = 0.0;
          _prevHistoryTotalBills = 0;
        });
      }
    }
  }

  // **CẬP NHẬT HÀM FETCH SUMMARY LỊCH SỬ ĐỂ LƯU DỮ LIỆU KỲ TRƯỚC**
  Future<void> _fetchHistoryCustomerSummaryData(
      {required int year,
      int? month,
      int? day,
      bool isPrevious = false}) async {
    final Map<String, String> queryParams = {'year': year.toString()};
    if (month != null) {
      queryParams['month'] = month.toString();
    }
    if (day != null && month != null) {
      queryParams['day'] = day.toString();
    }

    final url = Uri.parse('$BASE_API_URL/payment/total-customers/by-date/')
        .replace(queryParameters: queryParams);
    final periodDesc = isPrevious ? "previous" : "current";
    print("Fetching $periodDesc history customer summary from: $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (!mounted) return; // Check mounted sau await

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final summary = HistoryCustomerSummary.fromJson(data);
        if (!isPrevious) {
          setStateIfMounted(() {
            _historyTotalCustomers = summary.totalCustomers;
            _historyTotalSessions = summary.totalSessions;
            _historySummaryError = null;
          });
        } else {
          setStateIfMounted(() {
            _prevHistoryTotalCustomers = summary.totalCustomers;
            _prevHistoryTotalSessions = summary.totalSessions;
          });
        }
        print(
            "Fetched $periodDesc history customer summary: Cust=${summary.totalCustomers}, Sess=${summary.totalSessions}");
      } else {
        if (!isPrevious) {
          setStateIfMounted(() {
            _historyTotalCustomers = 0;
            _historyTotalSessions = 0;
            if (response.statusCode != 404) {
              _historySummaryError = 'Lỗi tải tóm tắt (${response.statusCode})';
            }
          });
        } else {
          setStateIfMounted(() {
            _prevHistoryTotalCustomers = 0;
            _prevHistoryTotalSessions = 0;
          });
        }
        print(
            "Error or Not Found fetching $periodDesc history customer summary (${response.statusCode}).");
      }
    } catch (e) {
      print("Exception fetching $periodDesc history customer summary: $e");
      if (!isPrevious) {
        setStateIfMounted(() {
          _historyTotalCustomers = 0;
          _historyTotalSessions = 0;
          _historySummaryError = 'Lỗi kết nối (tóm tắt).';
        });
      } else {
        setStateIfMounted(() {
          _prevHistoryTotalCustomers = 0;
          _prevHistoryTotalSessions = 0;
        });
      }
    }
  }

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

    final List<DropdownMenuItem<int?>> monthItems = [
      const DropdownMenuItem<int?>(value: null, child: Text("Tất cả tháng")),
      ...List.generate(
          12,
          (i) => DropdownMenuItem<int?>(
              value: i + 1, child: Text("Tháng ${i + 1}"))),
    ];

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // **ROW CHỨA TEXT MÔ TẢ VÀ BỘ LỌC - CĂN PHẢI BỘ LỌC**
        Padding(
          padding: EdgeInsets.only(bottom: _tableCellHorizontalPadding * 2.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _isLoadingHistory || _isLoadingPrevHistory
                      ? 'Đang tải lịch sử...'
                      : 'Lịch sử ${_buildFilterDescription()}: ${_historyTotalBills} phiếu - ${_currencyFormatter.format(_historyTotalRevenue)}',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: kFilterSpacing),

              // Phần các Dropdown và nút Lọc (Wrap căn phải)
              Wrap(
                spacing: kFilterSpacing,
                runSpacing: kFilterSpacing,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.end, // **CĂN PHẢI WIDGET TRONG WRAP**
                children: [
                  _buildHistoryFilterDropdown<int>(
                    theme: theme,
                    value: _selectedHistoryYear ?? _years.first,
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
                      }
                    },
                  ),
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
                  ElevatedButton.icon(
                    icon: Icon(Icons.filter_list, size: 16),
                    label: Text('Lọc'),
                    onPressed: _isLoadingHistory || _isLoadingPrevHistory
                        ? null
                        : () => _triggerHistoryFetch(), // Disable khi đang load
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
                            _isLoadingHistory ||
                            _isLoadingPrevHistory)
                        ? () async {}
                        : () => _triggerHistoryFetch(), // Gọi hàm trigger mới
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
          onChanged:
              _isLoadingHistory || _isLoadingPrevHistory ? null : onChanged,
          style: theme.textTheme.bodyMedium,
          icon: Icon(Icons.arrow_drop_down,
              size: 20,
              color: _isLoadingHistory || _isLoadingPrevHistory
                  ? Colors.grey
                  : null),
          isExpanded: false,
          focusColor: Colors.transparent,
        ),
      ),
    );
  }

  // **Hàm helper để tạo mô tả bộ lọc hiện tại**
  String _buildFilterDescription({bool short = false}) {
    if (_selectedHistoryYear == null) return "Chưa chọn";
    String desc = _selectedHistoryYear.toString();
    if (_selectedHistoryMonth != null) {
      desc += "/${_selectedHistoryMonth.toString().padLeft(2, '0')}";
      if (_selectedHistoryDay != null) {
        desc += "/${_selectedHistoryDay.toString().padLeft(2, '0')}";
      } else if (!short) {
        // desc += "/Tất cả ngày"; // Bỏ nếu không muốn hiển thị
      }
    } else if (!short) {
      desc += "/Tất cả";
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
