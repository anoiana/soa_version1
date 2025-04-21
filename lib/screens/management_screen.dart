import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math; // Để tạo dữ liệu giả
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart'; // Import for firstWhereOrNull
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // **IMPORT FOR CLIPBOARD**

import 'openTable.dart'; // Để định dạng ngày và tiền tệ (Ensure this file exists and defines TableSelectionScreen)
// import 'package:data_table_2/data_table_2.dart'; // REMOVED DataTable2 - Still removed
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
void main() {
  // **TRẢ LẠI HÀM MAIN GỐC**
  runApp(MyApp());
}

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
                      // Consider alternating row colors if desired
                      return Colors.white; // Example: Keep all white for now
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
            // ***IMPORTANT: Provide a default role or get it from actual login/auth state***
            home: ManagementScreen(role: 'Quản lý'), // Widget chính của bạn
          );
        }
      },
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
  final Color _oddRowColor = Colors.grey.shade100; // Define odd row color

  final List<int> _years = List<int>.generate(
      DateTime.now().year - 2019, (i) => DateTime.now().year - i);

  @override
  void initState() {
    super.initState();
    _selectedHistoryYear = DateTime.now().year;
    // **KHÔNG GỌI KHỞI TẠO LOCALE Ở ĐÂY NỮA**
    _fetchShifts();
    _triggerHistoryFetch(); // Fetch initial history (e.g., current year)
  }

  @override
  void dispose() {
    // Clean up resources if necessary
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
    final bool isHistoryView = _currentViewIndex == 1;

    // Determine loading state for display
    bool isLoadingCurrent = isHistoryView
        ? _isLoadingHistory
        : (_isLoadingShiftPayments || _isLoadingCustomerSummary);
    bool isLoadingPrevious = isHistoryView ? _isLoadingPrevHistory : false;
    bool isLoading = isLoadingCurrent || isLoadingPrevious;

    // Determine current values based on view
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

    // Calculate and format comparison data only for history view
    String historyComparisonPeriodText = '';
    String historyRevenueChange = '';
    String historyBillsChange = '';
    String historyCustomersChange = '';
    String historySessionsChange = '';

    if (isHistoryView && !isLoading && _historyError == null) {
      final comparisonData = _getComparisonPeriodTextAndCalculateChanges();
      historyComparisonPeriodText = comparisonData['text'] ?? '';
      historyRevenueChange = comparisonData['revenueChange'] ?? '';
      historyBillsChange = comparisonData['billsChange'] ?? '';
      historyCustomersChange = comparisonData['customersChange'] ?? '';
      historySessionsChange = comparisonData['sessionsChange'] ?? '';
    } else if (isHistoryView && isLoading) {
      historyComparisonPeriodText = 'Đang tải so sánh...';
    }

    // Determine display text based on view
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

    // Layout the Grid
    return LayoutBuilder(builder: (context, constraints) {
      int crossAxisCount = 4;
      if (constraints.maxWidth < 1200) crossAxisCount = 4;
      if (constraints.maxWidth < 900) crossAxisCount = 2;
      if (constraints.maxWidth < 500) crossAxisCount = 1;
      double childAspectRatio = isHistoryView ? 2.2 : 2.4; // Adjusted ratios
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
    final bool showComparison = comparisonText.isNotEmpty;
    final bool showChange = change.isNotEmpty;

    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row: Title and Icon
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          // Allow title to wrap if necessary
                          child: Text(title,
                              style: textTheme.labelSmall?.copyWith(
                                  color: textTheme.labelSmall?.color
                                      ?.withOpacity(0.9),
                                  fontWeight: FontWeight.w600)),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Icon(icon,
                              size: 18, color: iconColor.withOpacity(0.8)),
                        )
                      ]),
                  // Bottom Section: Value, Change, Comparison Text
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          // Value (allow potential wrapping)
                          Flexible(
                            child: Text(
                              value,
                              style: textTheme.titleLarge?.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textTheme.titleLarge?.color),
                              overflow:
                                  TextOverflow.ellipsis, // Prevent overflow
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(width: 4), // Space between value and change
                          // Change Indicator (if available)
                          if (showChange)
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
                          // Placeholder if no change but comparison exists (for alignment)
                          if (!showChange && showComparison)
                            const SizedBox(height: 15),
                        ],
                      ),
                      // Comparison Text (aligned right, optional)
                      if (showComparison)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              comparisonText,
                              style: textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                      // Placeholder if no comparison text (for consistent height)
                      if (!showComparison)
                        SizedBox(
                            height: (textTheme.bodySmall?.fontSize ?? 10.5) +
                                2.0), // Match height of comparison text line
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
    return Colors.grey.shade600; // Neutral color if no change or '0%'
  }

  String _calculatePercentChange(num currentValue, num previousValue) {
    if (previousValue == 0) {
      if (currentValue > 0) return '↑ Mới'; // New value added
      if (currentValue == 0) return '0%'; // Was 0, is 0
      return ''; // Should not happen if previous was 0 and current < 0
    }
    if (currentValue == previousValue) {
      return '0%'; // No change
    }
    double change = (currentValue.toDouble() - previousValue.toDouble()) /
        previousValue.abs(); // Use absolute for percentage base
    String prefix = change > 0 ? '+' : ''; // Add '+' sign for positive change
    // Handle very small changes that might round to 0%
    if (change.abs() < 0.0001 && change != 0) {
      return change > 0 ? '+~0%' : '-~0%';
    }
    NumberFormat formatter =
        NumberFormat("##0.#%", "vi_VN"); // Format as percentage
    return prefix +
        formatter.format(change); // Return with sign and formatted percentage
  }

  Map<String, String> _getComparisonPeriodTextAndCalculateChanges() {
    String text = '';
    int? prevYear = _selectedHistoryYear;
    int? prevMonth = _selectedHistoryMonth;
    int? prevDay = _selectedHistoryDay;
    bool canCompare = false;
    DateTime? previousPeriodDate;
    DateTime? currentPeriodDate; // To display the *current* period in text

    // Determine the current and previous periods for comparison
    if (prevDay != null && prevMonth != null && prevYear != null) {
      try {
        currentPeriodDate = DateTime(prevYear, prevMonth, prevDay);
        previousPeriodDate =
            currentPeriodDate.subtract(const Duration(days: 1));
        text = 'so với ${_dateFormatter.format(previousPeriodDate)}';
        canCompare = true;
      } catch (e) {
        // Handle invalid date combinations if necessary
        print("Error creating date for comparison (day): $e");
        prevYear = null; // Invalidate comparison
      }
    } else if (prevMonth != null && prevYear != null) {
      try {
        currentPeriodDate = DateTime(prevYear, prevMonth);
        // Calculate previous month correctly, handling year change
        previousPeriodDate =
            DateTime(currentPeriodDate.year, currentPeriodDate.month - 1);
        text =
            'so với T${_monthYearFormatter.format(previousPeriodDate).split('/')[0]}'; // Just show 'T<month>'
        canCompare = true;
      } catch (e) {
        print("Error creating date for comparison (month): $e");
        prevYear = null; // Invalidate comparison
      }
    } else if (prevYear != null) {
      try {
        currentPeriodDate = DateTime(prevYear);
        previousPeriodDate = DateTime(prevYear - 1);
        text = 'so với ${_yearFormatter.format(previousPeriodDate)}';
        canCompare = true;
      } catch (e) {
        print("Error creating date for comparison (year): $e");
        prevYear = null; // Invalidate comparison
      }
    } else {
      text = ''; // No comparison possible if year is not selected
      canCompare = false;
    }

    // Initialize change strings
    String revenueChange = '';
    String billsChange = '';
    String customersChange = '';
    String sessionsChange = '';

    // Calculate percentage changes if comparison is possible and previous data is loaded
    if (canCompare && !_isLoadingPrevHistory) {
      revenueChange = _calculatePercentChange(
          _historyTotalRevenue, _prevHistoryTotalRevenue);
      billsChange =
          _calculatePercentChange(_historyTotalBills, _prevHistoryTotalBills);
      customersChange = _calculatePercentChange(
          _historyTotalCustomers, _prevHistoryTotalCustomers);
      sessionsChange = _calculatePercentChange(
          _historyTotalSessions, _prevHistoryTotalSessions);
    } else if (canCompare && _isLoadingPrevHistory) {
      // Indicate that comparison data is still loading
      revenueChange = '...';
      billsChange = '...';
      customersChange = '...';
      sessionsChange = '...';
    }

    return {
      'text': text,
      'revenueChange': revenueChange,
      'billsChange': billsChange,
      'customersChange': customersChange,
      'sessionsChange': sessionsChange,
    };
  }

  // --- _buildTableRow (Sử dụng Spacer and fixed/flex widths) ---
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

    // Helper to wrap cell content with padding and alignment
    Widget buildCellWrapper(Widget content, Alignment alignment,
        {double? width, int? flex}) {
      final wrapper = Padding(
        padding: cellPadding,
        child: Align(
          alignment: alignment,
          child: DefaultTextStyle(
            style: isHeader ? headerStyle : dataStyle,
            child: content,
          ),
        ),
      );
      if (width != null) {
        return SizedBox(width: width, child: wrapper);
      } else if (flex != null) {
        return Expanded(flex: flex, child: wrapper);
      } else {
        return Expanded(child: wrapper); // Default flex if none provided
      }
    }

    return Container(
      height: height,
      color: backgroundColor,
      padding: EdgeInsets.symmetric(
          horizontal: _tableCellHorizontalPadding / 2), // Slight outer padding
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.stretch, // Ensure cells fill height
        children: [
          // Column 0: ID (Fixed Width)
          buildCellWrapper(cells[0], Alignment.centerLeft, width: _colWidthId),
          // Column 1: Status (Fixed Width)
          buildCellWrapper(cells[1], Alignment.center, width: _colWidthStatus),
          // Column 2: Payment Time (Flex Width)
          buildCellWrapper(cells[2], Alignment.centerLeft,
              flex: _colFlexPaymentTime),
          // Column 3: Payment Method (Flex Width)
          buildCellWrapper(cells[3], Alignment.centerLeft,
              flex: _colFlexPaymentMethod),
          // Column 4: Amount (Flex Width)
          buildCellWrapper(cells[4], Alignment.centerRight,
              flex: _colFlexAmount), // Align amount right
          // Column 5: Details Button (Fixed Width)
          buildCellWrapper(cells[5], Alignment.center, width: _colWidthDetails),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, String statusText) {
    Color backgroundColor;
    Color textColor;
    IconData? iconData;
    String displayStatus = statusText;

    // Normalize status text for easier comparison
    String lowerCaseStatus = statusText.toLowerCase();

    switch (lowerCaseStatus) {
      case 'hoàn thành':
      case 'completed':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        iconData = Icons.check_circle_outline_rounded;
        displayStatus = "Hoàn thành"; // Standardize display text
        break;
      case 'pending':
      case 'đang chờ':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        iconData = Icons.hourglass_empty_rounded;
        displayStatus = "Đang chờ";
        break;
      case 'cancelled':
      case 'đã hủy':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        iconData = Icons.cancel_outlined;
        displayStatus = "Đã hủy";
        break;
      default: // Unknown or other statuses
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade800;
        iconData = Icons.help_outline_rounded;
      // Keep original text if unknown
    }

    return Chip(
        avatar: iconData != null
            ? Icon(iconData, size: 14, color: textColor)
            : null,
        label: Text(displayStatus, overflow: TextOverflow.ellipsis),
        labelStyle: theme.chipTheme.labelStyle
            ?.copyWith(color: textColor, fontSize: 11.5),
        backgroundColor: backgroundColor,
        padding: theme.chipTheme.padding, // Use theme padding
        shape: theme.chipTheme.shape, // Use theme shape
        materialTapTargetSize:
            MaterialTapTargetSize.shrinkWrap, // Reduce tap area
        visualDensity: VisualDensity.compact // Make chip smaller
        );
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
      _isLoadingShiftPayments = false; // Reset payment loading state too
    });
    print("Fetching shifts...");
    final url = Uri.parse('$BASE_API_URL/shifts/');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (!mounted) return; // Check after await
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<Shift> fetchedShifts = data
            .map((s) => Shift.fromJson(s))
            .where((s) => s.startTime.year > 1970) // Basic validation
            .toList();
        // Sort shifts by start time, earliest first
        fetchedShifts.sort((a, b) => a.startTime.compareTo(b.startTime));

        setStateIfMounted(() {
          _shifts = fetchedShifts;
          _isLoadingShifts = false;
          _shiftError = null;
        });
        _autoSelectCurrentOrLatestShift(); // Select a shift after fetching

        print("Fetched ${_shifts.length} valid shifts.");
      } else {
        print("Error fetching shifts: ${response.statusCode}");
        setStateIfMounted(() {
          _shiftError = 'Lỗi tải ca (${response.statusCode})';
          _isLoadingShifts = false;
        });
      }
    } catch (e) {
      print("Exception fetching shifts: $e");
      if (mounted) {
        // Check mounted before setting state in catch block
        setStateIfMounted(() {
          _shiftError = 'Lỗi kết nối hoặc xử lý dữ liệu ca.';
          _isLoadingShifts = false;
        });
      }
    }
  }

  void _autoSelectCurrentOrLatestShift() {
    if (_shifts.isEmpty) {
      print("No shifts available to auto-select.");
      // Ensure loading indicator stops if fetch completed with no shifts
      if (_isLoadingShifts) setStateIfMounted(() => _isLoadingShifts = false);
      return;
    }

    final now = DateTime.now();
    // Find a shift where current time is between start and end time
    Shift? currentShift = _shifts.firstWhereOrNull((shift) =>
        !now.isBefore(shift.startTime) && now.isBefore(shift.endTime));

    // If no current shift found, select the latest one (last in the sorted list)
    final shiftToSelect = currentShift ?? _shifts.last;

    // Check if the shift needs to be selected or re-selected
    // Re-select if:
    // 1. The shift ID is different from the currently selected one.
    // 2. The shift ID is the same, BUT either:
    //    a. Payment data is missing (empty list, not loading, no error).
    //    b. Customer summary is missing (0 sessions, not loading).
    bool needsSelection = _selectedShiftId != shiftToSelect.shiftId;
    bool needsDataRefresh = _selectedShiftId == shiftToSelect.shiftId &&
        ((_shiftPayments.isEmpty &&
                !_isLoadingShiftPayments &&
                _paymentError == null) ||
            (!_isLoadingCustomerSummary &&
                _selectedShiftTotalSessions == 0 &&
                _selectedShiftTotalCustomers == 0)); // Check customers too

    if (needsSelection || needsDataRefresh) {
      print("Auto-selecting or re-selecting shift: ${shiftToSelect.shiftId}");
      _selectShift(shiftToSelect.shiftId);
    } else {
      print(
          "Shift ${shiftToSelect.shiftId} already selected/current and has data or is loading.");
      // Ensure loading indicators are turned off if fetch completed but no re-selection needed
      if (_isLoadingShifts) setStateIfMounted(() => _isLoadingShifts = false);
      if (_isLoadingShiftPayments)
        setStateIfMounted(() => _isLoadingShiftPayments = false);
      if (_isLoadingCustomerSummary)
        setStateIfMounted(() => _isLoadingCustomerSummary = false);
    }
  }

  void _selectShift(int shiftId) {
    // Prevent re-selecting the same shift if its data is already loading
    if (_selectedShiftId == shiftId &&
        (_isLoadingShiftPayments || _isLoadingCustomerSummary)) {
      print("Shift $shiftId is already loading data. Selection ignored.");
      return;
    }

    print("Shift selected: $shiftId");
    // Use addPostFrameCallback to ensure the state update happens after the current build cycle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use setStateIfMounted for safety
      setStateIfMounted(() {
        _selectedShiftId = shiftId;
        // Reset states for the new shift
        _isLoadingShiftPayments = true; // Start loading payments
        _isLoadingCustomerSummary = true; // Start loading customer summary
        _shiftPayments = []; // Clear previous payments
        _selectedShiftTotalRevenue = 0.0; // Reset revenue
        _paymentError = null; // Clear previous errors
        _selectedShiftTotalCustomers = 0; // Reset customer count
        _selectedShiftTotalSessions = 0; // Reset session count
        _fetchingDetailsForPaymentIds
            .clear(); // Clear any pending detail fetches
      });
      // Trigger the data fetching for the newly selected shift
      _fetchPaymentsForShift(shiftId);
      _fetchShiftCustomerSummary(shiftId);
    });
  }

  Future<void> _fetchPaymentsForShift(int shiftId) async {
    if (!mounted) return; // Check if widget is still mounted

    // Double-check if the selected shift is still the one we are fetching for
    if (_selectedShiftId != shiftId) {
      print(
          "Fetch payments for shift $shiftId aborted, selection changed to $_selectedShiftId");
      // Ensure loading indicator is turned off if fetch is aborted due to selection change
      if (mounted && _isLoadingShiftPayments) {
        // Check mounted again before setState
        setStateIfMounted(() => _isLoadingShiftPayments = false);
      }
      return;
    }

    // Ensure loading state is set (might already be true from _selectShift)
    if (!_isLoadingShiftPayments) {
      setStateIfMounted(() => _isLoadingShiftPayments = true);
    }
    _paymentError = null; // Clear previous error before fetching

    print("Fetching payments for shift: $shiftId");
    final url = Uri.parse('$BASE_API_URL/payment/shift/$shiftId');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (!mounted) return; // Check mounted state after await

      // Again, check if the selected shift is still the same after the network call
      if (_selectedShiftId == shiftId) {
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final summary = ShiftPaymentSummary.fromJson(data);
          // Sort payments by time, newest first
          summary.payments
              .sort((a, b) => b.paymentTime.compareTo(a.paymentTime));

          setStateIfMounted(() {
            _shiftPayments = summary.payments;
            _selectedShiftTotalRevenue = summary.totalRevenue;
            _paymentError = null; // Clear error on success
            _isLoadingShiftPayments = false; // Loading finished
          });
          print(
              "Fetched ${summary.payments.length} payments for shift $shiftId. Total Revenue: ${_currencyFormatter.format(summary.totalRevenue)}.");
        } else if (response.statusCode == 404) {
          // Handle 404 (Not Found) gracefully - likely means no payments for this shift yet
          setStateIfMounted(() {
            _shiftPayments = [];
            _selectedShiftTotalRevenue = 0.0;
            _paymentError = null; // No error, just no data
            _isLoadingShiftPayments = false; // Loading finished
          });
          print("No payments found (404) for shift $shiftId.");
        } else {
          // Handle other non-200 status codes as errors
          setStateIfMounted(() {
            _shiftPayments = [];
            _selectedShiftTotalRevenue = 0.0;
            _paymentError = 'Lỗi tải phiếu (${response.statusCode})';
            _isLoadingShiftPayments = false; // Loading finished (with error)
          });
          print(
              "Error fetching payments (${response.statusCode}) for shift $shiftId.");
        }
      } else {
        // Data is stale, selection changed during fetch
        print(
            "Ignoring stale payment data for shift $shiftId, current selection is $_selectedShiftId");
        // Ensure loading indicator is turned off if fetch completed but data is stale
        if (mounted && _isLoadingShiftPayments) {
          // Check mounted again
          setStateIfMounted(() => _isLoadingShiftPayments = false);
        }
      }
    } catch (e) {
      print("Exception fetching payments for shift $shiftId: $e");
      // Check mounted state and if the error is for the currently selected shift
      if (mounted && _selectedShiftId == shiftId) {
        setStateIfMounted(() {
          _paymentError = 'Lỗi kết nối hoặc xử lý dữ liệu phiếu.';
          _isLoadingShiftPayments = false; // Loading finished (with error)
          _shiftPayments = []; // Clear data on error
          _selectedShiftTotalRevenue = 0.0;
        });
      } else if (mounted && _isLoadingShiftPayments) {
        // If error occurred but selection changed, still turn off loading indicator
        setStateIfMounted(() => _isLoadingShiftPayments = false);
      }
    }
  }

  Future<void> _fetchShiftCustomerSummary(int shiftId) async {
    if (!mounted) return; // Check if widget is still mounted

    // Check if the selected shift is still the one we are fetching for
    if (_selectedShiftId != shiftId) {
      print(
          "Fetch summary for shift $shiftId aborted, selection changed to $_selectedShiftId");
      if (mounted && _isLoadingCustomerSummary) {
        setStateIfMounted(() => _isLoadingCustomerSummary = false);
      }
      return;
    }

    // Ensure loading state is set
    if (!_isLoadingCustomerSummary) {
      setStateIfMounted(() => _isLoadingCustomerSummary = true);
    }

    final url =
        Uri.parse('$BASE_API_URL/payment/shift/$shiftId/total-customers');
    print("Fetching customer summary for shift: $shiftId from $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (!mounted) return; // Check mounted after await

      // Check if the selection is still the same
      if (_selectedShiftId == shiftId) {
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final summary = ShiftCustomerSummary.fromJson(data);
          setStateIfMounted(() {
            _selectedShiftTotalCustomers = summary.totalCustomers;
            _selectedShiftTotalSessions = summary.totalSessions;
            _isLoadingCustomerSummary = false; // Loading finished
          });
          print(
              "Fetched customer summary for shift $shiftId: Customers=${summary.totalCustomers}, Sessions=${summary.totalSessions}");
        } else if (response.statusCode == 404) {
          // Handle 404 - No summary data found (might be valid if no sessions)
          setStateIfMounted(() {
            _selectedShiftTotalCustomers = 0;
            _selectedShiftTotalSessions = 0;
            _isLoadingCustomerSummary = false; // Loading finished
          });
          print("Customer summary not found (404) for shift $shiftId.");
        } else {
          // Handle other errors
          setStateIfMounted(() {
            _selectedShiftTotalCustomers = 0; // Reset on error
            _selectedShiftTotalSessions = 0;
            _isLoadingCustomerSummary = false; // Loading finished (with error)
            // Optionally set an error message if needed, but stats grid shows '...' anyway
          });
          print(
              "Error fetching customer summary (${response.statusCode}) for shift $shiftId");
        }
      } else {
        // Data is stale
        print(
            "Ignoring stale customer summary data for shift $shiftId, current selection is $_selectedShiftId");
        if (mounted && _isLoadingCustomerSummary) {
          // Check mounted again
          setStateIfMounted(() => _isLoadingCustomerSummary = false);
        }
      }
    } catch (e) {
      print("Exception fetching customer summary for shift $shiftId: $e");
      // Check mounted and selection before updating state
      if (mounted && _selectedShiftId == shiftId) {
        setStateIfMounted(() {
          _selectedShiftTotalCustomers = 0; // Reset on error
          _selectedShiftTotalSessions = 0;
          _isLoadingCustomerSummary = false; // Loading finished (with error)
          // Optionally set an error message here
        });
      } else if (mounted && _isLoadingCustomerSummary) {
        setStateIfMounted(() => _isLoadingCustomerSummary = false);
      }
    }
  }

  Future<PaymentDetail> _fetchPaymentDetails(int paymentId) async {
    // Note: No loading state change here, managed by _fetchingDetailsForPaymentIds set
    final url = Uri.parse('$BASE_API_URL/payment/$paymentId/detail');
    print("Fetching payment details for ID: $paymentId from $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      // No mounted check needed immediately after await *if* we don't update state here,
      // but the calling function MUST check mounted before using the result.

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print("Payment details fetched for ID $paymentId: $data");
        return PaymentDetail.fromJson(data);
      } else if (response.statusCode == 404) {
        print("Payment details not found (404) for ID: $paymentId");
        throw Exception('Không tìm thấy chi tiết hóa đơn #${paymentId} (404)');
      } else {
        print(
            "Error fetching payment details (${response.statusCode}) for ID: $paymentId");
        throw Exception(
            'Lỗi tải chi tiết hóa đơn #${paymentId} (${response.statusCode})');
      }
    } catch (e) {
      print("Exception fetching payment details for ID $paymentId: $e");
      if (e is TimeoutException) {
        throw Exception(
            'Hết thời gian chờ khi tải chi tiết hóa đơn #${paymentId}.');
      }
      if (e is Exception && e.toString().contains('Exception:')) {
        // Rethrow exceptions already formatted from above checks
        rethrow;
      }
      // Generic connection/processing error
      throw Exception(
          'Lỗi kết nối hoặc xử lý khi tải chi tiết hóa đơn #${paymentId}.');
    }
  }

  Future<void> _showPaymentDetailsDialog(
      BuildContext context, PaymentDetail details) async {
    // Ensure the widget is still mounted before showing the dialog
    if (!mounted) return;

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Helper to build consistent list tiles for details
    Widget buildDetailTile(IconData icon, String label, String value) {
      return ListTile(
        leading: Icon(icon,
            size: 20,
            color: theme.listTileTheme.iconColor ?? Colors.blueGrey.shade400),
        title: Text(label,
            style:
                textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
            value.isEmpty ? 'N/A' : value, // Show N/A if value is empty
            style: textTheme.bodyMedium?.copyWith(
                color: textTheme.bodyMedium?.color?.withOpacity(0.9))),
        dense: true, // Make tile more compact
        contentPadding: EdgeInsets.symmetric(vertical: 2, horizontal: 0),
        minLeadingWidth: 30, // Adjust leading icon spacing
      );
    }

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Chi tiết Hóa đơn #${details.paymentId}'),
          // Use SingleChildScrollView to prevent overflow if content is long
          content: SingleChildScrollView(
            child: ListBody(
              // ListBody arranges children vertically
              children: <Widget>[
                buildDetailTile(
                    Icons.table_restaurant_outlined,
                    'Số bàn',
                    details.tableNumber?.toString() ??
                        'Trực tiếp'), // Show 'Trực tiếp' if no table number
                Divider(height: 10, thickness: 0.5),
                buildDetailTile(
                    Icons.access_time_filled_rounded,
                    'Giờ vào bàn', // Changed label slightly
                    details.startTime != null
                        ? _dateTimeDetailFormatter.format(details.startTime!)
                        : 'N/A'),
                buildDetailTile(
                    Icons.access_time_rounded,
                    'Giờ thanh toán', // Changed label slightly (or use Payment time if endTime is null?)
                    details.endTime != null
                        ? _dateTimeDetailFormatter.format(details.endTime!)
                        : 'N/A'), // Show N/A if endTime is null
                Divider(height: 10, thickness: 0.5),
                buildDetailTile(Icons.people_alt_outlined, 'Số khách',
                    details.numberOfCustomers?.toString() ?? 'N/A'),
                buildDetailTile(
                    Icons.restaurant_menu_rounded,
                    'Gói buffet',
                    details.buffetPackage.isNotEmpty
                        ? details.buffetPackage
                        : 'Không xác định'), // Handle empty package name
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Đóng'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
            ),
          ],
          // Use theme defaults or customize padding/shape
          contentPadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0),
          titlePadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          shape: theme.dialogTheme.shape,
        );
      },
    );
  }

  // --- Trigger History Fetch (Handles both current and previous periods) ---
  Future<void> _triggerHistoryFetch({int? year, int? month, int? day}) async {
    // Use provided values or fallback to current state selections
    year ??= _selectedHistoryYear;
    month = month ?? _selectedHistoryMonth; // Allow month to be null
    day = day ?? _selectedHistoryDay; // Allow day to be null

    // Basic validation: Year must be selected
    if (year == null) {
      setStateIfMounted(() {
        _historyError = "Vui lòng chọn Năm để xem lịch sử.";
        _isLoadingHistory = false; // Ensure loading stops
        _isLoadingPrevHistory = false;
        // Clear previous data when validation fails
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
      return;
    }

    // Set loading states and clear previous data/errors
    setStateIfMounted(() {
      _isLoadingHistory = true;
      _isLoadingPrevHistory =
          true; // Assume we'll fetch previous period initially
      _historyError = null;
      _historySummaryError = null; // Clear specific summary error too
      _historicalBills = []; // Clear current results
      _historyTotalRevenue = 0.0;
      _historyTotalBills = 0;
      _historyTotalCustomers = 0;
      _historyTotalSessions = 0;
      _prevHistoryTotalRevenue = 0.0; // Clear previous results
      _prevHistoryTotalBills = 0;
      _prevHistoryTotalCustomers = 0;
      _prevHistoryTotalSessions = 0;
    });

    // Determine the previous period based on the selected current period
    int? prevYear;
    int? prevMonth;
    int? prevDay;
    bool fetchPrevious = true; // Flag to control fetching previous period

    try {
      if (day != null && month != null) {
        // Daily comparison: Previous day
        final current = DateTime(year, month, day);
        final previous = current.subtract(const Duration(days: 1));
        prevYear = previous.year;
        prevMonth = previous.month;
        prevDay = previous.day;
      } else if (month != null) {
        // Monthly comparison: Previous month
        final current = DateTime(year, month);
        final previous =
            DateTime(current.year, current.month - 1); // Handles year change
        prevYear = previous.year;
        prevMonth = previous.month;
        prevDay = null; // Compare whole months
      } else {
        // Yearly comparison: Previous year
        prevYear = year - 1;
        prevMonth = null;
        prevDay = null;
      }
    } catch (e) {
      // Handle potential errors if date calculation fails (e.g., invalid input)
      print("Error calculating previous period: $e");
      fetchPrevious =
          false; // Don't attempt to fetch previous if calculation failed
      setStateIfMounted(() =>
          _isLoadingPrevHistory = false); // Stop loading indicator for previous
    }

    // Create lists of futures for parallel fetching
    List<Future> currentPeriodFetches = [
      _fetchPaymentHistoryData(
          year: year, month: month, day: day, isPrevious: false),
      _fetchHistoryCustomerSummaryData(
          year: year, month: month, day: day, isPrevious: false),
    ];

    List<Future> previousPeriodFetches = [];
    if (fetchPrevious && prevYear != null) {
      previousPeriodFetches = [
        _fetchPaymentHistoryData(
            year: prevYear, month: prevMonth, day: prevDay, isPrevious: true),
        _fetchHistoryCustomerSummaryData(
            year: prevYear, month: prevMonth, day: prevDay, isPrevious: true),
      ];
    } else {
      // If not fetching previous, ensure loading state is off
      if (mounted && _isLoadingPrevHistory) {
        setStateIfMounted(() => _isLoadingPrevHistory = false);
      }
    }

    // Execute fetches in parallel using Future.wait
    try {
      await Future.wait([...currentPeriodFetches, ...previousPeriodFetches]);
      // After all futures complete, check for combined errors (summary error might have occurred)
      if (mounted) {
        // Check mounted before final state update
        setStateIfMounted(() {
          // Prioritize payment list error if both exist
          _historyError ??= _historySummaryError;
        });
      }
    } catch (e) {
      // Catch errors from Future.wait itself (though individual fetches handle their errors)
      print("Error during parallel history fetch execution: $e");
      if (mounted) {
        setStateIfMounted(() {
          _historyError ??= 'Lỗi khi tải dữ liệu lịch sử song song.';
        });
      }
    } finally {
      // Ensure loading indicators are turned off regardless of success/failure
      if (mounted) {
        setStateIfMounted(() {
          _isLoadingHistory = false;
          // Only turn off prev loading if it was ever true
          if (_isLoadingPrevHistory) {
            _isLoadingPrevHistory = false;
          }
        });
      }
    }
  }

  // --- Fetch Payment History Data (for current or previous period) ---
  Future<void> _fetchPaymentHistoryData(
      {required int year,
      int? month,
      int? day,
      required bool isPrevious}) async {
    // Added required isPrevious flag
    // Build query parameters
    final Map<String, String> queryParams = {'year': year.toString()};
    if (month != null) {
      queryParams['month'] = month.toString();
      // Only include day if month is also specified
      if (day != null) {
        queryParams['day'] = day.toString();
      }
    }

    final url = Uri.parse('$BASE_API_URL/payment/history/')
        .replace(queryParameters: queryParams);
    final periodDesc = isPrevious ? "previous" : "current";
    print("Fetching $periodDesc payment history data from: $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (!mounted) return; // Check mounted after await

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final historyResponse = PaymentHistoryResponse.fromJson(data);
        // Sort payments by time, newest first
        historyResponse.payments
            .sort((a, b) => b.paymentTime.compareTo(a.paymentTime));

        // Update the correct state variables based on isPrevious flag
        if (!isPrevious) {
          setStateIfMounted(() {
            _historicalBills = historyResponse.payments;
            _historyTotalRevenue = historyResponse.totalRevenue;
            _historyTotalBills = historyResponse.payments.length;
            // Clear specific error for this fetch on success
            if (_historyError != null && _historyError!.contains('phiếu')) {
              _historyError =
                  _historySummaryError; // Keep summary error if it exists
            }
          });
        } else {
          setStateIfMounted(() {
            _prevHistoryTotalRevenue = historyResponse.totalRevenue;
            _prevHistoryTotalBills = historyResponse.payments.length;
            // No error state needed for previous period, comparison just won't show % change
          });
        }
        print(
            "Fetched ${historyResponse.payments.length} $periodDesc historical payments. Total: ${_currencyFormatter.format(historyResponse.totalRevenue)}");
      } else if (response.statusCode == 404) {
        // Handle 404 (Not Found) - Valid scenario, means no data for the period
        print("No $periodDesc payment history data found (404) for period.");
        if (!isPrevious) {
          setStateIfMounted(() {
            _historicalBills = [];
            _historyTotalRevenue = 0.0;
            _historyTotalBills = 0;
            // Clear specific error for this fetch if it was 404
            if (_historyError != null && _historyError!.contains('phiếu')) {
              _historyError = _historySummaryError;
            }
          });
        } else {
          setStateIfMounted(() {
            _prevHistoryTotalRevenue = 0.0;
            _prevHistoryTotalBills = 0;
          });
        }
      } else {
        // Handle other non-200 errors
        print(
            "Error fetching $periodDesc payment history data (${response.statusCode}).");
        if (!isPrevious) {
          setStateIfMounted(() {
            _historicalBills = []; // Clear data on error
            _historyTotalRevenue = 0.0;
            _historyTotalBills = 0;
            _historyError =
                'Lỗi tải danh sách phiếu (${response.statusCode})'; // Set error message
          });
        } else {
          // For previous period, just reset values, don't show direct error
          setStateIfMounted(() {
            _prevHistoryTotalRevenue = 0.0;
            _prevHistoryTotalBills = 0;
          });
        }
      }
    } catch (e) {
      print("Exception fetching $periodDesc payment history data: $e");
      if (!mounted) return; // Check mounted in catch block
      if (!isPrevious) {
        setStateIfMounted(() {
          _historicalBills = [];
          _historyTotalRevenue = 0.0;
          _historyTotalBills = 0;
          _historyError =
              'Lỗi kết nối (danh sách phiếu).'; // Set connection error message
        });
      } else {
        // For previous period, just reset values on exception
        setStateIfMounted(() {
          _prevHistoryTotalRevenue = 0.0;
          _prevHistoryTotalBills = 0;
        });
      }
    }
  }

  // --- Fetch History Customer Summary Data (for current or previous period) ---
  Future<void> _fetchHistoryCustomerSummaryData(
      {required int year,
      int? month,
      int? day,
      required bool isPrevious}) async {
    // Added required isPrevious flag
    // Build query parameters
    final Map<String, String> queryParams = {'year': year.toString()};
    if (month != null) {
      queryParams['month'] = month.toString();
      // Only include day if month is also specified
      if (day != null) {
        queryParams['day'] = day.toString();
      }
    }

    final url = Uri.parse('$BASE_API_URL/payment/total-customers/by-date/')
        .replace(queryParameters: queryParams);
    final periodDesc = isPrevious ? "previous" : "current";
    print("Fetching $periodDesc history customer summary from: $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (!mounted) return; // Check mounted after await

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final summary = HistoryCustomerSummary.fromJson(data);

        // Update the correct state variables based on isPrevious flag
        if (!isPrevious) {
          setStateIfMounted(() {
            _historyTotalCustomers = summary.totalCustomers;
            _historyTotalSessions = summary.totalSessions;
            _historySummaryError =
                null; // Clear specific summary error on success
          });
        } else {
          setStateIfMounted(() {
            _prevHistoryTotalCustomers = summary.totalCustomers;
            _prevHistoryTotalSessions = summary.totalSessions;
          });
        }
        print(
            "Fetched $periodDesc history customer summary: Cust=${summary.totalCustomers}, Sess=${summary.totalSessions}");
      } else if (response.statusCode == 404) {
        // Handle 404 (Not Found) - Valid, means no customers/sessions found
        print(
            "No $periodDesc history customer summary data found (404) for period.");
        if (!isPrevious) {
          setStateIfMounted(() {
            _historyTotalCustomers = 0;
            _historyTotalSessions = 0;
            _historySummaryError = null; // Clear error on 404
          });
        } else {
          setStateIfMounted(() {
            _prevHistoryTotalCustomers = 0;
            _prevHistoryTotalSessions = 0;
          });
        }
      } else {
        // Handle other non-200 errors
        print(
            "Error fetching $periodDesc history customer summary (${response.statusCode}).");
        if (!isPrevious) {
          setStateIfMounted(() {
            _historyTotalCustomers = 0; // Reset on error
            _historyTotalSessions = 0;
            _historySummaryError =
                'Lỗi tải tóm tắt khách (${response.statusCode})'; // Set specific error
          });
        } else {
          // For previous period, just reset values
          setStateIfMounted(() {
            _prevHistoryTotalCustomers = 0;
            _prevHistoryTotalSessions = 0;
          });
        }
      }
    } catch (e) {
      print("Exception fetching $periodDesc history customer summary: $e");
      if (!mounted) return; // Check mounted in catch block
      if (!isPrevious) {
        setStateIfMounted(() {
          _historyTotalCustomers = 0;
          _historyTotalSessions = 0;
          _historySummaryError =
              'Lỗi kết nối (tóm tắt khách).'; // Set connection error
        });
      } else {
        // For previous period, just reset values on exception
        setStateIfMounted(() {
          _prevHistoryTotalCustomers = 0;
          _prevHistoryTotalSessions = 0;
        });
      }
    }
  }

  // --- Helper function to show secret code dialog ---
  Future<void> _showSecretCodeDialog(BuildContext context, Shift shift) async {
    if (!mounted) return; // Check if mounted before showing dialog

    final theme = Theme.of(context);
    final formatTime = _timeFormatter;
    final shiftTimeStr =
        'Ca ${formatTime.format(shift.startTime)} - ${formatTime.format(shift.endTime)} (${_dateFormatter.format(shift.startTime)})'; // Add date

    await showDialog<void>(
      context: context,
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Secret code', style: theme.dialogTheme.titleTextStyle),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  shiftTimeStr,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
                ),
                SizedBox(height: 15),
                Text(
                  'Secret code cho ca này:',
                  style: theme.dialogTheme.contentTextStyle,
                ),
                SizedBox(height: 8),
                // Use a Card for better visual separation of the code
                Card(
                  elevation: 0.5,
                  color: theme.inputDecorationTheme.fillColor ??
                      theme.colorScheme.surface.withOpacity(0.5),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10.0, horizontal: 15.0),
                    child: SelectableText(
                      shift.secretCode.isNotEmpty
                          ? shift.secretCode
                          : 'N/A', // Handle potential empty code
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: shift.secretCode.isNotEmpty
                            ? theme.colorScheme.secondary
                            : theme.textTheme.bodySmall?.color, // Dim 'N/A'
                        fontSize: 18,
                        letterSpacing: 1.5, // Add spacing for readability
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(height: 15),
                // Copy button
                if (shift.secretCode.isNotEmpty &&
                    shift.secretCode !=
                        'N/A') // Only show copy if there's a code
                  Center(
                    child: OutlinedButton.icon(
                        icon: Icon(Icons.copy_all_outlined, size: 16),
                        label: Text('Sao chép'),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: shift.secretCode));
                          // Close dialog *before* showing snackbar for better UX
                          Navigator.of(dialogContext).pop();
                          // Check mounted again before showing snackbar
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã sao chép secret code!'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.green.shade700,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        style: theme.outlinedButtonTheme.style?.copyWith(
                            padding: MaterialStateProperty.all(
                                EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8)))),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Đóng'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          contentPadding: const EdgeInsets.fromLTRB(
              20.0, 15.0, 20.0, 10.0), // Adjusted padding
          titlePadding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0),
          shape: theme.dialogTheme.shape, // Use theme shape
        );
      },
    );
  }

  // --- Build Method Chính ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kPagePadding = 18.0;

    return Scaffold(
      appBar: AppBar(
        // Hamburger menu icon
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded), // Use rounded menu icon
            tooltip: 'Mở menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        leadingWidth: 56, // Standard width for leading icon button
        title: Text(
            'Quản Lý Bán Hàng'), // Removed style override, uses AppBarTheme
        actions: [
          // Refresh Button (conditional based on view)
          if (_currentViewIndex == 0 &&
              _selectedShiftId !=
                  null) // Show only for current shift view if a shift is selected
            IconButton(
              icon: Icon(Icons.refresh_rounded, size: 22),
              tooltip: 'Làm mới dữ liệu ca',
              onPressed: (_isLoadingShiftPayments || _isLoadingCustomerSummary)
                  ? null
                  : () {
                      // Trigger refresh for the selected shift
                      if (_selectedShiftId != null) {
                        _fetchPaymentsForShift(_selectedShiftId!);
                        _fetchShiftCustomerSummary(_selectedShiftId!);
                      }
                    },
            ),
          if (_currentViewIndex == 1 &&
              _selectedHistoryYear !=
                  null) // Show only for history view if a year is selected
            IconButton(
              icon: Icon(Icons.refresh_rounded, size: 22),
              tooltip: 'Làm mới lịch sử',
              onPressed: (_isLoadingHistory || _isLoadingPrevHistory)
                  ? null
                  : () {
                      // Trigger refresh for the selected history period
                      _triggerHistoryFetch();
                    },
            ),

          // Notifications Button
          IconButton(
            icon: Icon(Icons.notifications_none_outlined, size: 22),
            tooltip: 'Thông báo',
            onPressed: () {
              // TODO: Implement notification handling
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Chức năng thông báo chưa được cài đặt.')),
              );
            },
          ),
          // Exit Button - Navigates back to TableSelectionScreen
          IconButton(
            icon: Icon(Icons.exit_to_app), // Standard exit icon
            tooltip: 'Về màn hình chọn bàn', // More descriptive tooltip
            onPressed: () {
              // Use pushReplacement to prevent user from navigating back to ManagementScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => TableSelectionScreen(
                    // Pass the role back or retrieve it from auth state
                    role: widget.role,
                  ),
                ),
              );
            },
          ),
          SizedBox(width: 8), // Add some padding to the right of actions
        ],
        // AppBar theme is applied automatically from ThemeData
      ),
      drawer: _buildAppDrawer(theme), // Use a separate method for the drawer
      body: Padding(
        padding: EdgeInsets.all(kPagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistics Grid
            _buildStatsGrid(context, theme),
            SizedBox(height: kPagePadding), // Spacing below stats

            // Main Content Area (IndexedStack for switching views)
            Expanded(
              child: IndexedStack(
                index: _currentViewIndex,
                children: [
                  // View 0: Current Shift View
                  _buildCurrentShiftView(theme),
                  // View 1: History View
                  _buildHistoryView(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widget to build the App Drawer ---
  Widget _buildAppDrawer(ThemeData theme) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero, // Remove default padding
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
                // Use secondary color from theme for header background
                color: theme.colorScheme.secondary),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'QUẢN LÝ NHÀ HÀNG', // Or a more specific title
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme
                      .onSecondary, // Use onSecondary color for text
                  fontSize: 20,
                ),
              ),
            ),
          ),
          // Menu Item: Current Shift
          ListTile(
            leading: Icon(
              Icons.schedule_rounded, // Use rounded icon
              color: _currentViewIndex == 0
                  ? theme.colorScheme.secondary
                  : theme.listTileTheme.iconColor,
              size: 22, // Slightly larger icon
            ),
            title: Text(
              'Ca Trực Hiện Tại',
              style: TextStyle(
                fontWeight: _currentViewIndex == 0
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 14,
                color: _currentViewIndex == 0
                    ? theme.colorScheme.secondary
                    : theme.textTheme.bodyLarge?.color,
              ),
            ),
            selected: _currentViewIndex == 0,
            selectedTileColor: theme.colorScheme.secondary
                .withOpacity(0.1), // Subtle selection highlight
            onTap: () {
              if (_currentViewIndex != 0) {
                setState(() => _currentViewIndex = 0);
                // Optionally, trigger a refresh of shift data if needed when switching back
                // _fetchShifts(); // Uncomment if you want to always refresh shifts on view change
              }
              Navigator.pop(context); // Close the drawer
            },
            contentPadding: EdgeInsets.symmetric(
                horizontal: 20, vertical: 4), // Adjust padding
          ),
          // Menu Item: Sales History
          ListTile(
            leading: Icon(
              Icons.history_rounded, // Use rounded icon
              color: _currentViewIndex == 1
                  ? theme.colorScheme.secondary
                  : theme.listTileTheme.iconColor,
              size: 22,
            ),
            title: Text(
              'Lịch Sử Bán Hàng',
              style: TextStyle(
                fontWeight: _currentViewIndex == 1
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 14,
                color: _currentViewIndex == 1
                    ? theme.colorScheme.secondary
                    : theme.textTheme.bodyLarge?.color,
              ),
            ),
            selected: _currentViewIndex == 1,
            selectedTileColor: theme.colorScheme.secondary.withOpacity(0.1),
            onTap: () {
              if (_currentViewIndex != 1) {
                setState(() => _currentViewIndex = 1);
                // Optionally, trigger a refresh of history data if needed
                // _triggerHistoryFetch(); // Uncomment if needed
              }
              Navigator.pop(context); // Close the drawer
            },
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          ),
          Divider(height: 1, indent: 20, endIndent: 20), // Add a divider
          // Add more menu items here if needed (e.g., Settings, Reports)
          // Example:
          /*
             ListTile(
               leading: Icon(Icons.settings_outlined, size: 22),
               title: Text('Cài đặt', style: TextStyle(fontSize: 14)),
               onTap: () {
                  // Navigate to settings or perform action
                  Navigator.pop(context);
               },
               contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
             ),
             */
          // Logout or Exit option at the bottom
          SizedBox(height: 20), // Spacer
          ListTile(
            leading: Icon(Icons.exit_to_app,
                size: 22, color: theme.colorScheme.error),
            title: Text('Về màn hình chính',
                style: TextStyle(fontSize: 14, color: theme.colorScheme.error)),
            onTap: () {
              Navigator.pop(context); // Close drawer first
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => TableSelectionScreen(role: widget.role),
                ),
              );
            },
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          ),
        ],
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
      crossAxisAlignment:
          CrossAxisAlignment.stretch, // Ensure children fill width
      children: [
        // Shift Selector Row
        _buildShiftSelector(
            theme, _tableCellHorizontalPadding * 2), // Pass padding
        SizedBox(
            height: _tableCellHorizontalPadding * 2), // Spacing below selector

        // Payment Table Card
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias, // Clip content to card shape
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Table Header Row
                _buildTableRow(
                  theme: theme,
                  height: _tableHeaderHeight,
                  isHeader: true,
                  backgroundColor: headerBackgroundColor,
                  cells: [
                    Text('MÃ HĐ'), // 0: ID
                    Text('TRẠNG THÁI'), // 1: Status
                    Text('TG THANH TOÁN'), // 2: Payment Time
                    Text('PT THANH TOÁN'), // 3: Payment Method
                    Text('TỔNG TIỀN'), // 4: Amount
                    Text('CHI TIẾT'), // 5: Details Button
                  ],
                ),
                // Header Divider
                Divider(
                    height: dividerThickness,
                    thickness: dividerThickness,
                    color: dividerColor),

                // Table Body (Scrollable Content)
                Expanded(
                  // Use RefreshIndicator for pull-to-refresh
                  child: RefreshIndicator(
                    onRefresh: () async {
                      // Only allow refresh if a shift is selected and not currently loading
                      if (_selectedShiftId != null &&
                          !_isLoadingShiftPayments &&
                          !_isLoadingCustomerSummary) {
                        print("Refreshing data for shift $_selectedShiftId");
                        // Fetch both payments and summary concurrently
                        await Future.wait([
                          _fetchPaymentsForShift(_selectedShiftId!),
                          _fetchShiftCustomerSummary(_selectedShiftId!),
                        ]);
                      } else {
                        print(
                            "Refresh skipped: No shift selected or already loading.");
                      }
                    },
                    color:
                        theme.colorScheme.secondary, // Refresh indicator color
                    backgroundColor: theme.cardTheme.color ??
                        Colors.white, // Background of indicator
                    child: _buildShiftPaymentsContent(
                        theme), // Builds the list or messages
                  ),
                ),

                // Table Footer Row (Optional, mirroring header)
                // Show footer only if there are payments and no loading/error
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
                    isHeader: true, // Use header style for consistency
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

    // --- Handle Loading State ---
    // Show loading indicator if EITHER payments OR summary is loading,
    // AND the list of payments is currently empty (to avoid showing loading over existing data).
    if ((_isLoadingShiftPayments || _isLoadingCustomerSummary) &&
        _shiftPayments.isEmpty &&
        _selectedShiftId != null) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: CircularProgressIndicator(color: theme.colorScheme.secondary),
      ));
    }

    // --- Handle Error State ---
    // Show payment-specific error if it exists
    if (_paymentError != null && _selectedShiftId != null) {
      return Center(
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              // Use column for text and potential retry button
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    color: theme.colorScheme.error, size: 30),
                SizedBox(height: 10),
                Text(_paymentError!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center),
                SizedBox(height: 15),
                ElevatedButton.icon(
                    icon: Icon(Icons.refresh, size: 18),
                    label: Text("Thử lại"),
                    onPressed: () {
                      if (_selectedShiftId != null) {
                        _fetchPaymentsForShift(_selectedShiftId!);
                        _fetchShiftCustomerSummary(
                            _selectedShiftId!); // Also retry summary
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ))
              ],
            )),
      );
    }

    // --- Handle Initial Loading State (Before shifts are fetched) ---
    if (_isLoadingShifts && _shifts.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text("Đang tải danh sách ca...",
                  style: theme.textTheme.bodyMedium)));
    }
    // --- Handle Error Fetching Shifts ---
    if (_shiftError != null && _shifts.isEmpty) {
      return Center(
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_shiftError!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center)),
      );
    }

    // --- Handle No Shift Selected State ---
    if (_selectedShiftId == null && !_isLoadingShifts) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
            _shifts.isEmpty
                ? "Không có ca nào được tìm thấy."
                : "Vui lòng chọn một ca từ danh sách trên.", // More informative message
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center),
      ));
    }

    // --- Handle Empty State (Shift selected, no payments, no error) ---
    // Check after loading and errors are handled
    if (!_isLoadingShiftPayments &&
        !_isLoadingCustomerSummary &&
        _shiftPayments.isEmpty &&
        _paymentError == null &&
        _selectedShiftId != null) {
      // Use LayoutBuilder and SingleChildScrollView to ensure "empty" message
      // is centered even if the list view area is large, and allows pull-to-refresh.
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics:
              AlwaysScrollableScrollPhysics(), // Enable refresh even when empty
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minHeight: constraints.maxHeight), // Fill viewport height
            child: Center(
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                      "Chưa có hóa đơn nào được ghi nhận trong ca này.", // Clearer message
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey.shade600),
                      textAlign: TextAlign.center)),
            ),
          ),
        ),
      );
    }

    // --- Display Data Rows ---
    // Only build the ListView if payments exist and there's no error blocking display
    if (_shiftPayments.isNotEmpty) {
      return ListView.separated(
        physics:
            const AlwaysScrollableScrollPhysics(), // Enable scrolling & refresh
        itemCount: _shiftPayments.length,
        separatorBuilder: (context, index) => Divider(
            height: dividerThickness,
            thickness: dividerThickness,
            color:
                dividerColor.withOpacity(0.6)), // Slightly transparent divider
        itemBuilder: (context, index) {
          final payment = _shiftPayments[index];
          // Assume status is always 'Hoàn thành' for payments retrieved from this endpoint
          final statusText = "Hoàn thành";
          // Check if details are currently being fetched for this specific payment
          final bool isLoadingDetails =
              _fetchingDetailsForPaymentIds.contains(payment.paymentId);

          return _buildTableRow(
            theme: theme,
            height: _tableRowHeight,
            // Apply alternating row color for better readability
            backgroundColor: index % 2 != 0 ? _oddRowColor : null,
            cells: [
              // 0: MÃ HĐ (Payment ID)
              Text(payment.paymentId.toString(),
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.secondary)), // Highlight ID
              // 1: TRẠNG THÁI (Status Chip)
              _buildStatusChip(theme, statusText),
              // 2: TG THANH TOÁN (Payment Time)
              Text(_fullDateTimeFormatter.format(payment.paymentTime),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              // 3: PT THANH TOÁN (Payment Method)
              Tooltip(
                // Add tooltip for potentially long method names
                message: payment.paymentMethod,
                child: Text(payment.paymentMethod,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              // 4: TỔNG TIỀN (Amount) - Align Right
              Text(_currencyFormatter.format(payment.amount),
                  textAlign: TextAlign.right),
              // 5: CHI TIẾT (Details Button)
              OutlinedButton(
                onPressed: isLoadingDetails
                    ? null // Disable button while loading details
                    : () async {
                        // Optimistically add to fetching set and show loading indicator
                        if (!mounted) return;
                        setStateIfMounted(() => _fetchingDetailsForPaymentIds
                            .add(payment.paymentId));

                        // Show a temporary snackbar indicating loading
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(theme
                                                .colorScheme
                                                .onSecondary))), // Use onSecondary
                                SizedBox(width: 15),
                                Text(
                                    'Đang tải chi tiết hóa đơn #${payment.paymentId}...',
                                    style: TextStyle(
                                        color: theme.colorScheme
                                            .onSecondary)), // Use onSecondary
                              ],
                            ),
                            duration: Duration(
                                seconds:
                                    30), // Long duration, will be hidden manually
                            backgroundColor: theme.colorScheme.secondary
                                .withOpacity(0.95), // Use secondary color
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            margin: EdgeInsets.all(10), // Add margin
                          ),
                        );

                        try {
                          // Fetch the details
                          final details =
                              await _fetchPaymentDetails(payment.paymentId);
                          // Check mounted AGAIN after await before interacting with context
                          if (!mounted) return;
                          ScaffoldMessenger.of(context)
                              .hideCurrentSnackBar(); // Hide loading snackbar
                          _showPaymentDetailsDialog(
                              context, details); // Show the details dialog
                        } catch (e) {
                          // Check mounted AGAIN after await before interacting with context
                          if (!mounted) return;
                          ScaffoldMessenger.of(context)
                              .hideCurrentSnackBar(); // Hide loading snackbar
                          // Show error snackbar
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Lỗi tải chi tiết: ${e.toString().replaceFirst("Exception: ", "")}'), // Clean up error message
                              backgroundColor: theme.colorScheme.error,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              margin: EdgeInsets.all(10), // Add margin
                            ),
                          );
                        } finally {
                          // Always remove from fetching set, check mounted
                          if (mounted) {
                            setStateIfMounted(() =>
                                _fetchingDetailsForPaymentIds
                                    .remove(payment.paymentId));
                          }
                        }
                      },
                // Style the button to be small and compact
                style: theme.outlinedButtonTheme.style?.copyWith(
                    padding: MaterialStateProperty.all(EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4)), // Compact padding
                    textStyle: MaterialStateProperty.all(theme
                        .textTheme.labelSmall // Use smaller text style
                        ?.copyWith(fontWeight: FontWeight.w500, fontSize: 11)),
                    minimumSize: MaterialStateProperty.all(
                        Size(40, 26))), // Set min size
                child: isLoadingDetails
                    ? SizedBox(
                        // Show a small progress indicator inside the button
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: theme.colorScheme.primary))
                    : const Text('Xem'), // Button text
              ),
            ],
          );
        },
      );
    }

    // Fallback if none of the above conditions are met (should be rare)
    return const SizedBox.shrink();
  }

  // --- Widget xây dựng View cho Lịch Sử ---
  Widget _buildHistoryView(ThemeData theme) {
    final headerBackgroundColor =
        theme.dataTableTheme.headingRowColor?.resolve({}) ??
            Colors.blue.shade100;
    final dividerColor = theme.dividerTheme.color ?? Colors.grey.shade300;
    final dividerThickness = theme.dividerTheme.thickness ?? 1.0;
    final kFilterSpacing = 10.0; // Spacing between filter elements

    // --- Dropdown Items ---
    // Year Dropdown Items
    final List<DropdownMenuItem<int>> yearItems = _years
        .map((year) =>
            DropdownMenuItem<int>(value: year, child: Text(year.toString())))
        .toList();

    // Month Dropdown Items (including "All")
    final List<DropdownMenuItem<int?>> monthItems = [
      const DropdownMenuItem<int?>(value: null, child: Text("Tất cả tháng")),
      ...List.generate(
          12,
          (i) => DropdownMenuItem<int?>(
              value: i + 1, child: Text("Tháng ${i + 1}"))),
    ];

    // Day Dropdown Items (dynamically generated based on selected month/year)
    List<DropdownMenuItem<int?>> dayItems = [
      const DropdownMenuItem<int?>(value: null, child: Text("Tất cả ngày")),
    ];
    if (_selectedHistoryMonth != null && _selectedHistoryYear != null) {
      try {
        // Calculate days in the selected month and year
        final daysInMonth = DateUtils.getDaysInMonth(
            _selectedHistoryYear!, _selectedHistoryMonth!);
        dayItems.addAll(List.generate(
            daysInMonth,
            (i) => DropdownMenuItem<int?>(
                value: i + 1, child: Text("Ngày ${i + 1}"))));
      } catch (e) {
        // Handle potential errors (e.g., invalid month/year combination)
        print("Lỗi tính ngày trong tháng cho bộ lọc: $e");
        // Keep dayItems as just "Tất cả ngày"
      }
    }

    // Determine if the day dropdown should be enabled
    final bool isDayFilterEnabled = _selectedHistoryMonth != null;
    // Determine if the Filter button should be enabled
    final bool isFilterEnabled = _selectedHistoryYear != null &&
        !_isLoadingHistory &&
        !_isLoadingPrevHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter Controls Row
        Padding(
          padding: EdgeInsets.only(bottom: _tableCellHorizontalPadding * 2.5),
          child: Wrap(
            // Use Wrap for responsiveness on smaller screens
            spacing: kFilterSpacing, // Horizontal space between items
            runSpacing: kFilterSpacing, // Vertical space if items wrap
            alignment: WrapAlignment.spaceBetween, // Distribute space
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Left Side: Filter Description Text (Flexible)
              Flexible(
                // Allow text to shrink if needed
                fit: FlexFit.loose,
                child: Text(
                  _isLoadingHistory || _isLoadingPrevHistory
                      ? 'Đang tải lịch sử...'
                      : 'Lọc theo: ${_buildFilterDescription()}',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Right Side: Filter Dropdowns and Button (Grouped)
              Wrap(
                spacing: kFilterSpacing,
                runSpacing: kFilterSpacing,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment:
                    WrapAlignment.end, // Keep filters aligned to the right
                children: [
                  // Year Dropdown
                  _buildHistoryFilterDropdown<int>(
                    theme: theme,
                    value: _selectedHistoryYear ??
                        _years.first, // Default to latest year if null
                    items: yearItems,
                    hintText: 'Năm', // Add hint
                    onChanged: (int? newValue) {
                      if (newValue != null &&
                          newValue != _selectedHistoryYear) {
                        // When year changes, reset month and day, but DON'T auto-trigger fetch yet
                        setState(() {
                          _selectedHistoryYear = newValue;
                          _selectedHistoryMonth = null; // Reset month
                          _selectedHistoryDay = null; // Reset day
                        });
                      }
                    },
                  ),
                  // Month Dropdown
                  _buildHistoryFilterDropdown<int?>(
                    theme: theme,
                    value: _selectedHistoryMonth,
                    items: monthItems,
                    hintText: 'Tháng', // Add hint
                    onChanged: (int? newValue) {
                      // Allow selecting null (All months)
                      if (newValue != _selectedHistoryMonth) {
                        // When month changes, reset day, DON'T auto-trigger fetch
                        setState(() {
                          _selectedHistoryMonth = newValue;
                          _selectedHistoryDay = null; // Reset day
                        });
                      }
                    },
                  ),
                  // Day Dropdown (conditionally enabled)
                  IgnorePointer(
                    ignoring:
                        !isDayFilterEnabled, // Disable pointer events if month not selected
                    child: Opacity(
                      opacity:
                          isDayFilterEnabled ? 1.0 : 0.5, // Dim if disabled
                      child: _buildHistoryFilterDropdown<int?>(
                        theme: theme,
                        value: _selectedHistoryDay,
                        items: dayItems,
                        hintText: 'Ngày', // Add hint
                        onChanged: !isDayFilterEnabled
                            ? null
                            : (int? newValue) {
                                // Allow selecting null (All days)
                                if (newValue != _selectedHistoryDay) {
                                  setState(() {
                                    _selectedHistoryDay = newValue;
                                  });
                                  // Optional: Trigger fetch immediately when day changes?
                                  // _triggerHistoryFetch(); // Uncomment if desired
                                }
                              },
                      ),
                    ),
                  ),
                  // Filter Button
                  ElevatedButton.icon(
                    icon: Icon(Icons.filter_list_rounded,
                        size: 16), // Use rounded icon
                    label: Text('Lọc'),
                    // Disable button if year not selected or if loading
                    onPressed:
                        !isFilterEnabled ? null : () => _triggerHistoryFetch(),
                    style: theme.elevatedButtonTheme.style?.copyWith(
                      // Make button slightly smaller to fit better
                      padding: MaterialStateProperty.all(
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      textStyle: MaterialStateProperty.all(
                          theme.textTheme.labelSmall?.copyWith(
                              color: theme
                                  .colorScheme.onSecondary, // Use theme color
                              fontWeight: FontWeight.w600)),
                      // Visual cue for disabled state
                      backgroundColor:
                          MaterialStateProperty.resolveWith<Color?>(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.disabled)) {
                            return Colors
                                .grey.shade400; // Grey out when disabled
                          }
                          return theme
                              .elevatedButtonTheme.style?.backgroundColor
                              ?.resolve(
                                  states); // Use default theme color otherwise
                        },
                      ),
                      foregroundColor:
                          MaterialStateProperty.resolveWith<Color?>(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.disabled)) {
                            return Colors.grey.shade700;
                          }
                          return theme
                              .elevatedButtonTheme.style?.foregroundColor
                              ?.resolve(states);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // History Payment Table Card
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Table Header
                _buildTableRow(
                  theme: theme,
                  height: _tableHeaderHeight,
                  isHeader: true,
                  backgroundColor: headerBackgroundColor,
                  cells: [
                    Text('MÃ HĐ'),
                    Text('TRẠNG THÁI'),
                    Text('TG THANH TOÁN'),
                    Text('PT THANH TOÁN'),
                    Text('TỔNG TIỀN'),
                    Text('CHI TIẾT'),
                  ],
                ),
                Divider(
                    height: dividerThickness,
                    thickness: dividerThickness,
                    color: dividerColor),
                // Table Body (Scrollable with Refresh)
                Expanded(
                  child: RefreshIndicator(
                    // Enable refresh only if not loading and year is selected
                    onRefresh: (_selectedHistoryYear == null ||
                            _isLoadingHistory ||
                            _isLoadingPrevHistory)
                        ? () async {} // Do nothing if refresh is disabled
                        : () =>
                            _triggerHistoryFetch(), // Call the trigger function
                    color: theme.colorScheme.secondary,
                    backgroundColor: theme.cardTheme.color ?? Colors.white,
                    child: _buildHistoryBillsContent(
                        theme), // Build list or messages
                  ),
                ),
                // Table Footer (Optional, shown only with data)
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
                      Text('MÃ HĐ'),
                      Text('TRẠNG THÁI'),
                      Text('TG THANH TOÁN'),
                      Text('PT THANH TOÁN'),
                      Text('TỔNG TIỀN'),
                      Text('CHI TIẾT'),
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

  // --- Helper to build Dropdown for History Filter ---
  Widget _buildHistoryFilterDropdown<T>({
    required ThemeData theme,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    String? hintText, // Optional hint text
  }) {
    final bool isDisabled =
        (_isLoadingHistory || _isLoadingPrevHistory); // Check if loading

    return Container(
      height: 38, // Consistent height for filter elements
      constraints: BoxConstraints(minWidth: 100), // Minimum width
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          // Use theme's input decoration background or default white
          color: isDisabled
              ? Colors.grey.shade200 // Lighter grey when disabled
              : (theme.inputDecorationTheme.fillColor ?? Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isDisabled
                  ? Colors.grey.shade400
                  : (theme.inputDecorationTheme.enabledBorder?.borderSide
                          .color ??
                      Colors.grey.shade400))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          // Disable onChanged callback if loading
          onChanged: isDisabled ? null : onChanged,
          // Use hint widget if provided and value is null (for nullable types)
          hint: hintText != null && value == null
              ? Text(hintText, style: theme.inputDecorationTheme.hintStyle)
              : null,
          style: theme.textTheme.bodyMedium?.copyWith(
              color: isDisabled
                  ? Colors.grey.shade700
                  : theme.textTheme.bodyMedium
                      ?.color // Dim text color when disabled
              ),
          icon: Icon(Icons.arrow_drop_down_rounded, // Use rounded icon
              size: 20,
              color: isDisabled
                  ? Colors.grey.shade500
                  : theme.iconTheme.color
                      ?.withOpacity(0.7)), // Dim icon when disabled
          isExpanded: false, // Don't expand dropdown itself
          focusColor: Colors.transparent, // Remove focus highlight
          dropdownColor: theme.cardTheme.color ??
              Colors.white, // Background color of the dropdown menu
        ),
      ),
    );
  }

  // --- Helper to create filter description string ---
  String _buildFilterDescription({bool short = false}) {
    if (_selectedHistoryYear == null) return "Chưa chọn năm";

    List<String> parts = [_selectedHistoryYear.toString()]; // Start with year

    if (_selectedHistoryMonth != null) {
      parts.add(
          "T${_selectedHistoryMonth.toString()}"); // Add month like "T1", "T12"
      if (_selectedHistoryDay != null) {
        // Format day with leading zero if needed
        parts.add("Ngày ${_selectedHistoryDay.toString().padLeft(2, '0')}");
      } else if (!short) {
        // Optionally add "All Days" if month is selected but day is not
        // parts.add("Tất cả ngày"); // (Commented out for brevity)
      }
    } else if (!short) {
      // Optionally add "All Months/Days" if only year is selected
      parts.add("Tất cả tháng");
    }

    return parts.join(' / '); // Join parts with a separator
  }

  // --- Helper to build content inside RefreshIndicator for History Bills ---
  Widget _buildHistoryBillsContent(ThemeData theme) {
    final dividerColor = theme.dividerTheme.color ?? Colors.grey.shade300;
    final dividerThickness = theme.dividerTheme.thickness ?? 1.0;

    // --- Handle Loading State ---
    if (_isLoadingHistory && _historicalBills.isEmpty) {
      // Show loading only if list is empty initially
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: CircularProgressIndicator(color: theme.colorScheme.secondary),
      ));
    }

    // --- Handle Error State ---
    if (_historyError != null) {
      return Center(
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              // Use column for icon, text, and retry button
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    color: theme.colorScheme.error, size: 30),
                SizedBox(height: 10),
                Text(_historyError!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center),
                SizedBox(height: 15),
                ElevatedButton.icon(
                    icon: Icon(Icons.refresh, size: 18),
                    label: Text("Thử lại"),
                    onPressed: () => _triggerHistoryFetch(), // Retry fetch
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ))
              ],
            )),
      );
    }

    // --- Handle Empty State (Data loaded, no error, but no bills) ---
    if (!_isLoadingHistory &&
        _historyError == null &&
        _historicalBills.isEmpty) {
      // Use LayoutBuilder and SingleChildScrollView for centering and pull-to-refresh
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics:
              AlwaysScrollableScrollPhysics(), // Enable refresh even when empty
          child: ConstrainedBox(
            constraints:
                BoxConstraints(minHeight: constraints.maxHeight), // Fill height
            child: Center(
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                      'Không tìm thấy hóa đơn nào cho khoảng thời gian\n"${_buildFilterDescription()}".', // Include filter description
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey.shade600),
                      textAlign: TextAlign.center)),
            ),
          ),
        ),
      );
    }

    // --- Display Data Rows ---
    // Build the list only if bills exist and there are no errors
    if (_historicalBills.isNotEmpty && _historyError == null) {
      return ListView.separated(
        physics:
            const AlwaysScrollableScrollPhysics(), // Enable scrolling & refresh
        itemCount: _historicalBills.length,
        separatorBuilder: (context, index) => Divider(
            height: dividerThickness,
            thickness: dividerThickness,
            color: dividerColor.withOpacity(0.6)),
        itemBuilder: (context, index) {
          final payment = _historicalBills[index];
          // Assume status is always 'Hoàn thành' for historical payments
          final statusText = "Hoàn thành";
          // Check if details are being fetched for this specific payment
          final bool isLoadingDetails =
              _fetchingDetailsForPaymentIds.contains(payment.paymentId);

          return _buildTableRow(
            theme: theme,
            height: _tableRowHeight,
            // Apply alternating row color
            backgroundColor: index % 2 != 0 ? _oddRowColor : null,
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
              Tooltip(
                message: payment.paymentMethod,
                child: Text(payment.paymentMethod,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              // 4: TỔNG TIỀN (Align Right)
              Text(_currencyFormatter.format(payment.amount),
                  textAlign: TextAlign.right),
              // 5: CHI TIẾT
              OutlinedButton(
                onPressed: isLoadingDetails
                    ? null
                    : () async {
                        // Similar logic as in shift view for fetching details
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(theme
                                                .colorScheme.onSecondary))),
                                SizedBox(width: 15),
                                Text(
                                    'Đang tải chi tiết hóa đơn #${payment.paymentId}...',
                                    style: TextStyle(
                                        color: theme.colorScheme.onSecondary)),
                              ],
                            ),
                            duration: Duration(seconds: 30),
                            backgroundColor:
                                theme.colorScheme.secondary.withOpacity(0.95),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            margin: EdgeInsets.all(10),
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
                              content: Text(
                                  'Lỗi tải chi tiết: ${e.toString().replaceFirst("Exception: ", "")}'),
                              backgroundColor: theme.colorScheme.error,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              margin: EdgeInsets.all(10),
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setStateIfMounted(() =>
                                _fetchingDetailsForPaymentIds
                                    .remove(payment.paymentId));
                          }
                        }
                      },
                // Style button consistently
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

    // Fallback if none of the above conditions are met
    return const SizedBox.shrink();
  }

  // --- Widget chọn ca (Shift Selector) ---
  Widget _buildShiftSelector(ThemeData theme, double horizontalPadding) {
    // Loading State (while shifts are being fetched)
    if (_isLoadingShifts && _shifts.isEmpty) {
      return Container(
          // Use a fixed height consistent with the final selector height
          height: 45,
          padding: EdgeInsets.symmetric(
              vertical: (45 - 4) / 2), // Center the progress bar vertically
          child: const Center(
              child: LinearProgressIndicator(
                  minHeight: 4))); // Thicker progress bar
    }

    // Error State (if fetching shifts failed)
    if (_shiftError != null && _shifts.isEmpty) {
      return Container(
          height: 45, // Consistent height
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
              child: Text(
            _shiftError!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            textAlign: TextAlign.center,
          )));
    }

    // Empty State (shifts loaded, but the list is empty)
    if (_shifts.isEmpty && !_isLoadingShifts) {
      return Container(
          height: 45, // Consistent height
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
              child: Text("Không có ca trực nào được tìm thấy.",
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey.shade700))));
    }

    // --- Build the Shift Selector List ---
    // Use a fixed-height container to prevent layout jumps
    return Container(
        height: 45, // Consistent height
        child: ListView.separated(
            scrollDirection: Axis.horizontal, // Horizontal scrolling
            itemCount: _shifts.length,
            // Add padding to the sides of the list
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            // Add spacing between shift items
            separatorBuilder: (context, index) =>
                const SizedBox(width: 10), // Increased spacing for Row
            itemBuilder: (context, index) {
              final shift = _shifts[index];
              final bool isSelected = _selectedShiftId == shift.shiftId;
              final formatTime = _timeFormatter;
              final bool isLoading =
                  (_isLoadingShiftPayments || _isLoadingCustomerSummary) &&
                      isSelected; // Check if loading *this* shift's data

              // Combine Chip and Key Icon in a Row
              return Row(
                mainAxisSize: MainAxisSize.min, // Row takes minimum width
                crossAxisAlignment:
                    CrossAxisAlignment.center, // Center items vertically
                children: [
                  // Choice Chip for selecting the shift
                  ChoiceChip(
                    label: Text(
                        'Ca ${formatTime.format(shift.startTime)} - ${formatTime.format(shift.endTime)}'),
                    selected: isSelected,
                    // Disable selection if this shift's data is loading
                    onSelected: isLoading
                        ? null
                        : (selected) {
                            if (selected) {
                              _selectShift(shift.shiftId); // Select this shift
                            }
                          },
                    // Use theme colors, highlight selected
                    selectedColor: theme.colorScheme.secondary,
                    backgroundColor: theme.chipTheme.backgroundColor ??
                        theme.cardTheme.color?.withOpacity(0.7),
                    // Adjust label style based on selection
                    labelStyle: theme.chipTheme.labelStyle?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.onSecondary
                            : theme.chipTheme.labelStyle?.color,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal),
                    // Add time icon as avatar
                    avatar: isLoading // Show spinner if loading this shift
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    isSelected
                                        ? theme.colorScheme.onSecondary
                                        : theme.colorScheme.secondary)))
                        : Icon(Icons.access_time_filled_rounded,
                            size: 14,
                            color: isSelected
                                ? theme.colorScheme.onSecondary.withOpacity(0.8)
                                : theme.chipTheme.labelStyle?.color
                                    ?.withOpacity(0.7)),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact, // Make chip compact
                    shape: theme.chipTheme.shape, // Use theme shape
                    elevation: isSelected ? 1.5 : 0.5,
                    pressElevation: 2.5,
                    materialTapTargetSize: MaterialTapTargetSize
                        .shrinkWrap, // Reduce tap target size
                  ),

                  // Key Icon Button to show secret code
                  SizedBox(width: 4), // Small space between chip and icon
                  IconButton(
                    icon: Icon(Icons.vpn_key_outlined),
                    iconSize: 18, // Small icon
                    color: theme.iconTheme.color?.withOpacity(0.7),
                    tooltip: 'Xem Secret code của ca', // Tooltip
                    visualDensity: VisualDensity.compact, // Compact density
                    padding: EdgeInsets.all(4), // Minimal padding
                    constraints:
                        BoxConstraints(), // Remove extra constraints for size
                    onPressed: () {
                      // Show the secret code dialog for this shift
                      _showSecretCodeDialog(context, shift);
                    },
                  ),
                ],
              );
            }));
  }
} // End of _ManagementScreenState class
