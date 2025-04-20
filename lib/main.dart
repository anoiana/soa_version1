import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart'; // For groupBy
import 'package:intl/intl.dart'; // For date formatting
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:midterm/screens/signInScreen.dart';
// import 'package:midterm/screens/management_screen.dart';
import 'package:shimmer/shimmer.dart'; // Import Shimmer
// import 'management_screen.dart'; // Assuming this exists

// --- Add WebSocket imports ---
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

// --- Constants ---
const double kDefaultPadding = 8.0;
const double kCardElevation = 4.0;
const double kTableGridSpacing = 12.0;
const double kTableItemHeight = 150.0; // Used for visibility calculation
const int kTableGridCrossAxisCountLarge = 5;
const int kTableGridCrossAxisCountSmall = 4;
const int kMenuCategoryButtonCrossAxisCount = 2;
const double kMenuCategoryButtonAspectRatio = 2.5;
const double kMenuItemImageSize = 100.0;
const double kRailWidth = 250.0;
const double kExclamationMarkSize = 35.0; // Consider removing if unused
const double kLogoHeight = 100.0;
const double kBottomActionBarHeight = 60.0;
// --- Add WebSocket URL ---
const String kWebSocketUrl =
    'wss://web-socket-soa-midterm.onrender.com/ws/kitchen'; // Your WebSocket URL

// --- Data Models (MenuItem, KitchenListOrder, KitchenOrderDetailItem) ---
class MenuItem {
  final int itemId;
  final String name;
  final String category;
  final bool available;
  final String? img;
  const MenuItem(
      {required this.itemId,
      required this.name,
      required this.category,
      required this.available,
      this.img});
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
        itemId: json['item_id'] as int? ?? 0,
        name: json['name'] as String? ?? 'Unknown Item',
        category: json['category'] as String? ?? 'Uncategorized',
        available: _parseAvailable(json['available'], json['item_id']),
        img: json['img'] as String?);
  }
  MenuItem copyWith({
    int? itemId,
    String? name,
    String? category,
    bool? available,
    String? img,
  }) {
    return MenuItem(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      category: category ?? this.category,
      available: available ?? this.available,
      img: img ?? this.img,
    );
  }

  static bool _parseAvailable(dynamic value, dynamic id) {
    bool isAvailable = false;
    if (value != null) {
      if (value is bool) {
        isAvailable = value;
      } else if (value is int) {
        isAvailable = value == 1;
      } else if (value is String) {
        String v = value.toLowerCase();
        isAvailable = v == '1' || v == 'true';
      } else {
        print(
            "Warning: Unexpected type for 'available' field: ${value.runtimeType} for item_id: $id");
      }
    }
    return isAvailable;
  }
}

class KitchenListOrder {
  final int orderId;
  final int sessionId;
  final DateTime orderTime;
  int? tableNumber; // Nullable: null = loading, -1 = error, >0 = valid
  KitchenListOrder(
      {required this.orderId,
      required this.sessionId,
      required this.orderTime,
      this.tableNumber});
  factory KitchenListOrder.fromJson(Map<String, dynamic> json) {
    DateTime parsedTime;
    try {
      parsedTime =
          DateTime.tryParse(json['order_time'] as String? ?? '')?.toLocal() ??
              DateTime.now().toLocal();
    } catch (e) {
      print("Error parsing order_time: ${json['order_time']} -> $e");
      parsedTime = DateTime.now().toLocal();
    }
    return KitchenListOrder(
      orderId: json['order_id'] as int? ?? 0,
      sessionId: json['session_id'] as int? ?? 0,
      orderTime: parsedTime,
      // Initialize tableNumber as null, it will be fetched later
    );
  }

  // Add equals and hashCode for Set operations
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KitchenListOrder &&
          runtimeType == other.runtimeType &&
          orderId == other.orderId;

  @override
  int get hashCode => orderId.hashCode;
}

class KitchenOrderDetailItem {
  final int orderItemId;
  final int orderId;
  final int itemId;
  final String name;
  final int quantity;
  String status;
  KitchenOrderDetailItem(
      {required this.orderItemId,
      required this.orderId,
      required this.itemId,
      required this.name,
      required this.quantity,
      required this.status});
  factory KitchenOrderDetailItem.fromJson(Map<String, dynamic> json) {
    return KitchenOrderDetailItem(
      orderItemId: json['order_item_id'] as int? ?? 0,
      orderId: json['order_id'] as int? ?? 0,
      itemId: json['item_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'N/A',
      quantity: json['quantity'] as int? ?? 1,
      status: json['status'] as String? ?? 'unknown',
    );
  }
}

// --- Callback Type Definition ---
typedef OrderUpdateCallback = void Function(
    Map<int, int> pendingOrderCountsByTable);
typedef TableClearedCallback = void Function(int tableNumber);
typedef ThemeChangeCallback = void Function(ThemeMode themeMode);

void main() {
  runApp(MyApp());
}

// --- Stateful MyApp for Theme Management ---
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- Define Base Theme Properties ---
    final TextTheme baseTextTheme = TextTheme(
      bodyMedium: GoogleFonts.lato(fontSize: 14),
      titleMedium:
          GoogleFonts.oswald(fontWeight: FontWeight.w600, fontSize: 16),
      headlineSmall:
          GoogleFonts.oswald(fontWeight: FontWeight.bold, fontSize: 22),
      bodySmall: GoogleFonts.lato(fontSize: 11.5),
      labelLarge: GoogleFonts.lato(fontWeight: FontWeight.bold),
    );

    final CardTheme baseCardTheme = CardTheme(
      elevation: kCardElevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin:
          const EdgeInsets.symmetric(vertical: 5, horizontal: kDefaultPadding),
    );

    final AppBarTheme baseAppBarTheme = AppBarTheme(
      elevation: kCardElevation,
      titleTextStyle: GoogleFonts.oswald(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(blurRadius: 4.0, color: Colors.black45, offset: Offset(2, 2))
        ],
      ),
      centerTitle: true,
    );

    final DialogTheme baseDialogTheme = DialogTheme(
      titleTextStyle:
          GoogleFonts.oswald(fontWeight: FontWeight.bold, fontSize: 19),
      contentTextStyle: GoogleFonts.lato(fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

    final ElevatedButtonThemeData baseElevatedButtonTheme =
        ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.lato(fontWeight: FontWeight.bold),
      ),
    );

    final SegmentedButtonThemeData baseSegmentedButtonTheme =
        SegmentedButtonThemeData(
      style: ButtonStyle(
        side: MaterialStateProperty.all(const BorderSide(width: 0.5)),
        shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
    );

    // --- Define Dark Theme ---
    final ThemeData darkTheme = ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.blueGrey,
      scaffoldBackgroundColor: const Color(0xFF263238),
      fontFamily: GoogleFonts.lato().fontFamily,
      appBarTheme: baseAppBarTheme.copyWith(
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: (baseAppBarTheme.titleTextStyle ?? const TextStyle())
            .copyWith(color: Colors.white),
      ),
      cardTheme: baseCardTheme.copyWith(
        color: const Color(0xFF455A64),
      ),
      dialogTheme: baseDialogTheme.copyWith(
        backgroundColor: const Color(0xFF37474F).withOpacity(0.95),
        titleTextStyle: (baseDialogTheme.titleTextStyle ?? const TextStyle())
            .copyWith(color: Colors.white),
        contentTextStyle:
            (baseDialogTheme.contentTextStyle ?? const TextStyle())
                .copyWith(color: Colors.white70),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style:
              (baseElevatedButtonTheme.style ?? const ButtonStyle()).copyWith(
        foregroundColor: MaterialStateProperty.all(Colors.white),
        backgroundColor: MaterialStateProperty.all(Colors.teal),
      )),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.disabled)) return Colors.grey[700]!;
          return states.contains(MaterialState.selected)
              ? Colors.greenAccent[100]!
              : Colors.redAccent[100]!;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.disabled))
            return Colors.grey[800]!.withOpacity(0.5);
          Color baseColor = states.contains(MaterialState.selected)
              ? Colors.greenAccent[100]!
              : Colors.redAccent[100]!;
          return baseColor.withOpacity(0.4);
        }),
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
      textTheme: baseTextTheme.apply(
          bodyColor: Colors.white.withOpacity(0.85),
          displayColor: Colors.white,
          decorationColor: Colors.white70),
      dividerTheme: const DividerThemeData(
          color: Colors.white24, thickness: 0.8, space: 1),
      shadowColor: Colors.black.withOpacity(0.5),
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: Colors.blueGrey,
        brightness: Brightness.dark,
      ).copyWith(
        secondary: Colors.cyanAccent,
        error: Colors.redAccent[100]!,
        onSurface: Colors.white,
        onBackground: Colors.white,
        onError: Colors.black,
        surface: const Color(0xFF37474F),
        background: const Color(0xFF263238),
        errorContainer: Colors.redAccent[100]?.withOpacity(0.2) ??
            Colors.red.withOpacity(0.2),
        onErrorContainer: Colors.redAccent[100] ?? Colors.red,
      ),
      primaryColorLight: Colors.cyanAccent[100],
      segmentedButtonTheme: baseSegmentedButtonTheme.copyWith(
          style:
              (baseSegmentedButtonTheme.style ?? const ButtonStyle()).copyWith(
        backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected))
            return Colors.blueGrey[700]!;
          return const Color(0xFF37474F);
        }),
        side: MaterialStateProperty.all(
            const BorderSide(color: Colors.white30, width: 0.5)),
        foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) return Colors.white;
          return Colors.white70;
        }),
      )),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: GoogleFonts.lato(color: Colors.grey[500], fontSize: 13),
        prefixIconColor: Colors.grey[500],
        suffixIconColor: Colors.grey[500],
        filled: true,
        fillColor: const Color(0xFF455A64).withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.2), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.2), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide:
              BorderSide(color: Colors.cyanAccent.withOpacity(0.7), width: 1.0),
        ),
      ),
      disabledColor: Colors.grey[600],
    );

    // --- Define Light Theme ---
    final ThemeData lightTheme = ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.blueGrey,
      scaffoldBackgroundColor: Colors.grey[100]!,
      fontFamily: GoogleFonts.lato().fontFamily,
      appBarTheme: baseAppBarTheme.copyWith(
        backgroundColor: Colors.blueGrey[700],
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: (baseAppBarTheme.titleTextStyle ?? const TextStyle())
            .copyWith(color: Colors.white),
      ),
      cardTheme: baseCardTheme.copyWith(
        color: Colors.white,
      ),
      dialogTheme: baseDialogTheme.copyWith(
        backgroundColor: Colors.white.withOpacity(0.98),
        titleTextStyle: (baseDialogTheme.titleTextStyle ?? const TextStyle())
            .copyWith(color: Colors.black87),
        contentTextStyle:
            (baseDialogTheme.contentTextStyle ?? const TextStyle())
                .copyWith(color: Colors.black54),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style:
              (baseElevatedButtonTheme.style ?? const ButtonStyle()).copyWith(
        foregroundColor: MaterialStateProperty.all(Colors.white),
        backgroundColor: MaterialStateProperty.all(Colors.blueGrey[600]),
      )),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color?>((states) {
          if (states.contains(MaterialState.disabled)) {
            return Colors.grey.shade400;
          }
          if (states.contains(MaterialState.selected)) {
            return Colors.blueGrey[600];
          }
          return Colors.grey.shade400;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color?>((states) {
          if (states.contains(MaterialState.disabled)) {
            return Colors.grey.shade400.withOpacity(0.5);
          }
          if (states.contains(MaterialState.selected)) {
            return Colors.blueGrey[600]?.withOpacity(0.5);
          }
          return Colors.grey.shade400.withOpacity(0.5);
        }),
      ),
      iconTheme: IconThemeData(color: Colors.grey[700]),
      textTheme: baseTextTheme.apply(
          bodyColor: Colors.black87,
          displayColor: Colors.black,
          decorationColor: Colors.black54),
      dividerTheme:
          DividerThemeData(color: Colors.grey[400]!, thickness: 0.8, space: 1),
      shadowColor: Colors.black.withOpacity(0.2),
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: Colors.blueGrey,
        brightness: Brightness.light,
      ).copyWith(
        secondary: Colors.teal,
        error: Colors.red[700]!,
        onSurface: Colors.black87,
        onBackground: Colors.black87,
        onError: Colors.white,
        surface: Colors.white,
        background: Colors.grey[100]!,
        errorContainer: Colors.red[100]!,
        onErrorContainer: Colors.red[900]!,
      ),
      primaryColorLight: Colors.teal[100],
      segmentedButtonTheme: baseSegmentedButtonTheme.copyWith(
          style:
              (baseSegmentedButtonTheme.style ?? const ButtonStyle()).copyWith(
        backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected))
            return Colors.blueGrey[100]!;
          return Colors.white;
        }),
        side: MaterialStateProperty.all(
            BorderSide(color: Colors.grey[400]!, width: 0.5)),
        foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected))
            return Colors.blueGrey[800]!;
          return Colors.grey[700]!;
        }),
      )),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: GoogleFonts.lato(color: Colors.grey[500], fontSize: 13),
        prefixIconColor: Colors.grey[500],
        suffixIconColor: Colors.grey[500],
        filled: true,
        fillColor: Colors.white.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.grey[400]!, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.grey[400]!, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide:
              BorderSide(color: Colors.teal.withOpacity(0.8), width: 1.2),
        ),
      ),
      disabledColor: Colors.grey[400],
    );

    // --- Build MaterialApp ---
    return MaterialApp(
      title: 'Restaurant App',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: LoginScreen(),
    );
  }
}

// --- MODIFIED Menu Screen (Accepts Theme Callbacks) ---
class MenuScreen extends StatefulWidget {

  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int selectedIndex = 0;
  bool _isMenuCategoriesExpanded = false;
  List<String> _categories = [];
  Map<String, List<MenuItem>> _menuItemsByCategory = {};
  Map<int, MenuItem> _menuItemsById = {};
  bool _isLoadingMenu = true;
  String? _menuErrorMessage;
  late List<Map<String, dynamic>> tables;
  final ScrollController _tableScrollController = ScrollController();
  final ScrollController _menuScrollController = ScrollController();
  List<GlobalKey> _categoryKeys = [];
  bool _showExclamationMark = false;
  double _exclamationMarkAngle = 0.0;
  final GlobalKey<_KitchenOrderListScreenState> _kitchenListKey = GlobalKey();
  int get orderScreenIndex => _categories.isEmpty ? 1 : _categories.length + 1;
  Map<int, int> _pendingOrderCountsByTable = {};
  int? _hoveredTableIndex;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    tables = List.generate(
      20,
      (index) => {
        'name': 'Bàn ${index + 1}',
        'pendingOrderCount': 0,
        'orders': <Map<String, dynamic>>[],
        'isVisible': false,
      },
    );
    _tableScrollController.addListener(_onTableScroll);
    _searchController.addListener(_onSearchChanged);
    _fetchMenuData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onTableScroll();
    });
  }

  @override
  void dispose() {
    _tableScrollController.removeListener(_onTableScroll);
    _tableScrollController.dispose();
    _menuScrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // --- Search Listener and Clear Method ---
  void _onSearchChanged() {
    if (mounted && _searchQuery != _searchController.text) {
      setState(() {
        _searchQuery = _searchController.text;
      });
    } else if (!mounted) {
      _searchQuery = _searchController.text;
    }
  }

  void _clearSearch() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    } else if (_searchQuery.isNotEmpty) {
      if (mounted) {
        setState(() {
          _searchQuery = "";
        });
      } else {
        _searchQuery = "";
      }
    }
  }

  // --- Data Fetching and State Update Methods ---
  Future<void> _fetchMenuData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMenu = true;
      _menuErrorMessage = null;
    });
    final url = Uri.parse('https://soa-deploy.up.railway.app/menu/');
    try {
      final r = await http.get(url).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (r.statusCode == 200) {
        final List<dynamic> d = jsonDecode(utf8.decode(r.bodyBytes));
        final List<MenuItem> items =
            d.map((i) => MenuItem.fromJson(i as Map<String, dynamic>)).toList();
        final valid = items.where((i) => i.category.isNotEmpty).toList();
        final grouped = groupBy(valid, (MenuItem i) => i.category);
        final uniqueCats = grouped.keys.toList()..sort();
        final keys = List.generate(uniqueCats.length, (_) => GlobalKey());
        final byId = {for (var i in valid) i.itemId: i};
        setState(() {
          _categories = uniqueCats;
          _menuItemsByCategory = grouped;
          _menuItemsById = byId;
          _categoryKeys = keys;
          _isLoadingMenu = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _menuErrorMessage = 'Lỗi tải menu (${r.statusCode})';
          _isLoadingMenu = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      print("Error fetch menu: $e");
      setState(() {
        _menuErrorMessage = 'Không thể tải menu.';
        _isLoadingMenu = false;
      });
    }
  }

  Future<bool> _updateItemStatus(MenuItem item, bool newStatus) async {
    if (!mounted) return false;
    final String itemId = item.itemId.toString();
    if (item.itemId <= 0) {
      return false;
    }
    final url =
        Uri.parse('https://soa-deploy.up.railway.app/menu/$itemId/status')
            .replace(queryParameters: {'available': newStatus.toString()});
    final h = {'Content-Type': 'application/json'};
    print('PATCH ${url.toString()}');
    try {
      final r = await http
          .patch(url, headers: h)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return false;
      print('API Resp: ${r.statusCode}');
      if (r.statusCode == 200 || r.statusCode == 204) {
        print('API OK item ${item.itemId}');
        final u = item.copyWith(available: newStatus);
        final cat = u.category;
        if (_menuItemsByCategory.containsKey(cat)) {
          setState(() {
            final list = _menuItemsByCategory[cat]!;
            final idx = list.indexWhere((i) => i.itemId == item.itemId);
            if (idx != -1) {
              list[idx] = u;
            }
            if (_menuItemsById.containsKey(item.itemId)) {
              _menuItemsById[item.itemId] = u;
            }
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Đã cập nhật: ${item.name} (${newStatus ? "Có sẵn" : "Hết hàng"})'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green[700]));
        }
        return true;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Lỗi cập nhật món. Server: ${r.statusCode}'),
              backgroundColor: Colors.redAccent));
        }
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Lỗi mạng/timeout cập nhật.'),
            backgroundColor: Colors.orangeAccent));
      }
      return false;
    }
  }

  void _updateExclamationMark() {
    if (!mounted ||
        !_tableScrollController.hasClients ||
        !_tableScrollController.position.hasContentDimensions) return;
    final o = _tableScrollController.offset;
    final m = _tableScrollController.position.maxScrollExtent;
    final v = _tableScrollController.position.viewportDimension;
    bool show = m > 0 && (o + v < m - 20);
    double angle = show
        ? (math.pi / 12) *
            math.sin(DateTime.now().millisecondsSinceEpoch / 300.0)
        : 0.0;
    if (_showExclamationMark != show ||
        (_showExclamationMark &&
            (_exclamationMarkAngle - angle).abs() > 0.01)) {
      setState(() {
        _showExclamationMark = show;
        _exclamationMarkAngle = angle;
      });
    }
  }

  void _onTableScroll() {
    if (!mounted ||
        !_tableScrollController.hasClients ||
        !_tableScrollController.position.hasContentDimensions) return;
    final o = _tableScrollController.offset;
    final v = _tableScrollController.position.viewportDimension;
    final c = _getCrossAxisCount(context);
    final h = kTableItemHeight + kTableGridSpacing;
    int r1 = (o / h).floor();
    int r2 = ((o + v - 1) / h).floor();
    int i1 = math.max(0, r1 * c);
    int i2 = math.min(tables.length - 1, (r2 + 1) * c - 1);
    bool changed = false;
    for (int i = 0; i < tables.length; i++) {
      bool vis = (i >= i1 && i <= i2);
      if ((tables[i]['isVisible'] as bool? ?? false) != vis) {
        tables[i]['isVisible'] = vis;
        changed = true;
      }
    }
    if (changed) {
      _updateExclamationMark();
    }
  }

  void _scrollToCategory(int categoryIndex) {
    if (categoryIndex < 1 || categoryIndex > _categories.length) return;
    int arrayIndex = categoryIndex - 1;
    if (arrayIndex >= _categoryKeys.length) return;
    bool needsViewChange = selectedIndex != categoryIndex;
    if (needsViewChange) {
      _clearSearch();
      setState(() {
        selectedIndex = categoryIndex;
        _isMenuCategoriesExpanded = true;
      });
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _performScroll(arrayIndex);
      });
    } else {
      _performScroll(arrayIndex);
    }
  }

  void _performScroll(int arrayIndex) {
    if (!mounted || arrayIndex < 0 || arrayIndex >= _categoryKeys.length)
      return;
    final key = _categoryKeys[arrayIndex];
    final ctx = key.currentContext;
    if (ctx != null) {
      bool isMenu = selectedIndex >= 1 && selectedIndex <= _categories.length;
      if (isMenu) {
        if (_menuScrollController.hasClients &&
            _menuScrollController.position.hasContentDimensions) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              alignment: 0.0);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _menuScrollController.hasClients)
              Scrollable.ensureVisible(ctx,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease);
          });
        }
      }
    } else {
      print("Scroll Fail: Ctx null $arrayIndex.");
    }
  }

  void _showOrderPopup(BuildContext context, int tableIndex) {
    final int targetNum = tableIndex + 1;
    final kitchenState = _kitchenListKey.currentState;
    if (kitchenState != null) {
      kitchenState.showOrdersForTable(context, targetNum);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đang tải DS đơn...'),
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  int _getNavigationRailSelectedIndex() {
    if (selectedIndex == 0) return 0;
    if (selectedIndex == orderScreenIndex) return 1;
    bool isCatSel = selectedIndex >= 1 && selectedIndex <= _categories.length;
    if (isCatSel || _isMenuCategoriesExpanded) return 2;
    return 0;
  }

  int _getCrossAxisCount(BuildContext context) {
    return MediaQuery.of(context).size.width > 1200
        ? kTableGridCrossAxisCountLarge
        : kTableGridCrossAxisCountSmall;
  }

  bool _isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width <= 800;
  }

  void _updateTableOrderCounts(Map<int, int> newCounts) {
    if (!mounted) return;
    bool changed = false;
    _pendingOrderCountsByTable = Map.from(newCounts);
    for (int i = 0; i < tables.length; i++) {
      int num = i + 1;
      int count = newCounts[num] ?? 0;
      int current = tables[i]['pendingOrderCount'] as int? ?? 0;
      if (current != count) {
        tables[i]['pendingOrderCount'] = count;
        changed = true;
      }
    }
    if (changed) {
      print("Update table counts: $newCounts");
      setState(() {});
    }
  }

  void _handleTableCleared(int tableNumber) {
    if (!mounted) return;
    print("Table cleared: $tableNumber");
    int idx = tableNumber - 1;
    if (idx >= 0 && idx < tables.length) {
      if ((tables[idx]['pendingOrderCount'] as int? ?? 0) > 0) {
        setState(() {
          tables[idx]['pendingOrderCount'] = 0;
          _pendingOrderCountsByTable[tableNumber] = 0;
        });
        print("Set pending 0 $tableNumber");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Đơn Bàn $tableNumber hoàn thành!'),
              backgroundColor: Colors.lightGreen[700],
              duration: const Duration(seconds: 3),
            ));
        });
      } else {
        print("Table $tableNumber already 0.");
        if (_pendingOrderCountsByTable[tableNumber] != 0) {
          setState(() {
            _pendingOrderCountsByTable[tableNumber] = 0;
          });
        }
      }
    } else {
      print("Warn: Invalid table# cleared: $tableNumber");
    }
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    final bool smallScreen = _isSmallScreen(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: smallScreen ? _buildAppBar(theme) : null,
      drawer: smallScreen ? _buildAppDrawer(theme) : null,
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: Stack(
          children: [
            Row(
              children: [
                if (!smallScreen) _buildNavigationRail(theme),
                if (!smallScreen)
                  VerticalDivider(
                      width: 1, thickness: 1, color: theme.dividerTheme.color),
                Expanded(
                  child: Column(
                    children: [
                      if (!smallScreen) _buildLargeScreenHeader(theme),
                      if (!smallScreen)
                        Container(height: 0.8, color: theme.dividerTheme.color),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.zero,
                          child: _buildCurrentView(theme),
                        ),
                      ),
                      _buildBottomActionBar(theme),
                    ],
                  ),
                ),
              ],
            ),
            if (selectedIndex == 0 && _showExclamationMark)
              _buildExclamationOverlay(smallScreen),
          ],
        ),
      ),
    );
  }
  AppBar _buildAppBar(ThemeData theme) {
    return AppBar(
      title: const Text('BẾP'),
      actions: [
        ..._buildAppBarActions(theme), // Các actions hiện có
        // Nút thoát
        IconButton(
          icon: Icon(Icons.exit_to_app, color: theme.iconTheme.color),
          tooltip: 'Thoát',
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LoginScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLargeScreenHeader(ThemeData theme) {
    return Container(
      color: theme.appBarTheme.backgroundColor,
      padding: const EdgeInsets.symmetric(
          horizontal: kDefaultPadding * 2, vertical: kDefaultPadding * 1.5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'BẾP',
              textAlign: TextAlign.center,
              style: theme.appBarTheme.titleTextStyle,
            ),
          ),
          ..._buildAppBarActions(theme), // Các actions hiện có
          // Nút thoát
          IconButton(
            icon: Icon(Icons.exit_to_app, color: theme.iconTheme.color),
            tooltip: 'Thoát',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => LoginScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions(ThemeData theme) {
    return [
      IconButton(
        icon: const Icon(Icons.person_outline),
        tooltip: 'Tài khoản',
        onPressed: () {},
        color: theme.appBarTheme.actionsIconTheme?.color,
      ),
      const SizedBox(width: kDefaultPadding / 2),
    ];
  }
  

  Widget _buildAppDrawer(ThemeData theme) {
    bool isMenuSelected =
        selectedIndex >= 1 && selectedIndex <= _categories.length;
    Color highlight = theme.colorScheme.secondary;
    final divider = Divider(
      color: theme.dividerTheme.color?.withOpacity(0.5),
      thickness: theme.dividerTheme.thickness,
      height: kDefaultPadding * 1.5,
      indent: kDefaultPadding * 2,
      endIndent: kDefaultPadding * 2,
    );
    return Drawer(
      backgroundColor: theme.dialogTheme.backgroundColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.cardTheme.color?.withOpacity(0.8),
              border: Border(
                  bottom: BorderSide(
                      color: theme.dividerTheme.color ?? Colors.white12,
                      width: 0.5)),
            ),
            child: Center(child: _buildLogo()),
          ),
          _buildDrawerItem(theme, Icons.table_restaurant_outlined, 'Bàn ăn', 0,
              selectedIndex, highlight, () {
            _clearSearch();
            setState(() {
              selectedIndex = 0;
              _isMenuCategoriesExpanded = false;
              Navigator.pop(context);
            });
          }),
          divider,
          _buildDrawerItem(theme, Icons.receipt_long_outlined, 'Đơn hàng',
              orderScreenIndex, selectedIndex, highlight, () {
            _clearSearch();
            setState(() {
              selectedIndex = orderScreenIndex;
              _isMenuCategoriesExpanded = false;
              Navigator.pop(context);
            });
          }),
          divider,
          ExpansionTile(
            leading: Icon(Icons.restaurant_menu_outlined,
                color: isMenuSelected ? highlight : theme.iconTheme.color,
                size: 24),
            title: Text('Món ăn',
                style:
                    (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
                  color: isMenuSelected
                      ? highlight
                      : theme.textTheme.bodyMedium?.color,
                  fontWeight:
                      isMenuSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14.5,
                )),
            initiallyExpanded: _isMenuCategoriesExpanded,
            onExpansionChanged: (expanded) {
              if (!_isLoadingMenu && _menuErrorMessage == null) {
                setState(() => _isMenuCategoriesExpanded = expanded);
              } else if (expanded) {
                /* ... show error ... */ Future.delayed(Duration.zero, () {
                  if (mounted)
                    setState(() => _isMenuCategoriesExpanded = false);
                });
              }
            },
            iconColor: theme.iconTheme.color,
            collapsedIconColor: theme.iconTheme.color?.withOpacity(0.7),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: kDefaultPadding * 2, vertical: kDefaultPadding),
                child: _isLoadingMenu
                    ? Center(
                        child: CircularProgressIndicator(
                            color: theme.colorScheme.secondary))
                    : _menuErrorMessage != null
                        ? Center(
                            child: Text(_menuErrorMessage!,
                                style:
                                    TextStyle(color: theme.colorScheme.error)))
                        : _categories.isEmpty
                            ? Center(
                                child: Text("Chưa có danh mục.",
                                    style: theme.textTheme.bodySmall))
                            : _buildCategoryButtonGrid(theme, true),
              ),
            ],
          ),
          divider,
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
      ThemeData theme,
      IconData icon,
      String title,
      int indexValue,
      int currentIndex,
      Color highlightColor,
      VoidCallback onTapAction) {
    bool isSelected = currentIndex == indexValue;
    final drawerItemStyle =
        theme.textTheme.bodyMedium?.copyWith(fontSize: 14.5);
    return ListTile(
      leading: Icon(icon,
          color: isSelected
              ? highlightColor
              : theme.iconTheme.color?.withOpacity(0.8),
          size: 24),
      title: Text(
        title,
        style: (drawerItemStyle ?? const TextStyle()).copyWith(
          color:
              isSelected ? highlightColor : theme.textTheme.bodyMedium?.color,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      onTap: onTapAction,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.secondary.withOpacity(0.15),
      hoverColor: theme.colorScheme.secondary.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: kDefaultPadding * 2.5),
      dense: true,
    );
  }

  Widget _buildNavigationRail(ThemeData theme) {
    final Color selectedColor = theme.colorScheme.secondary;
    final Color unselectedFGColor =
        theme.colorScheme.onSurface.withOpacity(0.7);
    final railLabelStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: 15.5,
      letterSpacing: 0.3,
    );
    final int currentRailIndex = _getNavigationRailSelectedIndex();
    final destinationsData = [
      {
        'icon': Icons.table_restaurant_outlined,
        'label': 'Danh sách bàn ăn',
        'index': 0
      },
      {
        'icon': Icons.receipt_long_outlined,
        'label': 'Danh sách đơn hàng',
        'index': 1
      },
      {
        'icon': Icons.restaurant_menu_outlined,
        'label': 'Danh sách món ăn',
        'index': 2
      },
    ];
    List<Widget> destinationsWidgets = [];
    for (int i = 0; i < destinationsData.length; i++) {
      final data = destinationsData[i];
      final bool isSelected = currentRailIndex == (data['index'] as int);
      destinationsWidgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: kDefaultPadding * 0.5),
        child: InkWell(
          onTap: () => _handleDestinationSelected(data['index'] as int),
          borderRadius: BorderRadius.circular(10),
          splashColor: selectedColor.withOpacity(0.1),
          highlightColor: selectedColor.withOpacity(0.05),
          hoverColor: selectedColor.withOpacity(0.08),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? selectedColor.withOpacity(0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(
                vertical: kDefaultPadding * 1.5, horizontal: kDefaultPadding),
            child: Row(
              children: [
                const SizedBox(width: kDefaultPadding * 1.5),
                Icon(
                  data['icon'] as IconData,
                  color: isSelected
                      ? selectedColor
                      : theme.iconTheme.color?.withOpacity(0.8),
                  size: isSelected ? 30 : 28,
                ),
                const SizedBox(width: kDefaultPadding * 1.5),
                Flexible(
                  child: Text(
                    data['label'] as String,
                    style: (isSelected
                            ? railLabelStyle?.copyWith(
                                color: selectedColor,
                                fontWeight: FontWeight.w600)
                            : railLabelStyle?.copyWith(
                                color: unselectedFGColor,
                                fontWeight: FontWeight.w500)) ??
                        const TextStyle(),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
      if (i < destinationsData.length - 1) {
        destinationsWidgets.add(Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: kDefaultPadding * 1.5,
              vertical: kDefaultPadding * 0.5),
          child: Divider(
            color: theme.dividerTheme.color?.withOpacity(0.5),
            height: 1,
            thickness: 1,
          ),
        ));
      }
    }
    return Container(
      width: kRailWidth,
      color: theme.dialogTheme.backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: kDefaultPadding * 2.5),
          Padding(
            padding: const EdgeInsets.only(left: kDefaultPadding * 2),
            child: _buildLogo(),
          ),
          const SizedBox(height: kDefaultPadding * 3.5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: destinationsWidgets,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: (_isMenuCategoriesExpanded &&
                    !_isLoadingMenu &&
                    _menuErrorMessage == null &&
                    _categories.isNotEmpty)
                ? Flexible(
                    child: Container(
                      margin: const EdgeInsets.only(top: kDefaultPadding),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(kDefaultPadding, 0,
                            kDefaultPadding, kDefaultPadding * 2),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: kDefaultPadding * 1.5),
                            child: _buildCategoryButtonGrid(theme, false),
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _handleDestinationSelected(int index) {
    setState(() {
      if (index == 0) {
        _clearSearch();
        selectedIndex = 0;
        _isMenuCategoriesExpanded = false;
      } else if (index == 1) {
        _clearSearch();
        selectedIndex = orderScreenIndex;
        _isMenuCategoriesExpanded = false;
      } else if (index == 2) {
        if (_isLoadingMenu || _menuErrorMessage != null) {
          /* ... show error ... */ return;
        }
        _isMenuCategoriesExpanded = !_isMenuCategoriesExpanded;
        if (_isMenuCategoriesExpanded) {
          bool isViewingTablesOrOrders =
              (selectedIndex == 0 || selectedIndex == orderScreenIndex);
          bool noCategorySelected =
              !(selectedIndex >= 1 && selectedIndex <= _categories.length);
          if ((isViewingTablesOrOrders || noCategorySelected) &&
              _categories.isNotEmpty) {
            _clearSearch();
            selectedIndex = 1;
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && _isMenuCategoriesExpanded) {
                _scrollToCategory(1);
              }
            });
          }
        } else {
          if (selectedIndex >= 1 && selectedIndex <= _categories.length) {
            _clearSearch();
          }
        }
        if (_isMenuCategoriesExpanded && _categories.isEmpty) {
          /* ... show error ... */ _isMenuCategoriesExpanded = false;
        }
      }
    });
  }

  Widget _buildLogo({double height = kLogoHeight, double? width}) {
    const String logoAssetPath = 'image.png';
    return ClipRRect(
      borderRadius: BorderRadius.circular(kDefaultPadding * 0.75),
      child: Image.asset(
        logoAssetPath,
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => Container(
            height: height,
            width: width ?? height * 1.8,
            color: Colors.grey[700],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined,
                    color: Colors.red[300], size: height * 0.5),
                const SizedBox(height: 4),
                Text("Logo Error",
                    style: TextStyle(color: Colors.red[300], fontSize: 10))
              ],
            )),
        frameBuilder: (c, child, frame, wasSync) => wasSync
            ? child
            : AnimatedOpacity(
                child: child,
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut),
      ),
    );
  }

  Widget _buildTableGrid(ThemeData theme) {
    int crossAxisCount = _getCrossAxisCount(context);
    return GridView.builder(
      key: const PageStorageKey<String>('tableGrid'),
      padding: const EdgeInsets.all(kDefaultPadding * 1.8),
      controller: _tableScrollController,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: kTableGridSpacing * 1.4,
        mainAxisSpacing: kTableGridSpacing * 1.4,
        childAspectRatio: 1.0,
      ),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        int pendingCount = table['pendingOrderCount'] as int? ?? 0;
        bool hasPending = pendingCount > 0;
        bool isHovered = _hoveredTableIndex == index;
        Color cardBg,
            iconColor,
            textColor,
            badgeColor = theme.colorScheme.error,
            badgeTextColor = theme.colorScheme.onError,
            borderColor = Colors.transparent;
        double elevation = kCardElevation;
        if (hasPending) {
          cardBg = Color.lerp(
              theme.cardTheme.color ?? theme.colorScheme.surface,
              theme.colorScheme.errorContainer ??
                  theme.colorScheme.error.withOpacity(0.2),
              0.6)!;
          iconColor = theme.colorScheme.error;
          textColor =
              theme.colorScheme.onErrorContainer ?? theme.colorScheme.error;
          borderColor = theme.colorScheme.error.withOpacity(0.8);
          elevation = kCardElevation + 4;
        } else {
          cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
          iconColor = theme.iconTheme.color?.withOpacity(0.65) ?? Colors.grey;
          textColor = (theme.textTheme.bodyMedium?.color ?? Colors.white)
              .withOpacity(0.85);
        }
        if (isHovered) {
          cardBg = Color.alphaBlend(
              theme.colorScheme.secondary.withOpacity(0.1), cardBg);
          borderColor = hasPending
              ? theme.colorScheme.error
              : theme.colorScheme.secondary.withOpacity(0.7);
          elevation += 4;
        }
        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredTableIndex = index),
          onExit: (_) => setState(() => _hoveredTableIndex = null),
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(isHovered ? 0.4 : 0.2),
                  blurRadius: isHovered ? 10 : 5,
                  spreadRadius: 0,
                  offset: Offset(0, isHovered ? 4 : 2),
                )
              ],
            ),
            child: Material(
              color: cardBg,
              borderRadius: BorderRadius.circular(13),
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              child: InkWell(
                onTap: () => _showOrderPopup(context, index),
                borderRadius: BorderRadius.circular(13),
                splashColor: theme.colorScheme.secondary.withOpacity(0.15),
                highlightColor: theme.colorScheme.secondary.withOpacity(0.1),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(kDefaultPadding * 1.2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.table_restaurant_rounded,
                            size: 55,
                            color: iconColor,
                          ),
                          const SizedBox(height: kDefaultPadding * 1.5),
                          Text(
                            table['name'] as String? ?? 'Bàn ?',
                            style: (theme.textTheme.titleMedium ??
                                    const TextStyle())
                                .copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (hasPending)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(6.5),
                          decoration: BoxDecoration(
                              color: badgeColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: theme.colorScheme.surface
                                      .withOpacity(0.9),
                                  width: 1.8),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 5,
                                    offset: const Offset(1, 1))
                              ]),
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                          child: Center(
                              child: Text('$pendingCount',
                                  style: TextStyle(
                                    color: badgeTextColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ))),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedMenuCategoryList(ThemeData theme) {
    int catIdx = selectedIndex - 1;
    if (catIdx < 0 || catIdx >= _categories.length) {
      return Center(
          child: Text("Danh mục không hợp lệ.",
              style: theme.textTheme.bodyMedium));
    }
    if (catIdx >= _categoryKeys.length) {
      return Center(
          child: Text("Đang chuẩn bị...", style: theme.textTheme.bodySmall));
    }
    final String catName = _categories[catIdx];
    final List<MenuItem> allItems = _menuItemsByCategory[catName] ?? [];
    final GlobalKey catKey = _categoryKeys[catIdx];
    final String query = _searchQuery.toLowerCase().trim();
    final List<MenuItem> filteredItems = query.isEmpty
        ? allItems
        : allItems
            .where((i) =>
                i.name.toLowerCase().contains(query) ||
                i.itemId.toString().contains(query))
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          key: catKey,
          padding: const EdgeInsets.fromLTRB(
              kDefaultPadding * 2,
              kDefaultPadding * 1.5,
              kDefaultPadding * 2,
              kDefaultPadding * 0.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  catName,
                  style: theme.textTheme.headlineSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: kDefaultPadding * 1.5),
              SizedBox(
                width: 250,
                height: 40,
                child: TextField(
                  controller: _searchController,
                  style: (theme.textTheme.bodyMedium ?? const TextStyle())
                      .copyWith(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Tìm món (tên, ID)...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18),
                            tooltip: 'Xóa',
                            splashRadius: 15,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _clearSearch,
                          )
                        : null,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding * 2),
          child: Divider(
              color: theme.dividerTheme.color,
              thickness: theme.dividerTheme.thickness),
        ),
        const SizedBox(height: kDefaultPadding),
        if (allItems.isEmpty)
          Expanded(
              child: Center(
            child: Padding(
              padding: const EdgeInsets.all(kDefaultPadding * 2),
              child: Text(
                "Không có món nào trong '$catName'.",
                style: (theme.textTheme.bodyMedium ?? const TextStyle())
                    .copyWith(
                        color: theme.textTheme.bodyMedium?.color
                            ?.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
            ),
          ))
        else if (filteredItems.isEmpty && query.isNotEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(kDefaultPadding * 2),
                child: Text(
                  "Không tìm thấy món khớp \"$query\".",
                  style: (theme.textTheme.bodyMedium ?? const TextStyle())
                      .copyWith(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.7)),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              key: PageStorageKey<String>('menuList_${catName}_$query'),
              controller: _menuScrollController,
              padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
              itemCount: filteredItems.length,
              itemBuilder: (context, itemIndex) {
                MenuItem current = filteredItems[itemIndex];
                MenuItem item = _menuItemsById[current.itemId] ?? current;
                String? imgPath = item.img;
                Widget imgWidget;
                if (imgPath != null && imgPath.isNotEmpty) {
                  String asset = 'assets/' +
                      (imgPath.startsWith('/')
                          ? imgPath.substring(1)
                          : imgPath);
                  imgWidget = Image.asset(asset,
                      width: kMenuItemImageSize,
                      height: kMenuItemImageSize,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) =>
                          _buildPlaceholderImage(hasError: true),
                      frameBuilder: (c, child, frame, wasSync) => wasSync
                          ? child
                          : AnimatedOpacity(
                              opacity: frame == null ? 0 : 1,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOut,
                              child: child,
                            ));
                } else {
                  imgWidget = _buildPlaceholderImage();
                }
                return Card(
                  margin: const EdgeInsets.only(bottom: kDefaultPadding * 1.5),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        child: imgWidget,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: kDefaultPadding * 1.2,
                              horizontal: kDefaultPadding * 1.8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.name,
                                style: (theme.textTheme.titleMedium ??
                                        const TextStyle())
                                    .copyWith(fontSize: 16.5),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: kDefaultPadding * 0.6),
                              Text(
                                "ID: ${item.itemId}",
                                style: (theme.textTheme.bodySmall ??
                                        const TextStyle())
                                    .copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.only(right: kDefaultPadding * 1.5),
                        child: AvailabilitySwitch(
                          item: item,
                          onStatusChanged: _updateItemStatus,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholderImage({bool hasError = false}) {
    final theme = Theme.of(context);
    return Container(
      width: kMenuItemImageSize,
      height: kMenuItemImageSize,
      color: theme.cardTheme.color?.withOpacity(0.5) ??
          theme.colorScheme.surface.withOpacity(0.5),
      child: Icon(
        hasError ? Icons.image_not_supported_outlined : Icons.restaurant,
        color: hasError
            ? theme.colorScheme.error.withOpacity(0.7)
            : theme.iconTheme.color?.withOpacity(0.4),
        size: kMenuItemImageSize * 0.4,
      ),
    );
  }

  Widget _buildBottomActionBar(ThemeData theme) {
    final footerTextStyle =
        (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
      color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
      fontSize: 11.5,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
    );
    return Container(
      height: kBottomActionBarHeight * 0.7,
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: theme.dividerTheme.color ?? Colors.white24, width: 0.5)),
      ),
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.only(bottom: kDefaultPadding * 0.5),
          child: Text(
            'SOA Midterm by REAL MEN',
            style: footerTextStyle,
          ),
        ),
      ),
    );
  }

  Widget _buildExclamationOverlay(bool smallScreen) {
    final theme = Theme.of(context);
    if (!_showExclamationMark) return const SizedBox.shrink();
    double rightEdge =
        smallScreen ? kDefaultPadding : kRailWidth + kDefaultPadding;
    const String assetPath = 'assets/exclamation_mark.png';
    return Positioned(
      right: rightEdge - kExclamationMarkSize / 2,
      top: MediaQuery.of(context).size.height / 2 - kExclamationMarkSize / 2,
      child: Transform.rotate(
        angle: _exclamationMarkAngle,
        child: IgnorePointer(
            child: Image.asset(
          assetPath,
          width: kExclamationMarkSize,
          height: kExclamationMarkSize,
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => Icon(Icons.warning_amber_rounded,
              color: theme.colorScheme.secondary, size: kExclamationMarkSize),
        )),
      ),
    );
  }

  Widget _buildCategoryButtonGrid(ThemeData theme, bool isDrawer) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: kMenuCategoryButtonCrossAxisCount,
        crossAxisSpacing: kDefaultPadding,
        mainAxisSpacing: kDefaultPadding,
        childAspectRatio: kMenuCategoryButtonAspectRatio,
      ),
      itemCount: _categories.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final catIdx = index + 1;
        final isSel = selectedIndex == catIdx;
        final catName = _categories[index];
        final selBg = theme.colorScheme.secondary.withOpacity(0.9);
        final unselBg = theme.cardTheme.color?.withOpacity(0.9) ??
            theme.colorScheme.surface;
        final selBorder = theme.colorScheme.secondary;
        final hover = theme.colorScheme.secondary.withOpacity(0.15);
        final splash = theme.colorScheme.secondary.withOpacity(0.25);
        final shadow = theme.shadowColor.withOpacity(isSel ? 0.3 : 0.15);
        const animDur = Duration(milliseconds: 250);
        Color fgColor = theme.colorScheme.onSecondary;
        if (!isSel) {
          fgColor = theme.colorScheme.onSurface.withOpacity(0.9);
        }
        return AnimatedContainer(
          duration: animDur,
          curve: Curves.easeInOutCubic,
          margin: EdgeInsets.all(isSel ? 0 : 2.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.0),
            boxShadow: [
              BoxShadow(
                  color: shadow,
                  blurRadius: isSel ? 8.0 : 4.0,
                  offset: Offset(0, isSel ? 4.0 : 2.0))
            ],
          ),
          child: ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith<Color>((s) {
                if (s.contains(MaterialState.pressed))
                  return splash.withOpacity(0.4);
                return isSel ? selBg : unselBg;
              }),
              foregroundColor: MaterialStateProperty.all<Color>(fgColor),
              overlayColor: MaterialStateProperty.resolveWith<Color?>((s) {
                if (s.contains(MaterialState.hovered)) return hover;
                return null;
              }),
              shadowColor: MaterialStateProperty.all(Colors.transparent),
              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      side: BorderSide(
                          color: isSel ? selBorder : Colors.transparent,
                          width: 1.5))),
              padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                  const EdgeInsets.symmetric(
                      horizontal: kDefaultPadding,
                      vertical: kDefaultPadding * 0.75)),
              minimumSize: MaterialStateProperty.all(const Size(0, 40)),
              splashFactory: NoSplash.splashFactory,
              elevation: MaterialStateProperty.all(0),
            ),
            onPressed: () {
              _clearSearch();
              _scrollToCategory(catIdx);
              if (isDrawer) Navigator.pop(context);
            },
            child: AnimatedDefaultTextStyle(
              duration: animDur,
              style: (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
                color: fgColor,
                fontSize: 13.5,
                fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: isSel ? 0.4 : 0.2,
              ),
              child: Text(
                catName,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentView(ThemeData theme) {
    int stackIndex = 0;
    if (selectedIndex == orderScreenIndex)
      stackIndex = 1;
    else if (selectedIndex >= 1 && selectedIndex <= _categories.length)
      stackIndex = 2;
    List<Widget> pages = [
      _buildTableGrid(theme),
      KitchenOrderListScreen(
        key: _kitchenListKey,
        onOrderUpdate: _updateTableOrderCounts,
        onTableCleared: _handleTableCleared,
      ),
      Builder(builder: (context) {
        bool isMenu = selectedIndex >= 1 && selectedIndex <= _categories.length;
        if (isMenu) {
          if (_isLoadingMenu)
            return Center(
                child: CircularProgressIndicator(
                    color: theme.colorScheme.secondary));
          if (_menuErrorMessage != null)
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off_outlined,
                        color: theme.colorScheme.error, size: 50),
                    const SizedBox(height: kDefaultPadding * 2),
                    Text(_menuErrorMessage!,
                        textAlign: TextAlign.center,
                        style: (theme.textTheme.bodyMedium ?? const TextStyle())
                            .copyWith(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.7))),
                    const SizedBox(height: kDefaultPadding * 2),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.errorContainer,
                          foregroundColor: theme.colorScheme.onErrorContainer),
                      onPressed: _fetchMenuData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    )
                  ]),
            ));
          if (_categories.isEmpty && !_isLoadingMenu)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(kDefaultPadding * 2),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book_outlined,
                          color: theme.iconTheme.color?.withOpacity(0.5),
                          size: 50),
                      const SizedBox(height: kDefaultPadding * 2),
                      Text("Không có danh mục.",
                          textAlign: TextAlign.center,
                          style:
                              (theme.textTheme.bodyMedium ?? const TextStyle())
                                  .copyWith(
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.7))),
                      const SizedBox(height: kDefaultPadding * 2),
                      ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  theme.colorScheme.secondary.withOpacity(0.8)),
                          onPressed: _fetchMenuData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tải lại Menu'))
                    ]),
              ),
            );
          if (stackIndex == 2) return _buildSelectedMenuCategoryList(theme);
        }
        return Container();
      }),
    ];
    return IndexedStack(
      index: stackIndex,
      children: pages,
    );
  }
} // End of _MenuScreenState

// --- Availability Switch Widget ---
class AvailabilitySwitch extends StatefulWidget {
  final MenuItem item;
  final Future<bool> Function(MenuItem item, bool newValue) onStatusChanged;
  const AvailabilitySwitch({
    Key? key,
    required this.item,
    required this.onStatusChanged,
  }) : super(key: key);
  @override
  _AvailabilitySwitchState createState() => _AvailabilitySwitchState();
}

class _AvailabilitySwitchState extends State<AvailabilitySwitch> {
  bool _isUpdating = false;
  late bool _optimisticValue;
  @override
  void initState() {
    super.initState();
    _optimisticValue = widget.item.available;
  }

  @override
  void didUpdateWidget(covariant AvailabilitySwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.available != oldWidget.item.available &&
        widget.item.available != _optimisticValue &&
        !_isUpdating) {
      if (mounted) setState(() => _optimisticValue = widget.item.available);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final switchTheme = theme.switchTheme;
    bool displayValue = _optimisticValue;
    Color statusColor = _isUpdating
        ? theme.disabledColor
        : (displayValue
            ? (theme.brightness == Brightness.dark
                ? Colors.greenAccent[100]!
                : Colors.green[700]!)
            : (theme.brightness == Brightness.dark
                ? Colors.redAccent[100]!
                : Colors.red[700]!));
    String statusText = _isUpdating ? '...' : (displayValue ? 'Có sẵn' : 'Hết');
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 35,
          width: 55,
          child: Center(
            child: _isUpdating
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.secondary)))
                : Switch(
                    value: displayValue,
                    onChanged: (newValue) async {
                      setState(() {
                        _optimisticValue = newValue;
                        _isUpdating = true;
                      });
                      bool success =
                          await widget.onStatusChanged(widget.item, newValue);
                      if (mounted) {
                        setState(() {
                          if (!success) {
                            _optimisticValue = !newValue;
                          }
                          _isUpdating = false;
                        });
                      } else {
                        print("Switch unmounted ${widget.item.name}");
                      }
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: switchTheme.thumbColor
                        ?.resolve({MaterialState.selected}),
                    inactiveThumbColor: switchTheme.thumbColor?.resolve({}),
                    activeTrackColor: switchTheme.trackColor
                        ?.resolve({MaterialState.selected}),
                    inactiveTrackColor: switchTheme.trackColor?.resolve({}),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          statusText,
          style: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
            fontSize: 10.5,
            color: statusColor,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
        )
      ],
    );
  }
}

// --- Enum OrderListView ---
enum OrderListView { pending, completed }

// --- OPTIMIZED Kitchen Order List Screen ---
class KitchenOrderListScreen extends StatefulWidget {
  final OrderUpdateCallback? onOrderUpdate;
  final TableClearedCallback? onTableCleared;
  const KitchenOrderListScreen(
      {Key? key, this.onOrderUpdate, this.onTableCleared})
      : super(key: key);
  @override
  State<KitchenOrderListScreen> createState() => _KitchenOrderListScreenState();
}

class _KitchenOrderListScreenState extends State<KitchenOrderListScreen>
    with AutomaticKeepAliveClientMixin {
  // --- State variables ---
  final ValueNotifier<List<KitchenListOrder>> _pendingOrdersNotifier =
      ValueNotifier([]);
  List<KitchenListOrder> get _pendingOrders => _pendingOrdersNotifier.value;
  set _pendingOrders(List<KitchenListOrder> newList) {
    _pendingOrdersNotifier.value = newList;
  }

  List<KitchenListOrder> _completedOrders = [];
  bool _isLoadingPending = true;
  bool _isBackgroundLoading = false;
  String? _pendingErrorMessage;
  bool _isLoadingCompleted = false;
  String? _completedErrorMessage;
  bool _completedOrdersLoaded = false;
  OrderListView _currentView = OrderListView.pending;
  final Set<int> _inProgressOrderIds = {};
  bool _isDetailLoading = false;
  String? _detailErrorMessage;
  List<KitchenOrderDetailItem> _detailItems = [];
  final Set<int> _updatingItemIds = {};
  bool _isCompletingAll = false;
  final Map<int, int?> _tableNumberCache = {};
  final Set<int> _fetchingTableSessionIds = {};
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 10;
  final Duration _initialReconnectDelay = const Duration(seconds: 3);
  final Duration _maxReconnectDelay = const Duration(minutes: 1);
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  List<KitchenListOrder> _filteredPendingOrders = [];
  List<KitchenListOrder> _filteredCompletedOrders = [];
  bool _isHandlingWebSocketUpdate = false;

  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    print("KitchenOrderListScreen initState");
    _searchController.addListener(_onSearchChanged);
    _pendingOrdersNotifier.addListener(_onPendingOrdersChanged);
    _fetchPendingOrders();
    _connectWebSocket();
  }

  void _onPendingOrdersChanged() {
    if (mounted) {
      setState(() {
        _updateFilteredLists();
      });
    }
  }

  @override
  void dispose() {
    print("KitchenOrderListScreen dispose");
    _pendingOrdersNotifier.removeListener(_onPendingOrdersChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _disconnectWebSocket();
    _reconnectTimer?.cancel();
    _pendingOrdersNotifier.dispose();
    super.dispose();
  }

  // --- Search & Filter ---
  void _onSearchChanged() {
    if (mounted && _searchQuery != _searchController.text) {
      setState(() {
        _searchQuery = _searchController.text;
        _updateFilteredLists();
      });
    } else if (!mounted) {
      _searchQuery = _searchController.text;
    }
  }

  void _clearSearch() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    } else if (_searchQuery.isNotEmpty) {
      if (mounted) {
        setState(() {
          _searchQuery = "";
          _updateFilteredLists();
        });
      } else {
        _searchQuery = "";
      }
    }
  }

  void _updateFilteredLists() {
    final query = _searchQuery.toLowerCase().trim();
    if (query.isEmpty) {
      _filteredPendingOrders = List.from(_pendingOrders);
      _filteredCompletedOrders = List.from(_completedOrders);
    } else {
      _filteredPendingOrders = _pendingOrders.where((o) {
        final t = o.tableNumber?.toString() ?? "";
        final id = o.orderId.toString();
        return id.contains(query) ||
            (o.tableNumber != null && o.tableNumber! > 0 && t.contains(query));
      }).toList();
      _filteredCompletedOrders = _completedOrders.where((o) {
        final t = o.tableNumber?.toString() ?? "";
        final id = o.orderId.toString();
        return id.contains(query) ||
            (o.tableNumber != null && o.tableNumber! > 0 && t.contains(query));
      }).toList();
    }
    print(
        "Filtering done. Q:'$query'. P:${_filteredPendingOrders.length}, C:${_filteredCompletedOrders.length}");
  }

  // --- WebSocket ---
  void _connectWebSocket() {
    if (_isConnecting || _isConnected || _channel != null) return;
    if (!mounted) return;
    setState(() {
      _isConnecting = true;
    });
    print("WS: Connect $kWebSocketUrl...");
    try {
      _channel = WebSocketChannel.connect(Uri.parse(kWebSocketUrl));
      _isConnected = false;
      if (!mounted) {
        _channel?.sink.close(status.goingAway);
        _channel = null;
        _isConnecting = false;
        return;
      }
      print("WS: OK, listening...");
      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _reconnectAttempts = 0;
      });
      _reconnectTimer?.cancel();
      _channel!.stream.listen(
        (m) {
          if (!mounted) return;
          print("WS: RX $m");
          _handleWebSocketMessage(m);
        },
        onError: (e) {
          if (!mounted) return;
          print("WS: Err $e");
          setState(() {
            _isConnected = false;
            _isConnecting = false;
          });
          _scheduleReconnect();
        },
        onDone: () {
          if (!mounted) return;
          print(
              "WS: Done. Code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason}");
          setState(() {
            _isConnected = false;
            _isConnecting = false;
          });
          if (_channel?.closeCode != status.goingAway &&
              _channel?.closeCode != status.normalClosure) {
            _scheduleReconnect();
          } else {
            _channel = null;
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      if (!mounted) return;
      print("WS: Conn fail $e");
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
      _channel = null;
      _scheduleReconnect();
    }
  }

  void _disconnectWebSocket() {
    print("WS: Disconnect...");
    _reconnectTimer?.cancel();
    _channel?.sink.close(status.goingAway);
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
  }

  void _scheduleReconnect() {
    if (!mounted || _reconnectTimer?.isActive == true || _isConnecting) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print("WS: Max reconnect.");
      _reconnectAttempts = 0;
      return;
    }
    _reconnectAttempts++;
    final delay =
        _initialReconnectDelay * math.pow(1.5, _reconnectAttempts - 1);
    final clamped = delay > _maxReconnectDelay ? _maxReconnectDelay : delay;
    print(
        "WS: Sched reconnect #${_reconnectAttempts} in ${clamped.inSeconds}s...");
    _reconnectTimer = Timer(clamped, () {
      if (mounted) {
        _connectWebSocket();
      }
    });
  }

  // OPTIMIZED WebSocket Handler
  // OPTIMIZED WebSocket Handler
  void _handleWebSocketMessage(dynamic message) async {
    print("WS: Handle msg -> Check for changes.");
    if (_isHandlingWebSocketUpdate || !mounted)
      return; // Prevent overlapping updates

    setState(() {
      _isHandlingWebSocketUpdate = true;
    }); // Set flag

    List<KitchenListOrder> inProgressFetched =
        []; // <<<--- Define variable to hold fetched in-progress orders

    try {
      // 1. Fetch ONLY the current list of pending order IDs and statuses
      print("WS Update: Fetching current pending orders status...");
      List<KitchenListOrder> currentServerPending = [];
      try {
        final results = await Future.wait([
          _fetchOrdersWithStatus('ordered'),
          _fetchOrdersWithStatus('in_progress'), // Fetch both statuses
        ], eagerError: true);
        if (!mounted) return;
        currentServerPending = [...results[0], ...results[1]];
        inProgressFetched =
            results[1]; // <<<--- Assign the fetched in-progress list here
      } catch (e) {
        print("WS Update: Error fetching orders during WS update: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Lỗi kiểm tra cập nhật đơn hàng.'),
            backgroundColor: Colors.orangeAccent.withOpacity(0.8),
            duration: Duration(seconds: 2),
          ));
        }
        // Ensure flag is reset even on error
        if (mounted)
          setState(() {
            _isHandlingWebSocketUpdate = false;
          });
        return; // Exit if we can't get the current server state
      }

      if (!mounted) return;

      final serverOrderMap = <int, KitchenListOrder>{
        for (var o in currentServerPending) o.orderId: o
      };
      final serverOrderIds = serverOrderMap.keys.toSet();
      final localOrderIds = _pendingOrders.map((o) => o.orderId).toSet();

      // 2. Identify changes
      final newOrderIds = serverOrderIds.difference(localOrderIds);
      final removedOrderIds = localOrderIds.difference(serverOrderIds);

      bool changed = false;
      List<KitchenListOrder> updatedPendingList = List.from(_pendingOrders);

      // 3. Remove completed/cancelled orders
      if (removedOrderIds.isNotEmpty) {
        print("WS Update: Removing orders: $removedOrderIds");
        updatedPendingList
            .removeWhere((o) => removedOrderIds.contains(o.orderId));
        final removedSessionIds = _pendingOrders
            .where((o) => removedOrderIds.contains(o.orderId))
            .map((o) => o.sessionId)
            .toSet();
        _tableNumberCache.removeWhere(
            (sessionId, _) => removedSessionIds.contains(sessionId));
        _fetchingTableSessionIds
            .removeWhere((sessionId) => removedSessionIds.contains(sessionId));
        _inProgressOrderIds.removeAll(removedOrderIds);
        changed = true;
      }

      // 4. Add new orders (fetch details & table# only for these)
      if (newOrderIds.isNotEmpty) {
        print("WS Update: Adding new orders: $newOrderIds");
        List<KitchenListOrder> newOrders = [];
        for (int newId in newOrderIds) {
          KitchenListOrder? newOrderData = serverOrderMap[newId];
          if (newOrderData != null) {
            newOrders.add(newOrderData);
            // *** FIX: Use the correct variable 'inProgressFetched' ***
            if (inProgressFetched
                .any((ip) => ip.orderId == newOrderData.orderId)) {
              print("WS Update: Marking new order $newId as in progress.");
              _inProgressOrderIds.add(newId);
            }
          }
        }
        if (newOrders.isNotEmpty) {
          print(
              "WS Update: Fetching table numbers for ${newOrders.length} new orders...");
          List<KitchenListOrder> newOrdersWithTables =
              await _fetchTableNumbersForOrders(newOrders);
          if (mounted) {
            updatedPendingList.addAll(newOrdersWithTables);
            changed = true;
          }
        }
      }

      // 5. Update state if changes occurred
      if (changed && mounted) {
        print("WS Update: Applying changes to state.");
        updatedPendingList
            .sort((a, b) => a.orderTime.compareTo(b.orderTime)); // Re-sort
        _pendingOrders =
            updatedPendingList; // Update notifier -> triggers listener -> updates filter & UI via setState

        Map<int, int> counts = {};
        for (var order in _pendingOrders) {
          if (order.tableNumber != null &&
              order.tableNumber! > 0 &&
              order.tableNumber! != -1) {
            counts[order.tableNumber!] = (counts[order.tableNumber!] ?? 0) + 1;
          }
        }
        try {
          widget.onOrderUpdate?.call(counts);
        } catch (e) {
          print("WS Update: Err call onOrderUpdate: $e");
        }
      } else {
        print("WS Update: No changes detected.");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isHandlingWebSocketUpdate = false;
        }); // Release flag
      } else {
        _isHandlingWebSocketUpdate = false;
      }
    }
  }

  // --- OPTIMIZED Data Fetching Methods ---
  Future<void> _fetchPendingOrders({bool forceRefresh = false}) async {
    if (_isLoadingPending && !forceRefresh) return;
    if (!mounted) return;
    if (forceRefresh) {
      print("Kitchen: Force refresh pending.");
      final ids = _pendingOrders.map((o) => o.sessionId).toSet();
      _tableNumberCache.removeWhere((sId, _) => ids.contains(sId));
      _fetchingTableSessionIds.removeWhere((sId) => ids.contains(sId));
    }
    bool isInitialLoad = _pendingOrders.isEmpty;
    setState(() {
      if (isInitialLoad) _isLoadingPending = true;
      _isBackgroundLoading = true;
      _pendingErrorMessage = null;
      if (forceRefresh) _inProgressOrderIds.clear();
    });
    List<KitchenListOrder> initialOrders = [];
    String? errorMsg;
    bool initialFetchSuccess = false;
    List<KitchenListOrder> inProgressFetched =
        []; // Keep track of in-progress orders fetched
    try {
      print("Kitchen: Fetching basic pending orders...");
      final r = await Future.wait([
        _fetchOrdersWithStatus('ordered'),
        _fetchOrdersWithStatus('in_progress')
      ], eagerError: true);
      if (!mounted) return;
      final o = r[0];
      final i = r[1];
      inProgressFetched = i;
      List<KitchenListOrder> c = [...o, ...i];
      final m = <int, KitchenListOrder>{
        for (var order in c) order.orderId: order
      };
      initialOrders = m.values.toList()
        ..sort((a, b) => a.orderTime.compareTo(b.orderTime));
      _inProgressOrderIds.clear();
      for (var order in initialOrders) {
        if (i.any((ip) => ip.orderId == order.orderId)) {
          _inProgressOrderIds.add(order.orderId);
        }
      }
      initialFetchSuccess = true;
      print("Kitchen: Basic pending orders fetched: ${initialOrders.length}");
    } catch (e) {
      errorMsg = "Lỗi tải danh sách đơn: $e";
      print("Kitchen: Err fetch PENDING (basic): $e");
      initialOrders = [];
    }

    if (mounted) {
      _pendingOrders = initialOrders;
      _pendingErrorMessage = errorMsg;
      _isLoadingPending = false;
      _updateFilteredLists();
      setState(() {});
      print("Kitchen: Initial pending list rendered.");
    }

    if (mounted && initialFetchSuccess && initialOrders.isNotEmpty) {
      print("Kitchen: Starting background table# fetch...");
      Future.delayed(Duration.zero,
          () => _fetchAndProcessTableNumbers(List.from(initialOrders)));
    } else {
      if (mounted) {
        setState(() {
          _isBackgroundLoading = false;
        });
        try {
          widget.onOrderUpdate?.call({});
        } catch (e) {
          print("Err call onOrderUpdate (init fail): $e");
        }
      }
    }
  }

  Future<void> _fetchAndProcessTableNumbers(
      List<KitchenListOrder> orders) async {
    try {
      print(
          "Kitchen: Starting background table# fetch for ${orders.length} orders.");
      await _fetchTableNumbersForOrders(orders);
      if (!mounted) return;
      Map<int, int> counts = {};
      for (var order in _pendingOrdersNotifier.value) {
        if (order.tableNumber != null &&
            order.tableNumber! > 0 &&
            order.tableNumber! != -1) {
          counts[order.tableNumber!] = (counts[order.tableNumber!] ?? 0) + 1;
        }
      }
      print("Kitchen: Background table# fetched. Updated counts: $counts");
      try {
        widget.onOrderUpdate?.call(counts);
      } catch (e) {
        print("Kitchen: Error calling onOrderUpdate after table fetch: $e");
      }
      if (mounted) {
        setState(() {
          _isBackgroundLoading = false;
        });
      }
    } catch (e) {
      print("Kitchen: Error during background table# fetch/update: $e");
      if (mounted) {
        setState(() {
          _isBackgroundLoading = false;
        });
      }
    }
  }

  Future<void> _fetchCompletedOrders({bool forceRefresh = false}) async {
    if (_isLoadingCompleted && !forceRefresh) return;
    if (!mounted) return;
    if (forceRefresh) {
      print("Kitchen: Force refresh completed.");
      final ids = _completedOrders.map((o) => o.sessionId).toSet();
      _tableNumberCache.removeWhere((sId, _) => ids.contains(sId));
      _fetchingTableSessionIds.removeWhere((sId) => ids.contains(sId));
    }
    bool isInitialLoad = _completedOrders.isEmpty;
    setState(() {
      _isLoadingCompleted = true;
      _isBackgroundLoading = true;
      _completedErrorMessage = null;
    });
    List<KitchenListOrder> initialOrders = [];
    String? errorMsg;
    bool initialFetchSuccess = false;
    try {
      print("Kitchen: Fetching basic completed orders...");
      final served = await _fetchOrdersWithStatus('served');
      if (!mounted) return;
      initialOrders = served
        ..sort((a, b) => b.orderTime.compareTo(a.orderTime));
      initialFetchSuccess = true;
      print("Kitchen: Basic completed orders fetched: ${initialOrders.length}");
    } catch (e) {
      errorMsg = "Lỗi tải đơn hoàn thành: $e";
      print("Kitchen: Err fetch COMPLETED (basic): $e");
      initialOrders = [];
    }
    if (mounted) {
      _completedOrders = initialOrders;
      _completedErrorMessage = errorMsg;
      _isLoadingCompleted = false;
      _completedOrdersLoaded = true;
      _updateFilteredLists();
      setState(() {});
      print("Kitchen: Initial completed list rendered.");
    }
    if (mounted && initialFetchSuccess && initialOrders.isNotEmpty) {
      Future.delayed(Duration.zero,
          () => _fetchAndProcessTableNumbers(List.from(initialOrders)));
    } else if (mounted) {
      setState(() {
        _isBackgroundLoading = false;
      });
    }
  }

  Future<List<KitchenListOrder>> _fetchOrdersWithStatus(String status) async {
    final u = Uri.parse(
        'https://soa-deploy.up.railway.app/kitchen/get-orders-by-status/$status');
    print("API: Fetch $status: $u");
    try {
      final r = await http.get(u).timeout(const Duration(seconds: 15));
      if (!mounted) return [];
      if (r.statusCode == 200) {
        final List<dynamic> d = jsonDecode(utf8.decode(r.bodyBytes));
        return d
            .map((o) => KitchenListOrder.fromJson(o as Map<String, dynamic>))
            .toList();
      } else {
        String b = r.body;
        try {
          b = utf8.decode(r.bodyBytes);
        } catch (_) {}
        print("API: Err $status: ${r.statusCode}, Body: $b");
        throw Exception('Fail load $status: ${r.statusCode}');
      }
    } catch (e) {
      print("API: Net/Timeout Err $status: $e");
      throw Exception('Net err $status');
    }
  }

  Future<int?> _fetchTableNumber(int sessionId) async {
    if (_tableNumberCache.containsKey(sessionId)) {
      final v = _tableNumberCache[sessionId];
      return v == -1 ? null : v;
    }
    if (_fetchingTableSessionIds.contains(sessionId)) {
      return null;
    }
    if (!mounted) return null;
    _fetchingTableSessionIds.add(sessionId);
    final url = Uri.parse(
        'https://soa-deploy.up.railway.app/order/session/$sessionId/table-number');
    int? res;
    int cacheVal = -1;
    try {
      final r = await http.get(url).timeout(const Duration(seconds: 8));
      if (!mounted) {
        _fetchingTableSessionIds.remove(sessionId);
        return null;
      }
      if (r.statusCode == 200) {
        final d = jsonDecode(utf8.decode(r.bodyBytes));
        dynamic t;
        if (d is Map && d.containsKey('table_number'))
          t = d['table_number'];
        else if (d is int || d is String) t = d;
        if (t is int)
          res = t;
        else if (t is String) res = int.tryParse(t);
        if (res != null && res > 0)
          cacheVal = res;
        else {
          res = null;
          cacheVal = -1;
        }
      } else {
        res = null;
        cacheVal = -1;
      }
    } catch (e) {
      print("Exc fetch table# $sessionId: $e");
      res = null;
      cacheVal = -1;
      if (!mounted) {
        _fetchingTableSessionIds.remove(sessionId);
        return null;
      }
    } finally {
      _tableNumberCache[sessionId] = cacheVal;
      _fetchingTableSessionIds.remove(sessionId);
    }
    return res;
  }

  Future<List<KitchenListOrder>> _fetchTableNumbersForOrders(
      List<KitchenListOrder> orders) async {
    if (orders.isEmpty) return orders;
    final List<Future<void>> fut = [];
    final Set<int> needed = {};
    for (var o in orders) {
      if (!_tableNumberCache.containsKey(o.sessionId) &&
          !_fetchingTableSessionIds.contains(o.sessionId)) {
        needed.add(o.sessionId);
      }
    }
    if (needed.isNotEmpty) {
      print("Need fetch table# for: $needed");
      for (int sId in needed) {
        fut.add(_fetchTableNumber(sId));
      }
      try {
        await Future.wait(fut);
        print("Done Future.wait table#");
      } catch (e) {
        print("Err Future.wait table#: $e");
      }
    }
    if (!mounted) return orders;
    List<KitchenListOrder> updated = orders.map((o) {
      final c = _tableNumberCache[o.sessionId];
      if (o.tableNumber != c) {
        o.tableNumber = c;
      }
      return o;
    }).toList();
    return updated;
  }

  Future<void> _fetchOrderDetail(
      int orderId, StateSetter setDialogState) async {
    if (!mounted) return;
    try {
      setDialogState(() {
        _isDetailLoading = true;
        _detailErrorMessage = null;
        _detailItems = [];
        _updatingItemIds.clear();
        _isCompletingAll = false;
      });
    } catch (e) {
      print("Err set dialog load state $orderId: $e");
      _isDetailLoading = false;
      _detailItems = [];
      return;
    }
    final url = Uri.parse(
        'https://soa-deploy.up.railway.app/kitchen/order/$orderId/items');
    print('Fetch detail: $url');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> d = jsonDecode(utf8.decode(response.bodyBytes));
        final List<KitchenOrderDetailItem> f = d
            .map((i) =>
                KitchenOrderDetailItem.fromJson(i as Map<String, dynamic>))
            .toList();
        try {
          setDialogState(() {
            _detailItems = f;
            _isDetailLoading = false;
          });
        } catch (e) {
          print("Err set dialog data state $orderId: $e");
          _detailItems = f;
          _isDetailLoading = false;
        }
      } else {
        print("Err fetch detail $orderId: ${response.statusCode}");
        final b = utf8.decode(response.bodyBytes);
        String s = '';
        try {
          final de = jsonDecode(b);
          if (de is Map && de.containsKey('detail')) {
            s = ': ${de['detail']}';
          }
        } catch (_) {}
        try {
          setDialogState(() {
            _detailErrorMessage = 'Lỗi tải chi tiết (${response.statusCode})$s';
            _isDetailLoading = false;
          });
        } catch (e) {
          print("Err set dialog server err state $orderId: $e");
          _detailErrorMessage = 'Lỗi tải chi tiết (${response.statusCode})$s';
          _isDetailLoading = false;
        }
      }
    } on TimeoutException catch (e) {
      print("Timeout fetch detail $orderId: $e");
      if (!mounted) return;
      try {
        setDialogState(() {
          _detailErrorMessage = 'Yêu cầu quá thời gian (8 giây).';
          _isDetailLoading = false;
        });
      } catch (se) {
        print("Err set dialog timeout err state $orderId: $se");
        _detailErrorMessage = 'Yêu cầu quá thời gian (8 giây).';
        _isDetailLoading = false;
      }
    } catch (e) {
      print("Net/Other Err fetch detail $orderId: $e");
      if (!mounted) return;
      try {
        setDialogState(() {
          _detailErrorMessage = 'Lỗi kết nối/xử lý dữ liệu.';
          _isDetailLoading = false;
        });
      } catch (se) {
        print("Err set dialog catch err state $orderId: $se");
        _detailErrorMessage = 'Lỗi kết nối/xử lý dữ liệu.';
        _isDetailLoading = false;
      }
    }
  }

  // --- Popup & Order Management Methods ---
  void _showOrderDetailPopup(BuildContext context, KitchenListOrder order) {
    final theme = Theme.of(context);
    _isDetailLoading = false;
    _detailErrorMessage = null;
    _detailItems = [];
    _updatingItemIds.clear();
    _isCompletingAll = false;
    showDialog<void>(
        context: context,
        barrierDismissible: !_isCompletingAll,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(builder: (context, setDialogState) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              bool f = mounted &&
                  (ModalRoute.of(dialogContext)?.isCurrent ?? false) &&
                  _detailItems.isEmpty &&
                  !_isDetailLoading &&
                  _detailErrorMessage == null;
              if (f) {
                _fetchOrderDetail(order.orderId, setDialogState);
              }
            });
            bool canCompleteAll =
                _detailItems.any((i) => i.status.toLowerCase() != 'served') &&
                    !_isDetailLoading &&
                    !_isCompletingAll &&
                    _updatingItemIds.isEmpty;
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(16.0, 16.0, 8.0, 10.0),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                      child: Text(
                    'Chi tiết Đơn #${order.orderId}',
                    style: theme.dialogTheme.titleTextStyle,
                    overflow: TextOverflow.ellipsis,
                  )),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isCompletingAll)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.lightBlueAccent)),
                        )
                      else
                        IconButton(
                          icon: Icon(Icons.done_all,
                              color: canCompleteAll
                                  ? theme.colorScheme.secondary
                                  : theme.disabledColor,
                              size: 24),
                          tooltip: 'Hoàn thành tất cả',
                          onPressed: !canCompleteAll
                              ? null
                              : () => _completeAllItemsForOrder(
                                  order, setDialogState, dialogContext),
                          splashRadius: 20,
                          visualDensity: VisualDensity.compact,
                        ),
                      IconButton(
                        icon: Icon(Icons.refresh,
                            color: theme.colorScheme.secondary.withOpacity(0.8),
                            size: 22),
                        tooltip: 'Tải lại',
                        onPressed: _isDetailLoading ||
                                _updatingItemIds.isNotEmpty ||
                                _isCompletingAll
                            ? null
                            : () => _fetchOrderDetail(
                                order.orderId, setDialogState),
                        splashRadius: 20,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  )
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
              content: _buildPopupContent(theme, setDialogState, order,
                  _isCompletingAll, dialogContext),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              actions: [
                TextButton(
                  onPressed: _updatingItemIds.isNotEmpty || _isCompletingAll
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text('Đóng',
                      style: TextStyle(
                          color: _updatingItemIds.isNotEmpty || _isCompletingAll
                              ? theme.disabledColor
                              : theme.colorScheme.secondary)),
                ),
              ],
              backgroundColor: theme.dialogTheme.backgroundColor,
              shape: theme.dialogTheme.shape,
            );
          });
        }).then((_) {
      _updatingItemIds.clear();
      _detailItems = [];
      _isDetailLoading = false;
      _detailErrorMessage = null;
      _isCompletingAll = false;
      print("Detail dialog closed #${order.orderId}");
    });
  }

  void showOrdersForTable(BuildContext parentContext, int tableNumber) {
    final theme = Theme.of(parentContext);
    print("Show popup table $tableNumber.");
    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return ValueListenableBuilder<List<KitchenListOrder>>(
          valueListenable: _pendingOrdersNotifier,
          builder: (context, currentPendingOrders, child) {
            final ordersForTable = currentPendingOrders
                .where((o) => o.tableNumber == tableNumber)
                .toList()
              ..sort((a, b) => a.orderTime.compareTo(b.orderTime));
            if (ordersForTable.isEmpty && Navigator.canPop(dialogContext)) {
              print("Table $tableNumber list popup: Auto-closing.");
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(dialogContext)) {
                  Navigator.of(dialogContext).pop();
                }
              });
              return const SizedBox.shrink();
            }
            return WillPopScope(
              onWillPop: () async {
                print("Table $tableNumber list popup: Manually closing.");
                return true;
              },
              child: AlertDialog(
                title: Text('Đơn hàng Bàn $tableNumber (Chờ)',
                    style: theme.dialogTheme.titleTextStyle),
                content: Container(
                  width: double.maxFinite,
                  constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.of(dialogContext).size.height * 0.5),
                  child: ordersForTable.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(kDefaultPadding),
                            child: Text(
                              'Không còn đơn hàng nào đang chờ.',
                              style: (theme.textTheme.bodyMedium ??
                                      const TextStyle())
                                  .copyWith(
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.7)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: ordersForTable.length,
                          itemBuilder: (context, index) {
                            final order = ordersForTable[index];
                            final fmtTime = DateFormat('HH:mm - dd/MM/yy')
                                .format(order.orderTime);
                            final bool showIP =
                                _inProgressOrderIds.contains(order.orderId);
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: kDefaultPadding * 0.6),
                              color: theme.cardTheme.color?.withOpacity(0.9),
                              child: ListTile(
                                leading: Icon(Icons.receipt_long,
                                    color: theme.colorScheme.secondary
                                        .withOpacity(0.8)),
                                title: Row(
                                  children: [
                                    if (showIP)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(right: 6),
                                          child: Icon(
                                              Icons.hourglass_top_rounded,
                                              color: Colors.yellowAccent[700],
                                              size: 16)),
                                    Flexible(
                                        child: Text('Đơn #${order.orderId}')),
                                  ],
                                ),
                                subtitle: Text('TG: $fmtTime'),
                                trailing: Icon(Icons.arrow_forward_ios,
                                    size: 16,
                                    color: theme.iconTheme.color
                                        ?.withOpacity(0.7)),
                                onTap: () {
                                  _showOrderDetailPopup(parentContext, order);
                                },
                                dense: true,
                              ),
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton.icon(
                    icon: Icon(Icons.refresh,
                        size: 16,
                        color: theme.colorScheme.secondary.withOpacity(0.8)),
                    label: Text('Làm mới DS',
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                theme.colorScheme.secondary.withOpacity(0.8))),
                    onPressed: () {
                      _fetchPendingOrders(forceRefresh: true);
                    },
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text('Đóng',
                        style: TextStyle(color: theme.colorScheme.secondary)),
                  ),
                ],
                backgroundColor: theme.dialogTheme.backgroundColor,
                shape: theme.dialogTheme.shape,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPopupContent(
      ThemeData theme,
      StateSetter setDialogState,
      KitchenListOrder order,
      bool isCompletingAll,
      BuildContext dialogContext) {
    if (_isDetailLoading)
      return Container(
          height: 150,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.secondary),
              const SizedBox(height: 15),
              Text("Đang tải...", style: theme.textTheme.bodySmall)
            ],
          ));
    if (_detailErrorMessage != null)
      return Container(
          padding: const EdgeInsets.all(kDefaultPadding * 2),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.warning_amber_rounded,
                color: theme.colorScheme.error, size: 40),
            const SizedBox(height: 10),
            Text(_detailErrorMessage!,
                textAlign: TextAlign.center,
                style: (theme.textTheme.bodyMedium ?? const TextStyle())
                    .copyWith(
                        color: theme.textTheme.bodyMedium?.color
                            ?.withOpacity(0.7))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
                onPressed: () =>
                    _fetchOrderDetail(order.orderId, setDialogState),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer,
                    foregroundColor: theme.colorScheme.onErrorContainer))
          ]));
    if (_detailItems.isEmpty)
      return Container(
          height: 100,
          padding: const EdgeInsets.all(kDefaultPadding * 2),
          alignment: Alignment.center,
          child: Text('Không có món ăn.',
              textAlign: TextAlign.center,
              style: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6))));
    return Container(
        width: double.maxFinite,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: ListView.builder(
            shrinkWrap: true,
            padding:
                const EdgeInsets.symmetric(horizontal: kDefaultPadding * 0.5),
            itemCount: _detailItems.length,
            itemBuilder: (context, index) {
              final item = _detailItems[index];
              final bool isServed = item.status.toLowerCase() == 'served';
              final bool isThisUpdating =
                  _updatingItemIds.contains(item.orderItemId);
              return Opacity(
                  opacity: isServed ? 0.65 : 1.0,
                  child: Card(
                      elevation: isServed ? 1 : 3,
                      margin: const EdgeInsets.symmetric(
                          vertical: kDefaultPadding * 0.7,
                          horizontal: kDefaultPadding / 2),
                      color: theme.cardTheme.color
                          ?.withAlpha(isServed ? 200 : 255),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: kDefaultPadding * 1.2,
                              vertical: kDefaultPadding),
                          child: Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('${item.name} (SL: ${item.quantity})',
                                      style: (theme.textTheme.titleMedium ??
                                              const TextStyle())
                                          .copyWith(
                                        fontSize: 14.5,
                                        color: isServed
                                            ? theme.textTheme.bodySmall?.color
                                            : theme
                                                .textTheme.titleMedium?.color,
                                        decoration: isServed
                                            ? TextDecoration.lineThrough
                                            : null,
                                        decorationColor: theme.dividerColor,
                                        decorationThickness: 1.5,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 5),
                                  Row(children: [
                                    Icon(_getStatusIcon(item.status),
                                        color: _getStatusColor(item.status),
                                        size: 14),
                                    const SizedBox(width: 4),
                                    Text(_getStatusText(item.status),
                                        style: (theme.textTheme.bodySmall ??
                                                const TextStyle())
                                            .copyWith(
                                                fontStyle: FontStyle.italic,
                                                fontSize: 11,
                                                color:
                                                    _getStatusColor(item.status)
                                                        .withOpacity(0.9)))
                                  ])
                                ])),
                            const SizedBox(width: kDefaultPadding),
                            SizedBox(
                                width: 85,
                                height: 30,
                                child: Center(
                                    child: isThisUpdating
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.lightBlueAccent))
                                        : isServed
                                            ? Icon(Icons.check_circle,
                                                color: Colors.greenAccent
                                                    .withOpacity(0.9),
                                                size: 28)
                                            : ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.teal,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                                  textStyle: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6)),
                                                  elevation: 2,
                                                  disabledBackgroundColor: theme
                                                      .disabledColor
                                                      .withOpacity(0.5),
                                                  disabledForegroundColor:
                                                      theme.disabledColor,
                                                ),
                                                onPressed: isCompletingAll ||
                                                        isThisUpdating
                                                    ? null
                                                    : () {
                                                        _updatePopupOrderItemStatus(
                                                            order,
                                                            item,
                                                            'served',
                                                            setDialogState,
                                                            dialogContext);
                                                      },
                                                child:
                                                    const Text('Hoàn thành'))))
                          ]))));
            }));
  }

  Future<void> _updatePopupOrderItemStatus(
      KitchenListOrder order,
      KitchenOrderDetailItem item,
      String newStatus,
      StateSetter setDialogState,
      BuildContext dialogContext) async {
    if (_updatingItemIds.contains(item.orderItemId) || !mounted) return;
    try {
      setDialogState(() => _updatingItemIds.add(item.orderItemId));
    } catch (e) {
      print("Err set update start ${item.orderItemId}: $e");
      return;
    }
    print("PATCH item ${item.orderItemId} -> '$newStatus'");
    final url = Uri.parse(
            'https://soa-deploy.up.railway.app/kitchen/order-items/${item.orderItemId}/status')
        .replace(queryParameters: {'status': newStatus});
    final headers = {'Content-Type': 'application/json'};
    bool success = false;
    try {
      final response = await http
          .patch(url, headers: headers)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        print("API OK: Item ${item.orderItemId} -> '$newStatus'.");
        success = true;
        final index =
            _detailItems.indexWhere((i) => i.orderItemId == item.orderItemId);
        if (index != -1) {
          try {
            setDialogState(() => _detailItems[index].status = newStatus);
          } catch (e) {
            _detailItems[index].status = newStatus;
          }
          bool allServed =
              _detailItems.every((i) => i.status.toLowerCase() == 'served');
          if (allServed) {
            print("Order ${order.orderId} fully served. Calling complete API.");
            bool completeOk = await _callCompleteOrderApi(order.orderId);
            if (!mounted) return;
            if (!completeOk) {
              print("Err: Failed /complete API for ${order.orderId}");
              String msg = 'Lỗi xác nhận hoàn thành đơn.';
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(msg), backgroundColor: Colors.orange));
              try {
                setDialogState(() {
                  _updatingItemIds.remove(item.orderItemId);
                });
              } catch (e) {
                _updatingItemIds.remove(item.orderItemId);
              }
              return;
            }
            if (mounted) {
              setState(() {
                _pendingOrders = _pendingOrders
                    .where((o) => o.orderId != order.orderId)
                    .toList();
                _inProgressOrderIds.remove(order.orderId);
                if (!_completedOrders
                    .any((co) => co.orderId == order.orderId)) {
                  _completedOrders.insert(0, order);
                }
                _notifyTableStatusUpdate(order.tableNumber);
              });
              ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                content: Text('Đơn hàng #${order.orderId} đã hoàn thành!'),
                backgroundColor: Colors.green[700],
                duration: const Duration(seconds: 3),
              ));
            }
            if (Navigator.canPop(dialogContext)) {
              Navigator.of(dialogContext).pop();
            }
            if (mounted) _fetchCompletedOrders();
          } else {
            if (!_inProgressOrderIds.contains(order.orderId)) {
              if (mounted) {
                setState(() {
                  print("Marking order ${order.orderId} in progress.");
                  _inProgressOrderIds.add(order.orderId);
                });
              }
            }
            if (mounted && newStatus.toLowerCase() == 'served') {
              ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                content:
                    Text('Đã hoàn thành: ${item.name} (Đơn #${order.orderId})'),
                backgroundColor: Colors.lightGreen.shade800,
                duration: const Duration(seconds: 2),
              ));
            }
          }
        } else {
          print("Err: Item ${item.orderItemId} not found locally.");
          try {
            setDialogState(
                () => _fetchOrderDetail(order.orderId, setDialogState));
          } catch (e) {}
        }
      } else {
        print(
            "API Err update item ${item.orderItemId}: ${response.statusCode}, ${utf8.decode(response.bodyBytes)}");
        success = false;
        String m = 'Lỗi cập nhật món (${response.statusCode})';
        try {
          final eb = jsonDecode(utf8.decode(response.bodyBytes));
          if (eb is Map && eb.containsKey('detail')) {
            m += ': ${eb['detail']}';
          }
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(m), backgroundColor: Colors.redAccent));
        }
      }
    } catch (e) {
      if (!mounted) return;
      print("Net/Timeout Err update item ${item.orderItemId}: $e");
      success = false;
      String m = 'Lỗi mạng/timeout.';
      if (e is TimeoutException) {
        m = 'Quá thời gian.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(m), backgroundColor: Colors.orangeAccent));
      }
    } finally {
      if (mounted) {
        try {
          setDialogState(() => _updatingItemIds.remove(item.orderItemId));
        } catch (e) {
          _updatingItemIds.remove(item.orderItemId);
        }
      } else {
        _updatingItemIds.remove(item.orderItemId);
      }
      print("Finished update item ${item.orderItemId}. Success: $success");
    }
  }

  Future<bool> _callCompleteOrderApi(int orderId) async {
    final url = Uri.parse(
        'https://soa-deploy.up.railway.app/kitchen/order/complete/$orderId');
    final headers = {'Content-Type': 'application/json'};
    print("PATCH Helper: $url");
    try {
      final r = await http
          .patch(url, headers: headers)
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200 || r.statusCode == 204) {
        print("API OK Helper: Order $orderId complete.");
        return true;
      } else {
        print(
            "API Err Helper: Order $orderId fail complete (${r.statusCode}), ${r.body}");
        return false;
      }
    } catch (e) {
      print("Net/Timeout Err Helper complete order $orderId: $e");
      return false;
    }
  }

  Future<void> _completeAllItemsForOrder(KitchenListOrder order,
      StateSetter setDialogState, BuildContext dialogContext) async {
    if (_isCompletingAll || !mounted) return;
    print("API complete order ${order.orderId} directly.");
    try {
      setDialogState(() => _isCompletingAll = true);
    } catch (e) {
      print("Err set dialog 'Complete All' start: $e");
      return;
    }
    bool success = await _callCompleteOrderApi(order.orderId);
    if (!mounted) return;
    if (success) {
      print("API OK: Order ${order.orderId} complete via All.");
      if (mounted) {
        setState(() {
          _pendingOrders =
              _pendingOrders.where((o) => o.orderId != order.orderId).toList();
          _inProgressOrderIds.remove(order.orderId);
          if (!_completedOrders.any((co) => co.orderId == order.orderId)) {
            _completedOrders.insert(0, order);
          }
          _notifyTableStatusUpdate(order.tableNumber);
        });
        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
          content: Text('Đơn hàng #${order.orderId} đã hoàn thành!'),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 3),
        ));
      }
      if (Navigator.canPop(dialogContext)) {
        Navigator.of(dialogContext).pop();
      }
      if (mounted) _fetchCompletedOrders();
    } else {
      print("API Err complete order ${order.orderId} via All.");
      String m = 'Lỗi hoàn thành đơn hàng.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(m), backgroundColor: Colors.redAccent));
      }
      try {
        setDialogState(() => _fetchOrderDetail(order.orderId, setDialogState));
      } catch (e) {}
    }
    if (mounted) {
      try {
        setDialogState(() {
          _isCompletingAll = false;
          _updatingItemIds.clear();
        });
      } catch (e) {
        _isCompletingAll = false;
        _updatingItemIds.clear();
      }
    } else {
      _isCompletingAll = false;
      _updatingItemIds.clear();
    }
    print("Finished 'Complete All' ${order.orderId}. Success: $success");
  }

  void _notifyTableStatusUpdate(int? tableNumber) {
    if (!mounted) return;
    if (tableNumber == null || tableNumber <= 0 || tableNumber == -1) {
      print("Warn: Cannot notify invalid table#: $tableNumber. Refreshing.");
      _fetchPendingOrders(forceRefresh: true);
      return;
    }
    print("Check if table $tableNumber clear...");
    bool others = _pendingOrders.any((o) => o.tableNumber == tableNumber);
    if (!others) {
      print("Table $tableNumber clear. Call onTableCleared.");
      try {
        widget.onTableCleared?.call(tableNumber);
      } catch (e) {
        print("Err call onTableCleared: $e");
      }
    } else {
      print("Table $tableNumber still pending. Recalc counts.");
      Map<int, int> counts = {};
      for (var o in _pendingOrders) {
        if (o.tableNumber != null &&
            o.tableNumber! > 0 &&
            o.tableNumber! != -1) {
          counts[o.tableNumber!] = (counts[o.tableNumber!] ?? 0) + 1;
        }
      }
      try {
        widget.onOrderUpdate?.call(counts);
      } catch (e) {
        print("Err call onOrderUpdate after partial clear: $e");
      }
    }
  }

  // --- Helper Methods for Status Display ---
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ordered':
        return Colors.orangeAccent;
      case 'in_progress':
        return Colors.yellowAccent[700]!;
      case 'ready':
        return Colors.lightBlueAccent;
      case 'served':
        return Colors.greenAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'ordered':
        return Icons.circle_notifications_outlined;
      case 'in_progress':
        return Icons.hourglass_top_rounded;
      case 'ready':
        return Icons.notifications_active_outlined;
      case 'served':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'ordered':
        return 'Chờ xử lý';
      case 'in_progress':
        return 'Đang làm';
      case 'ready':
        return 'Sẵn sàng';
      case 'served':
        return 'Đã phục vụ';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status.isNotEmpty
            ? status[0].toUpperCase() + status.substring(1).toLowerCase()
            : 'Không rõ';
    }
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildHeaderWithSearch(theme),
        Expanded(child: _buildBodyContent(theme)),
        if (_isBackgroundLoading && !_isLoadingPending && !_isLoadingCompleted)
          LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.secondary.withOpacity(0.5)),
          ),
        if (!_isConnected && _reconnectAttempts > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: Colors.orangeAccent[700],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Text(
                  _isConnecting ? 'Đang kết nối...' : 'Mất kết nối...',
                  style: (theme.textTheme.bodySmall ?? const TextStyle())
                      .copyWith(color: Colors.white, fontSize: 10.5),
                ),
              ],
            ),
          )
      ],
    );
  }

  // --- Header Row with Switcher and Search ---
  Widget _buildHeaderWithSearch(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kDefaultPadding * 1.5, kDefaultPadding,
          kDefaultPadding * 1.5, kDefaultPadding * 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildViewSwitcher(theme),
          const Spacer(),
          SizedBox(
            width: 250,
            height: 40,
            child: TextField(
              controller: _searchController,
              style: (theme.textTheme.bodyMedium ?? const TextStyle())
                  .copyWith(fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Tìm đơn/bàn...',
                prefixIcon: Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18),
                        tooltip: 'Xóa',
                        splashRadius: 15,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _clearSearch,
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Builds the Pending/Completed switcher ---
  Widget _buildViewSwitcher(ThemeData theme) {
    final Color pendingSelCol = theme.brightness == Brightness.dark
        ? Colors.yellowAccent[700]!
        : Colors.orange[800]!;
    final Color completedSelCol = theme.brightness == Brightness.dark
        ? Colors.greenAccent
        : Colors.green[700]!;
    final Color unselectedFG = theme.colorScheme.onSurface.withOpacity(0.7);
    return SegmentedButton<OrderListView>(
      segments: <ButtonSegment<OrderListView>>[
        ButtonSegment<OrderListView>(
            value: OrderListView.pending,
            label: Text('Đang xử lý'),
            icon: Icon(Icons.sync, size: 18)),
        ButtonSegment<OrderListView>(
            value: OrderListView.completed,
            label: Text('Đã hoàn thành'),
            icon: Icon(Icons.check_circle_outline_rounded, size: 18)),
      ],
      selected: <OrderListView>{_currentView},
      onSelectionChanged: (Set<OrderListView> newSelection) {
        if (newSelection.isNotEmpty && newSelection.first != _currentView) {
          setState(() {
            _currentView = newSelection.first;
            _clearSearch();
            if (_currentView == OrderListView.completed &&
                !_completedOrdersLoaded &&
                !_isLoadingCompleted) {
              _fetchCompletedOrders();
            } else {
              _updateFilteredLists();
            }
          });
        }
      },
      style: theme.segmentedButtonTheme.style?.copyWith(
        foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return _currentView == OrderListView.pending
                ? pendingSelCol
                : completedSelCol;
          }
          return unselectedFG;
        }),
        iconColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return _currentView == OrderListView.pending
                ? pendingSelCol
                : completedSelCol;
          }
          return unselectedFG;
        }),
      ),
    );
  }

  // --- Builds the main content area ---
  Widget _buildBodyContent(ThemeData theme) {
    Widget content;
    Future<void> Function() onRefresh;
    bool showLoading = false;
    bool showEmpty = false;
    String? errorMessage;
    List<KitchenListOrder> listToShow = [];
    if (_currentView == OrderListView.pending) {
      onRefresh = () => _fetchPendingOrders(forceRefresh: true);
      errorMessage = _pendingErrorMessage;
      listToShow = _filteredPendingOrders;
      showLoading = _isLoadingPending && _pendingOrders.isEmpty;
      showEmpty = listToShow.isEmpty &&
          !showLoading &&
          errorMessage == null &&
          !_isLoadingPending &&
          !_isBackgroundLoading;
    } else {
      onRefresh = () => _fetchCompletedOrders(forceRefresh: true);
      errorMessage = _completedErrorMessage;
      listToShow = _filteredCompletedOrders;
      showLoading = _isLoadingCompleted && _completedOrders.isEmpty;
      showEmpty = listToShow.isEmpty &&
          !showLoading &&
          errorMessage == null &&
          !_isLoadingCompleted &&
          !_isBackgroundLoading;
    }

    if (showLoading) {
      content = _buildShimmerLoadingList(theme);
    } else if (errorMessage != null && listToShow.isEmpty) {
      content = _buildErrorWidget(errorMessage, onRefresh);
    } else if (showEmpty && !_isBackgroundLoading) {
      String emptyMsg;
      IconData emptyIcon;
      if (_searchQuery.isNotEmpty) {
        emptyMsg = 'Không tìm thấy đơn hàng nào khớp.';
        emptyIcon = Icons.search_off_rounded;
      } else if (_currentView == OrderListView.pending) {
        emptyMsg = 'Không có đơn hàng đang xử lý.';
        emptyIcon = Icons.no_food_outlined;
      } else {
        emptyMsg = 'Chưa có đơn hàng hoàn thành.';
        emptyIcon = Icons.history_toggle_off_outlined;
      }
      content = _buildEmptyListWidget(emptyMsg, emptyIcon, onRefresh);
    } else {
      content = _buildOrderListView(listToShow);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: theme.colorScheme.secondary,
      backgroundColor: theme.scaffoldBackgroundColor,
      child: content,
    );
  }

  // --- Builds the shimmer loading list ---
  Widget _buildShimmerLoadingList(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.cardTheme.color?.withOpacity(0.5) ??
          theme.colorScheme.surface.withOpacity(0.5),
      highlightColor: theme.cardTheme.color?.withOpacity(0.8) ??
          theme.colorScheme.surface.withOpacity(0.8),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(kDefaultPadding, 0, kDefaultPadding,
            kDefaultPadding + kBottomActionBarHeight),
        itemCount: 7,
        itemBuilder: (_, __) => Card(
          margin: const EdgeInsets.only(bottom: kDefaultPadding * 1.5),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: kDefaultPadding * 1.5,
                vertical: kDefaultPadding * 1.2),
            leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8))),
            title: Container(
                width: double.infinity,
                height: 16.0,
                color: theme.colorScheme.onSurface.withOpacity(0.1),
                margin: const EdgeInsets.only(bottom: 8)),
            subtitle: Container(
                width: 120,
                height: 12.0,
                color: theme.colorScheme.onSurface.withOpacity(0.1)),
          ),
        ),
      ),
    );
  }

  // --- Builds the actual list view for orders - USES listToShow ---
  Widget _buildOrderListView(List<KitchenListOrder> listToShow) {
    final theme = Theme.of(context);
    if (listToShow.isEmpty && !_isBackgroundLoading) {
      String emptyMsg;
      IconData emptyIcon;
      Future<void> Function() onRefresh;
      if (_searchQuery.isNotEmpty) {
        emptyMsg = 'Không tìm thấy đơn nào khớp.';
        emptyIcon = Icons.search_off_rounded;
      } else if (_currentView == OrderListView.pending) {
        emptyMsg = 'Không có đơn hàng đang xử lý.';
        emptyIcon = Icons.no_food_outlined;
      } else {
        emptyMsg = 'Chưa có đơn hàng hoàn thành.';
        emptyIcon = Icons.history_toggle_off_outlined;
      }
      onRefresh = _currentView == OrderListView.pending
          ? () => _fetchPendingOrders(forceRefresh: true)
          : () => _fetchCompletedOrders(forceRefresh: true);
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: _buildEmptyListWidget(emptyMsg, emptyIcon, onRefresh)),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(kDefaultPadding, 0, kDefaultPadding,
          kDefaultPadding + kBottomActionBarHeight),
      itemCount: listToShow.length,
      itemBuilder: (context, index) {
        final order = listToShow[index];
        final fmtTime = DateFormat('HH:mm - dd/MM/yy').format(order.orderTime);
        final bool isServed = _currentView == OrderListView.completed;
        final bool showIP =
            !isServed && _inProgressOrderIds.contains(order.orderId);
        final baseTitleStyle = theme.textTheme.bodyMedium ?? const TextStyle();
        final baseSubStyle = theme.textTheme.bodySmall ?? const TextStyle();
        final primaryTextColor = isServed
            ? baseTitleStyle.color?.withOpacity(0.7)
            : baseTitleStyle.color;
        final titleStyle = baseTitleStyle.copyWith(
          fontWeight: FontWeight.w500,
          color: primaryTextColor,
          fontSize: 14.5,
        );
        final tableNumStyle = titleStyle.copyWith(
          fontWeight: FontWeight.bold,
        );
        final tableErrStyle = titleStyle.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.error,
          fontStyle: FontStyle.italic,
        );
        final subColor = isServed
            ? baseSubStyle.color?.withOpacity(0.6)
            : baseSubStyle.color?.withOpacity(0.8);
        int? currentTableNum = order.tableNumber;
        InlineSpan tableSpan;
        if (currentTableNum == null) {
          tableSpan = WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Tooltip(
              message: 'Đang tải...',
              child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: theme.disabledColor)),
            ),
          );
        } else if (currentTableNum == -1) {
          tableSpan = TextSpan(text: 'Lỗi', style: tableErrStyle);
        } else {
          tableSpan =
              TextSpan(text: currentTableNum.toString(), style: tableNumStyle);
        }
        return Card(
          margin: const EdgeInsets.only(bottom: kDefaultPadding * 1.5),
          elevation: isServed ? 1.5 : 3.5,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: isServed
              ? theme.cardTheme.color?.withAlpha(200)
              : theme.cardTheme.color,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: kDefaultPadding * 1.8,
                vertical: kDefaultPadding * 1.2),
            leading: Icon(
                isServed
                    ? Icons.check_circle_outline
                    : Icons.receipt_long_outlined,
                color: isServed
                    ? Colors.greenAccent.withOpacity(0.7)
                    : theme.colorScheme.secondary,
                size: 34),
            title: Text.rich(
              TextSpan(
                style: titleStyle,
                children: [
                  TextSpan(text: 'Bàn '),
                  tableSpan,
                  TextSpan(text: ' - Đơn #${order.orderId}'),
                  if (showIP)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding:
                            const EdgeInsets.only(left: kDefaultPadding * 0.75),
                        child: Icon(Icons.hourglass_top_rounded,
                            color: Colors.yellowAccent[700], size: 16),
                      ),
                    ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
                padding: const EdgeInsets.only(top: 5.0),
                child: Text('TG: $fmtTime',
                    style: baseSubStyle.copyWith(color: subColor))),
            trailing: isServed
                ? Icon(Icons.visibility_outlined,
                    color: theme.iconTheme.color?.withOpacity(0.6), size: 22)
                : Icon(Icons.chevron_right,
                    color: theme.iconTheme.color?.withOpacity(0.5)),
            onTap: () => _showOrderDetailPopup(context, order),
            tileColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }

  // --- Builds the error widget ---
  Widget _buildErrorWidget(String message, Future<void> Function() onRetry) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Container(
            height: MediaQuery.of(context).size.height * 0.6,
            alignment: Alignment.center,
            child: Center(
                child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              color: theme.colorScheme.error, size: 50),
                          const SizedBox(height: 16),
                          Text(message,
                              textAlign: TextAlign.center,
                              style: (theme.textTheme.bodyMedium ??
                                      const TextStyle())
                                  .copyWith(
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.7))),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                              onPressed: onRetry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Thử lại'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      theme.colorScheme.errorContainer,
                                  foregroundColor:
                                      theme.colorScheme.onErrorContainer))
                        ]))))
      ],
    );
  }

  // --- Builds the empty list widget ---
  Widget _buildEmptyListWidget(
      String message, IconData icon, Future<void> Function() onRefresh) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Container(
            height: MediaQuery.of(context).size.height * 0.6,
            alignment: Alignment.center,
            child: Center(
                child: Padding(
                    padding: const EdgeInsets.all(kDefaultPadding * 2),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon,
                              size: 60,
                              color: theme.iconTheme.color?.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(message,
                              textAlign: TextAlign.center,
                              style: (theme.textTheme.titleMedium ??
                                      const TextStyle())
                                  .copyWith(
                                      color: theme.textTheme.titleMedium?.color
                                          ?.withOpacity(0.6))),
                          const SizedBox(height: 20),
                          TextButton.icon(
                              onPressed: onRefresh,
                              icon: Icon(Icons.refresh,
                                  size: 18, color: theme.colorScheme.secondary),
                              label: Text('Làm mới',
                                  style: TextStyle(
                                      color: theme.colorScheme.secondary)))
                        ]))))
      ],
    );
  }
} // End of _KitchenOrderListScreenState
