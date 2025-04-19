import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart'; // For groupBy
import 'package:intl/intl.dart'; // For date formatting
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:shimmer/shimmer.dart'; // Import Shimmer
// import 'management_screen.dart'; // Assuming this exists

// --- Add WebSocket imports ---
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

// --- Constants ---
const double kDefaultPadding = 8.0;
const double kCardElevation = 4.0;
const double kTableGridSpacing = 12.0;
const double kTableItemHeight = 150.0;
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
  int? tableNumber;
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
    );
  }
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

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData appTheme = ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.blueGrey,
      scaffoldBackgroundColor: const Color(0xFF263238),
      fontFamily: GoogleFonts.lato().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF37474F),
        elevation: kCardElevation,
        titleTextStyle: GoogleFonts.oswald(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(blurRadius: 4.0, color: Colors.black45, offset: Offset(2, 2))
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        elevation: kCardElevation,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: const Color(0xFF455A64),
        margin: const EdgeInsets.symmetric(
            vertical: 5, horizontal: kDefaultPadding),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: const Color(0xFF37474F).withOpacity(0.95),
        titleTextStyle: GoogleFonts.oswald(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19),
        contentTextStyle: GoogleFonts.lato(color: Colors.white70, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.teal,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.disabled)) return Colors.grey;
          return states.contains(MaterialState.selected)
              ? Colors.greenAccent
              : Colors.redAccent;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.disabled))
            return Colors.grey.withOpacity(0.3);
          return (states.contains(MaterialState.selected)
                  ? Colors.greenAccent
                  : Colors.redAccent)
              .withOpacity(0.5);
        }),
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
      textTheme: TextTheme(
        bodyMedium: GoogleFonts.lato(
            color: Colors.white.withOpacity(0.85), fontSize: 14),
        titleMedium: GoogleFonts.oswald(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
        headlineSmall: GoogleFonts.oswald(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
        bodySmall: GoogleFonts.lato(color: Colors.grey[400], fontSize: 11.5),
        labelLarge: GoogleFonts.lato(fontWeight: FontWeight.bold),
      ),
      dividerTheme: const DividerThemeData(
          color: Colors.white24, thickness: 0.8, space: 1),
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: Colors.blueGrey,
        brightness: Brightness.dark,
      ).copyWith(secondary: Colors.cyanAccent, error: Colors.redAccent[100]),
      primaryColorLight: Colors.cyanAccent[100],
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
            if (states.contains(MaterialState.selected))
              return Colors.blueGrey[700];
            return const Color(0xFF37474F);
          }),
          side: MaterialStateProperty.all(
              const BorderSide(color: Colors.white30, width: 0.5)),
          shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ),
    );
    return MaterialApp(
      title: 'Restaurant App',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: MenuScreen(),
    );
  }
}

// --- Menu Screen ---
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
    _fetchMenuData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _onTableScroll();
      }
    });
  }

  @override
  void dispose() {
    _tableScrollController.removeListener(_onTableScroll);
    _tableScrollController.dispose();
    _menuScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMenuData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMenu = true;
      _menuErrorMessage = null;
    });
    final url = Uri.parse('https://soa-deploy.up.railway.app/menu/');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> decodedData =
            jsonDecode(utf8.decode(response.bodyBytes));
        final List<MenuItem> allItems = decodedData
            .map((jsonItem) =>
                MenuItem.fromJson(jsonItem as Map<String, dynamic>))
            .toList();
        final validItems =
            allItems.where((item) => item.category.isNotEmpty).toList();
        final groupedItems =
            groupBy(validItems, (MenuItem item) => item.category);
        final uniqueCategories = groupedItems.keys.toList()..sort();
        final newCategoryKeys =
            List.generate(uniqueCategories.length, (_) => GlobalKey());
        final Map<int, MenuItem> itemsById = {
          for (var item in validItems) item.itemId: item
        };
        setState(() {
          _categories = uniqueCategories;
          _menuItemsByCategory = groupedItems;
          _menuItemsById = itemsById;
          _categoryKeys = newCategoryKeys;
          _isLoadingMenu = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _menuErrorMessage = 'Lỗi tải menu (${response.statusCode})';
          _isLoadingMenu = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      print("Error fetching menu data: $e");
      setState(() {
        _menuErrorMessage = 'Không thể tải menu. Kiểm tra kết nối.';
        _isLoadingMenu = false;
      });
    }
  }

  Future<bool> _updateItemStatus(MenuItem item, bool newStatus) async {
    if (!mounted) return false;
    final String itemId = item.itemId.toString();
    if (item.itemId <= 0) {
      print("Error: Invalid item ID (${item.itemId}) for update.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Lỗi: ID món ăn không hợp lệ.'),
            backgroundColor: Colors.redAccent));
      }
      return false;
    }
    final url =
        Uri.parse('https://soa-deploy.up.railway.app/menu/$itemId/status')
            .replace(queryParameters: {'available': newStatus.toString()});
    final headers = {'Content-Type': 'application/json'};
    print('Calling API: PATCH ${url.toString()}');
    try {
      final response = await http
          .patch(url, headers: headers)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return false;
      print('API Response Status Code: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 204) {
        print('API update successful for item ${item.itemId}');
        final updatedItem = item.copyWith(available: newStatus);
        final category = updatedItem.category;
        if (_menuItemsByCategory.containsKey(category)) {
          setState(() {
            final categoryList = _menuItemsByCategory[category]!;
            final itemIndex =
                categoryList.indexWhere((i) => i.itemId == item.itemId);
            if (itemIndex != -1) {
              categoryList[itemIndex] = updatedItem;
              print("Updated item in category '$category'");
            } else {
              print(
                  "Warning: Item ${item.itemId} not found in category '$category' list during update.");
            }
            if (_menuItemsById.containsKey(item.itemId)) {
              _menuItemsById[item.itemId] = updatedItem;
              print("Updated item in ID map");
            } else {
              print(
                  "Warning: Item ${item.itemId} not found in ID map during update.");
            }
          });
        } else {
          print(
              "Warning: Category '$category' not found for item ${item.itemId} during update.");
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
        print(
            'API update failed for item ${item.itemId}. Status: ${response.statusCode}, Body: ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Lỗi cập nhật trạng thái món ăn. Server: ${response.statusCode}'),
              backgroundColor: Colors.redAccent));
        }
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      print('Error calling update API for item ${item.itemId}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Lỗi mạng hoặc timeout khi cập nhật.'),
            backgroundColor: Colors.orangeAccent));
      }
      return false;
    }
  }

  void _updateExclamationMark() {
    if (!mounted ||
        !_tableScrollController.hasClients ||
        !_tableScrollController.position.hasContentDimensions) return;
    final double scrollOffset = _tableScrollController.offset;
    final double maxScroll = _tableScrollController.position.maxScrollExtent;
    final double viewportHeight =
        _tableScrollController.position.viewportDimension;
    bool shouldShow =
        maxScroll > 0 && (scrollOffset + viewportHeight < maxScroll - 20);
    double targetAngle = shouldShow
        ? (math.pi / 12) *
            math.sin(DateTime.now().millisecondsSinceEpoch / 300.0)
        : 0.0;
    if (_showExclamationMark != shouldShow ||
        (_showExclamationMark &&
            (_exclamationMarkAngle - targetAngle).abs() > 0.01)) {
      setState(() {
        _showExclamationMark = shouldShow;
        _exclamationMarkAngle = targetAngle;
      });
    }
  }

  void _onTableScroll() {
    if (!mounted ||
        !_tableScrollController.hasClients ||
        !_tableScrollController.position.hasContentDimensions) return;
    final double scrollOffset = _tableScrollController.offset;
    final double viewportHeight =
        _tableScrollController.position.viewportDimension;
    final int crossAxisCount = _getCrossAxisCount(context);
    final double totalItemHeight = kTableItemHeight + kTableGridSpacing;
    int firstVisibleRow = (scrollOffset / totalItemHeight).floor();
    int lastVisibleRow =
        ((scrollOffset + viewportHeight - 1) / totalItemHeight).floor();
    int firstVisibleIndex = math.max(0, firstVisibleRow * crossAxisCount);
    int lastVisibleIndex =
        math.min(tables.length - 1, (lastVisibleRow + 1) * crossAxisCount - 1);
    bool changed = false;
    for (int i = 0; i < tables.length; i++) {
      bool currentlyVisible = (i >= firstVisibleIndex && i <= lastVisibleIndex);
      if ((tables[i]['isVisible'] as bool? ?? false) != currentlyVisible) {
        tables[i]['isVisible'] = currentlyVisible;
        changed = true;
      }
    }
    if (changed) {
      _updateExclamationMark();
    }
  }

  void _scrollToCategory(int categoryIndex) {
    if (categoryIndex < 1 || categoryIndex > _categories.length) {
      print("Error: Invalid category index $categoryIndex requested.");
      return;
    }
    int arrayIndex = categoryIndex - 1;
    if (arrayIndex >= _categoryKeys.length) {
      print(
          "Error: Category key not found for index $arrayIndex. Keys length: ${_categoryKeys.length}");
      return;
    }
    bool needsViewChange = selectedIndex != categoryIndex;
    if (needsViewChange) {
      setState(() {
        selectedIndex = categoryIndex;
        _isMenuCategoriesExpanded = true;
      });
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _performScroll(arrayIndex);
        }
      });
    } else {
      _performScroll(arrayIndex);
    }
  }

  void _performScroll(int arrayIndex) {
    if (!mounted || arrayIndex < 0 || arrayIndex >= _categoryKeys.length)
      return;
    final key = _categoryKeys[arrayIndex];
    final context = key.currentContext;
    if (context != null) {
      bool isViewingAnyCategory =
          selectedIndex >= 1 && selectedIndex <= _categories.length;
      if (isViewingAnyCategory) {
        if (_menuScrollController.hasClients &&
            _menuScrollController.position.hasContentDimensions) {
          print("Scrolling to category index: $arrayIndex");
          Scrollable.ensureVisible(context,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              alignment: 0.0);
        } else {
          print("Scroll controller not ready, scheduling post-frame scroll.");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _menuScrollController.hasClients) {
              print(
                  "Executing post-frame scroll to category index: $arrayIndex");
              Scrollable.ensureVisible(context,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease);
            } else if (mounted) {
              print(
                  "Post-frame scroll attempt failed: Controller still not ready.");
            }
          });
        }
      } else {
        print(
            "Scroll attempt ignored: Not currently viewing a menu category list.");
      }
    } else {
      print(
          "Scroll Failed: Context is null for category key index $arrayIndex.");
    }
  }

  void _showOrderPopup(BuildContext context, int tableIndex) {
    final int targetTableNumber = tableIndex + 1;
    final kitchenState = _kitchenListKey.currentState;
    if (kitchenState != null) {
      print(
          "Requesting kitchen state to show orders for table $targetTableNumber");
      kitchenState.showOrdersForTable(context, targetTableNumber);
    } else {
      print(
          "Error: KitchenOrderListScreen state not available yet for table $targetTableNumber.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Đang tải danh sách đơn hàng, vui lòng thử lại sau giây lát.'),
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  int _getNavigationRailSelectedIndex() {
    if (selectedIndex == 0) return 0;
    if (selectedIndex == orderScreenIndex) return 1;
    bool isAnyCategorySelected =
        selectedIndex >= 1 && selectedIndex <= _categories.length;
    if (isAnyCategorySelected || _isMenuCategoriesExpanded) return 2;
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
      int tableNum = i + 1;
      int newCount = newCounts[tableNum] ?? 0;
      int currentTablePendingCount =
          tables[i]['pendingOrderCount'] as int? ?? 0;
      if (currentTablePendingCount != newCount) {
        tables[i]['pendingOrderCount'] = newCount;
        changed = true;
      }
    }
    if (changed) {
      print(
          "Updating table counts from Kitchen (via general update): $newCounts");
      setState(() {});
    }
  }

  void _handleTableCleared(int tableNumber) {
    if (!mounted) return;
    print("Received table cleared signal for table: $tableNumber");
    int tableIndex = tableNumber - 1;
    if (tableIndex >= 0 && tableIndex < tables.length) {
      if ((tables[tableIndex]['pendingOrderCount'] as int? ?? 0) > 0) {
        setState(() {
          tables[tableIndex]['pendingOrderCount'] = 0;
          _pendingOrderCountsByTable[tableNumber] = 0;
        });
        print(
            "Set pending order count to 0 for table $tableNumber in MenuScreen.");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('Tất cả đơn chờ cho Bàn $tableNumber đã hoàn thành!'),
              backgroundColor: Colors.lightGreen[700],
              duration: const Duration(seconds: 3),
            ));
          }
        });
      } else {
        print(
            "Table $tableNumber already had 0 pending orders in MenuScreen state. Ignoring redundant clear signal.");
        if (_pendingOrderCountsByTable[tableNumber] != 0) {
          setState(() {
            _pendingOrderCountsByTable[tableNumber] = 0;
          });
        }
      }
    } else {
      print(
          "Warning: Received cleared signal for invalid table number: $tableNumber");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool smallScreen = _isSmallScreen(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: smallScreen ? _buildAppBar(theme) : null,
      drawer: smallScreen ? _buildAppDrawer(theme) : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor,
              theme.scaffoldBackgroundColor
                  .withBlue(theme.scaffoldBackgroundColor.blue + 5)
                  .withGreen(theme.scaffoldBackgroundColor.green + 2),
            ],
            stops: const [0.3, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                if (!smallScreen) _buildNavigationRail(theme),
                if (!smallScreen)
                  const VerticalDivider(
                      width: 1, thickness: 1, color: Colors.white12),
                Expanded(
                  child: Column(
                    children: [
                      if (!smallScreen) _buildLargeScreenHeader(theme),
                      if (!smallScreen)
                        Container(
                            height: 0.8,
                            color: theme.dividerTheme.color ?? Colors.white24),
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
      title: const Text('WELCOME'),
      actions: _buildAppBarActions(),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      IconButton(
          icon: const Icon(Icons.person_outline),
          tooltip: 'Tài khoản',
          onPressed: () {}),
      IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Tìm kiếm',
          onPressed: () {}),
      const SizedBox(width: kDefaultPadding / 2),
    ];
  }

  Widget _buildAppDrawer(ThemeData theme) {
    bool isMenuSelected =
        selectedIndex >= 1 && selectedIndex <= _categories.length;
    Color highlight = theme.colorScheme.secondary;
    final divider = Divider(
      color: theme.dividerTheme.color?.withOpacity(0.5) ?? Colors.white24,
      thickness: theme.dividerTheme.thickness ?? 1,
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
          _buildDrawerItem(
              theme,
              Icons.table_restaurant_outlined,
              'Danh sách bàn ăn',
              0,
              selectedIndex,
              highlight,
              () => setState(() {
                    selectedIndex = 0;
                    _isMenuCategoriesExpanded = false;
                    Navigator.pop(context);
                  })),
          divider,
          _buildDrawerItem(
              theme,
              Icons.receipt_long_outlined,
              'Danh sách đơn hàng',
              orderScreenIndex,
              selectedIndex,
              highlight,
              () => setState(() {
                    selectedIndex = orderScreenIndex;
                    _isMenuCategoriesExpanded = false;
                    Navigator.pop(context);
                  })),
          divider,
          ExpansionTile(
            leading: Icon(Icons.restaurant_menu_outlined,
                color: isMenuSelected ? highlight : Colors.white70, size: 24),
            title: Text('Danh sách món ăn',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isMenuSelected ? highlight : Colors.white,
                  fontWeight:
                      isMenuSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14.5,
                )),
            initiallyExpanded: _isMenuCategoriesExpanded,
            onExpansionChanged: (expanded) {
              if (!_isLoadingMenu && _menuErrorMessage == null) {
                setState(() => _isMenuCategoriesExpanded = expanded);
              } else if (expanded) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_isLoadingMenu
                      ? 'Đang tải menu...'
                      : 'Lỗi tải menu, không thể mở rộng.'),
                  duration: const Duration(seconds: 1),
                ));
                Future.delayed(Duration.zero, () {
                  if (mounted)
                    setState(() => _isMenuCategoriesExpanded = false);
                });
              }
            },
            iconColor: Colors.white,
            collapsedIconColor: Colors.white70,
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
                                style: TextStyle(color: Colors.red[300])))
                        : _categories.isEmpty
                            ? Center(
                                child: Text("Chưa có danh mục nào.",
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
          color: isSelected ? highlightColor : Colors.white70, size: 24),
      title: Text(
        title,
        style: drawerItemStyle?.copyWith(
          color: isSelected ? highlightColor : Colors.white,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      onTap: onTapAction,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.secondary.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: kDefaultPadding * 2.5),
      dense: true,
    );
  }

  Widget _buildNavigationRail(ThemeData theme) {
    final Color selectedColor = theme.colorScheme.secondary;
    final Color unselectedColor = Colors.white;
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
                      : unselectedColor.withOpacity(0.8),
                  size: isSelected ? 30 : 28,
                ),
                const SizedBox(width: kDefaultPadding * 1.5),
                Flexible(
                  child: Text(
                    data['label'] as String,
                    style: isSelected
                        ? railLabelStyle?.copyWith(
                            color: selectedColor, fontWeight: FontWeight.w600)
                        : railLabelStyle?.copyWith(
                            color: unselectedColor.withOpacity(0.7),
                            fontWeight: FontWeight.w500),
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
            color: theme.dividerTheme.color?.withOpacity(0.5) ?? Colors.white24,
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
        selectedIndex = 0;
        _isMenuCategoriesExpanded = false;
      } else if (index == 1) {
        selectedIndex = orderScreenIndex;
        _isMenuCategoriesExpanded = false;
      } else if (index == 2) {
        if (_isLoadingMenu || _menuErrorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isLoadingMenu
                ? 'Đang tải menu...'
                : _menuErrorMessage ?? 'Lỗi menu'),
            duration: const Duration(seconds: 1),
          ));
          return;
        }
        _isMenuCategoriesExpanded = !_isMenuCategoriesExpanded;
        if (_isMenuCategoriesExpanded) {
          bool isViewingTablesOrOrders =
              (selectedIndex == 0 || selectedIndex == orderScreenIndex);
          bool noCategorySelected =
              !(selectedIndex >= 1 && selectedIndex <= _categories.length);
          if ((isViewingTablesOrOrders || noCategorySelected) &&
              _categories.isNotEmpty) {
            selectedIndex = 1;
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && _isMenuCategoriesExpanded) {
                _scrollToCategory(1);
              }
            });
          }
        }
        if (_isMenuCategoriesExpanded && _categories.isEmpty) {
          _isMenuCategoriesExpanded = false;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Chưa có danh mục món ăn nào.'),
            duration: Duration(seconds: 2),
          ));
        }
      }
    });
  }

  Widget _buildLogo({double height = kLogoHeight, double? width}) {
    const String logoAssetPath = 'assets/spidermen.jpg';
    return ClipRRect(
      borderRadius: BorderRadius.circular(kDefaultPadding * 0.75),
      child: Image.asset(
        logoAssetPath,
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          print("Error loading logo asset '$logoAssetPath': $error");
          return Container(
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
              ));
        },
        frameBuilder: (context, child, frame, wasSyncLoaded) {
          if (wasSyncLoaded) {
            return child;
          }
          return AnimatedOpacity(
            child: child,
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        },
      ),
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
              child: Text('WELCOME',
                  textAlign: TextAlign.center,
                  style: theme.appBarTheme.titleTextStyle)),
          ..._buildAppBarActions(),
        ],
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
        bool hasPendingOrders = pendingCount > 0;
        bool isHovered = _hoveredTableIndex == index;
        Color cardBackgroundColor;
        Color iconColor;
        Color textColor;
        Color badgeColor = theme.colorScheme.error;
        Color borderColor = Colors.transparent;
        double elevation = kCardElevation;
        if (hasPendingOrders) {
          cardBackgroundColor = Color.lerp(theme.cardTheme.color!,
              theme.colorScheme.error.withOpacity(0.4), 0.5)!;
          iconColor = Colors.yellowAccent[100]!;
          textColor = Colors.white;
          borderColor = theme.colorScheme.error.withOpacity(0.8);
          elevation = kCardElevation + 4;
        } else {
          cardBackgroundColor = theme.cardTheme.color!;
          iconColor = Colors.white.withOpacity(0.65);
          textColor = Colors.white.withOpacity(0.85);
        }
        if (isHovered) {
          cardBackgroundColor = cardBackgroundColor.withOpacity(0.85);
          borderColor = hasPendingOrders
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
                  color: Colors.black.withOpacity(isHovered ? 0.35 : 0.2),
                  blurRadius: isHovered ? 10 : 5,
                  spreadRadius: 0,
                  offset: Offset(0, isHovered ? 4 : 2),
                )
              ],
            ),
            child: Material(
              color: cardBackgroundColor,
              borderRadius: BorderRadius.circular(13),
              clipBehavior: Clip.antiAlias,
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
                          Icon(Icons.table_restaurant_rounded,
                              size: 55, color: iconColor),
                          const SizedBox(height: kDefaultPadding * 1.5),
                          Text(
                            table['name'] as String? ?? 'Bàn ?',
                            style: theme.textTheme.titleMedium?.copyWith(
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
                    if (hasPendingOrders)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(6.5),
                          decoration: BoxDecoration(
                              color: badgeColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.9),
                                  width: 1.8),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black87,
                                    blurRadius: 5,
                                    offset: Offset(1, 1))
                              ]),
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                          child: Center(
                              child: Text('$pendingCount',
                                  style: const TextStyle(
                                    color: Colors.white,
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
    int categoryArrayIndex = selectedIndex - 1;
    if (categoryArrayIndex < 0 || categoryArrayIndex >= _categories.length) {
      return Center(
          child: Text("Danh mục không hợp lệ.",
              style: theme.textTheme.bodyMedium));
    }
    if (categoryArrayIndex >= _categoryKeys.length) {
      return Center(
          child: Text("Đang chuẩn bị danh mục...",
              style: theme.textTheme.bodySmall));
    }
    final String categoryName = _categories[categoryArrayIndex];
    final List<MenuItem> itemsInCategory =
        _menuItemsByCategory[categoryName] ?? [];
    final GlobalKey categoryHeaderKey = _categoryKeys[categoryArrayIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          key: categoryHeaderKey,
          padding: const EdgeInsets.fromLTRB(kDefaultPadding * 2,
              kDefaultPadding * 2, kDefaultPadding * 2, kDefaultPadding),
          child: Text(categoryName, style: theme.textTheme.headlineSmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding * 2),
          child: Divider(
              color: theme.dividerTheme.color,
              thickness: theme.dividerTheme.thickness),
        ),
        const SizedBox(height: kDefaultPadding),
        if (itemsInCategory.isEmpty)
          Expanded(
              child: Center(
            child: Padding(
              padding: const EdgeInsets.all(kDefaultPadding * 2),
              child: Text(
                "Không có món ăn nào trong danh mục '$categoryName'.",
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ))
        else
          Expanded(
            child: ListView.builder(
              key: PageStorageKey<String>('menuList_$categoryName'),
              controller: _menuScrollController,
              padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
              itemCount: itemsInCategory.length,
              itemBuilder: (context, itemIndex) {
                MenuItem currentItemFromCategory = itemsInCategory[itemIndex];
                MenuItem item =
                    _menuItemsById[currentItemFromCategory.itemId] ??
                        currentItemFromCategory;
                String? relativePathFromDb = item.img;
                Widget imageWidget;
                if (relativePathFromDb != null &&
                    relativePathFromDb.isNotEmpty) {
                  String assetPath = 'assets/' +
                      (relativePathFromDb.startsWith('/')
                          ? relativePathFromDb.substring(1)
                          : relativePathFromDb);
                  print(
                      "Attempting to load asset: $assetPath for item: ${item.name}");
                  imageWidget = Image.asset(assetPath,
                      width: kMenuItemImageSize,
                      height: kMenuItemImageSize,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print("Error loading asset '$assetPath': $error");
                        return _buildPlaceholderImage(hasError: true);
                      },
                      frameBuilder: (context, child, frame, wasSyncLoaded) =>
                          wasSyncLoaded
                              ? child
                              : AnimatedOpacity(
                                  opacity: frame == null ? 0 : 1,
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeOut,
                                  child: child,
                                ));
                } else {
                  print("No image path for item: ${item.name}");
                  imageWidget = _buildPlaceholderImage();
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
                        child: imageWidget,
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
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontSize: 16.5),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: kDefaultPadding * 0.6),
                              Text(
                                "ID: ${item.itemId}",
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontSize: 11),
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
    return Container(
      width: kMenuItemImageSize,
      height: kMenuItemImageSize,
      color: const Color(0xFF37474F),
      child: Icon(
        hasError ? Icons.image_not_supported_outlined : Icons.restaurant,
        color: hasError ? Colors.redAccent.withOpacity(0.7) : Colors.grey[500],
        size: kMenuItemImageSize * 0.4,
      ),
    );
  }

  Widget _buildBottomActionBar(ThemeData theme) {
    final footerTextStyle = theme.textTheme.bodySmall?.copyWith(
      color: Colors.white.withOpacity(0.8),
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
    if (!_showExclamationMark) return const SizedBox.shrink();
    double rightEdge =
        smallScreen ? kDefaultPadding : kRailWidth + kDefaultPadding;
    const String exclamationAssetPath = 'assets/exclamation_mark.png';
    return Positioned(
      right: rightEdge - kExclamationMarkSize / 2,
      top: MediaQuery.of(context).size.height / 2 - kExclamationMarkSize / 2,
      child: Transform.rotate(
        angle: _exclamationMarkAngle,
        child: IgnorePointer(
          child: Image.asset(
            exclamationAssetPath,
            width: kExclamationMarkSize,
            height: kExclamationMarkSize,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.warning_amber_rounded,
                color: Colors.yellowAccent,
                size: kExclamationMarkSize),
          ),
        ),
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
        final categoryViewIndex = index + 1;
        final isSelected = selectedIndex == categoryViewIndex;
        final categoryName = _categories[index];
        final selectedBgColor = theme.colorScheme.secondary.withOpacity(0.9);
        final unselectedBgColor =
            theme.cardTheme.color?.withOpacity(0.8) ?? const Color(0xFF455A64);
        final selectedBorderColor = theme.colorScheme.secondary;
        final hoverColor = theme.colorScheme.secondary.withOpacity(0.15);
        final splashColor = theme.colorScheme.secondary.withOpacity(0.25);
        final shadowColor = Colors.black.withOpacity(isSelected ? 0.3 : 0.15);
        const animationDuration = Duration(milliseconds: 250);
        return AnimatedContainer(
          duration: animationDuration,
          curve: Curves.easeInOutCubic,
          margin: EdgeInsets.all(isSelected ? 0 : 2.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.0),
            boxShadow: [
              BoxShadow(
                  color: shadowColor,
                  blurRadius: isSelected ? 8.0 : 4.0,
                  offset: Offset(0, isSelected ? 4.0 : 2.0))
            ],
          ),
          child: ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith<Color>(
                  (Set<MaterialState> states) {
                if (states.contains(MaterialState.pressed))
                  return splashColor.withOpacity(0.4);
                return isSelected ? selectedBgColor : unselectedBgColor;
              }),
              foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
              overlayColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) {
                if (states.contains(MaterialState.hovered)) return hoverColor;
                return null;
              }),
              shadowColor: MaterialStateProperty.all(Colors.transparent),
              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      side: BorderSide(
                          color: isSelected
                              ? selectedBorderColor
                              : Colors.transparent,
                          width: 1.5))),
              padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                  const EdgeInsets.symmetric(
                      horizontal: kDefaultPadding,
                      vertical: kDefaultPadding * 0.75)),
              minimumSize: MaterialStateProperty.all(const Size(0, 40)),
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: () {
              _scrollToCategory(categoryViewIndex);
              if (isDrawer) Navigator.pop(context);
            },
            child: AnimatedDefaultTextStyle(
              duration: animationDuration,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: isSelected ? 0.4 : 0.2,
                  fontFamily:
                      Theme.of(context).textTheme.labelLarge?.fontFamily),
              child: Text(
                categoryName,
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
    if (selectedIndex == orderScreenIndex) {
      stackIndex = 1;
    } else if (selectedIndex >= 1 && selectedIndex <= _categories.length) {
      stackIndex = 2;
    }
    List<Widget> pages = [
      _buildTableGrid(theme),
      KitchenOrderListScreen(
        key: _kitchenListKey,
        onOrderUpdate: _updateTableOrderCounts,
        onTableCleared: _handleTableCleared,
      ),
      Builder(builder: (context) {
        bool isMenuView =
            selectedIndex >= 1 && selectedIndex <= _categories.length;
        if (isMenuView) {
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
                    const Icon(Icons.cloud_off_outlined,
                        color: Colors.redAccent, size: 50),
                    const SizedBox(height: kDefaultPadding * 2),
                    Text(_menuErrorMessage!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.white70)),
                    const SizedBox(height: kDefaultPadding * 2),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent[100]),
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
                        color: Colors.grey[600], size: 50),
                    const SizedBox(height: kDefaultPadding * 2),
                    Text("Không tìm thấy danh mục món ăn nào.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.white70)),
                    const SizedBox(height: kDefaultPadding * 2),
                    ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                theme.colorScheme.secondary.withOpacity(0.8)),
                        onPressed: _fetchMenuData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tải lại Menu'))
                  ],
                ),
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
        ? (Colors.grey[500] ?? Colors.grey)
        : (displayValue
            ? (Colors.greenAccent[100] ?? Colors.greenAccent)
            : (Colors.redAccent[100] ?? Colors.redAccent));
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
                            print(
                                "API update failed, reverting switch for ${widget.item.name}");
                          } else {
                            print(
                                "API update succeeded for ${widget.item.name}");
                          }
                          _isUpdating = false;
                        });
                      } else {
                        print(
                            "Switch widget unmounted after API call for ${widget.item.name}");
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
          style: theme.textTheme.bodySmall?.copyWith(
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

// --- Kitchen Order List Screen ---
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
  // ***** MODIFIED: Use ValueNotifier for pending orders *****
  final ValueNotifier<List<KitchenListOrder>> _pendingOrdersNotifier =
      ValueNotifier([]);
  List<KitchenListOrder> get _pendingOrders => _pendingOrdersNotifier.value;
  set _pendingOrders(List<KitchenListOrder> newList) {
    _pendingOrdersNotifier.value = newList;
  }

  List<KitchenListOrder> _completedOrders = [];
  bool _isLoadingPending = true;
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

  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    print("KitchenOrderListScreen initState");
    _fetchPendingOrders();
    _connectWebSocket();
  }

  @override
  void dispose() {
    print("KitchenOrderListScreen dispose");
    _disconnectWebSocket();
    _reconnectTimer?.cancel();
    _pendingOrdersNotifier.dispose();
    super.dispose();
  } // Dispose notifier

  // --- WebSocket Methods (unchanged) ---
  void _connectWebSocket() {
    if (_isConnecting || _isConnected || _channel != null) return;
    if (!mounted) return;
    setState(() {
      _isConnecting = true;
    });
    print("WebSocket: Attempting to connect to $kWebSocketUrl...");
    try {
      _channel = WebSocketChannel.connect(Uri.parse(kWebSocketUrl));
      _isConnected = false;
      if (!mounted) {
        _channel?.sink.close(status.goingAway);
        _channel = null;
        _isConnecting = false;
        return;
      }
      print("WebSocket: Connection established, listening for messages...");
      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _reconnectAttempts = 0;
      });
      _reconnectTimer?.cancel();
      _channel!.stream.listen(
        (message) {
          if (!mounted) return;
          print("WebSocket: Received message: $message");
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          if (!mounted) return;
          print("WebSocket: Error: $error");
          setState(() {
            _isConnected = false;
            _isConnecting = false;
          });
          _scheduleReconnect();
        },
        onDone: () {
          if (!mounted) return;
          print(
              "WebSocket: Connection closed (onDone). Code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason}");
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
      print("WebSocket: Connection failed: $e");
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
      _channel = null;
      _scheduleReconnect();
    }
  }

  void _disconnectWebSocket() {
    print("WebSocket: Disconnecting...");
    _reconnectTimer?.cancel();
    _channel?.sink.close(status.goingAway);
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
  }

  void _scheduleReconnect() {
    if (!mounted || _reconnectTimer?.isActive == true || _isConnecting) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print("WebSocket: Max reconnect attempts reached.");
      _reconnectAttempts = 0;
      return;
    }
    _reconnectAttempts++;
    final delay =
        _initialReconnectDelay * math.pow(1.5, _reconnectAttempts - 1);
    final clampedDelay =
        delay > _maxReconnectDelay ? _maxReconnectDelay : delay;
    print(
        "WebSocket: Scheduling reconnect attempt #$_reconnectAttempts in ${clampedDelay.inSeconds} seconds...");
    _reconnectTimer = Timer(clampedDelay, () {
      if (mounted) {
        _connectWebSocket();
      }
    });
  }

  void _handleWebSocketMessage(dynamic message) {
    print("WebSocket: Handling message - Triggering pending order refresh.");
    dynamic decodedMessage;
    if (message is String) {
      try {
        decodedMessage = jsonDecode(message);
        print("WebSocket: Decoded message: $decodedMessage");
      } catch (e) {
        print("WebSocket: Message is not valid JSON: $message");
      }
    } else {
      print(
          "WebSocket: Received non-string message type: ${message.runtimeType}");
    }
    if (mounted) {
      _fetchPendingOrders(forceRefresh: true);
    }
  }

  // --- Data Fetching Methods ---
  // ***** MODIFIED: Update _pendingOrdersNotifier in setState *****
  Future<void> _fetchPendingOrders({bool forceRefresh = false}) async {
    if (_isLoadingPending && !forceRefresh) return;
    if (!mounted) return;
    if (forceRefresh) {
      print("Kitchen: Force refreshing pending orders.");
      final pendingSessionIds = _pendingOrders.map((o) => o.sessionId).toSet();
      _tableNumberCache
          .removeWhere((sessionId, _) => pendingSessionIds.contains(sessionId));
      _fetchingTableSessionIds
          .removeWhere((sessionId) => pendingSessionIds.contains(sessionId));
    }
    setState(() {
      _isLoadingPending = true;
      _pendingErrorMessage = null;
      if (forceRefresh) _inProgressOrderIds.clear();
    });
    List<KitchenListOrder> finalOrders = [];
    String? errorMsg;
    Map<int, int> countsByTable = {};
    try {
      final results = await Future.wait([
        _fetchOrdersWithStatus('ordered'),
        _fetchOrdersWithStatus('in_progress'),
      ]);
      final orderedOrders = results[0];
      final inProgressOrders = results[1];
      List<KitchenListOrder> combinedPendingOrders = [
        ...orderedOrders,
        ...inProgressOrders,
      ];
      final uniquePendingOrdersMap = <int, KitchenListOrder>{
        for (var order in combinedPendingOrders) order.orderId: order
      };
      final sortedOrders = uniquePendingOrdersMap.values.toList()
        ..sort((a, b) => a.orderTime.compareTo(b.orderTime));
      final ordersWithTableNumbers =
          await _fetchTableNumbersForOrders(sortedOrders);
      finalOrders = ordersWithTableNumbers;
      countsByTable.clear();
      for (var order in finalOrders) {
        if (order.tableNumber != null && order.tableNumber! > 0) {
          countsByTable[order.tableNumber!] =
              (countsByTable[order.tableNumber!] ?? 0) + 1;
        }
      }
      try {
        widget.onOrderUpdate?.call(countsByTable);
      } catch (e) {
        print("Kitchen: Error calling onOrderUpdate callback: $e");
      }
      _inProgressOrderIds.clear();
      for (var order in finalOrders) {
        if (inProgressOrders
            .any((ipOrder) => ipOrder.orderId == order.orderId)) {
          _inProgressOrderIds.add(order.orderId);
        }
      }
    } catch (e) {
      errorMsg = "Lỗi tải đơn hàng: ${e.toString()}";
      print("Kitchen: Error fetching PENDING orders: $e");
      if (mounted) {
        try {
          widget.onOrderUpdate?.call({});
        } catch (e) {
          print(
              "Kitchen: Error calling onOrderUpdate callback during error handling: $e");
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _pendingOrders = finalOrders; // This now updates the notifier
          _pendingErrorMessage = errorMsg;
          _isLoadingPending = false;
        });
        print(
            "Kitchen: Finished fetching pending orders. Count: ${finalOrders.length}");
      }
    }
  }

  Future<void> _fetchCompletedOrders({bool forceRefresh = false}) async {
    if (_isLoadingCompleted && !forceRefresh) return;
    if (!mounted) return;
    if (forceRefresh) {
      print("Kitchen: Force refreshing completed orders.");
      final completedSessionIds =
          _completedOrders.map((o) => o.sessionId).toSet();
      _tableNumberCache.removeWhere(
          (sessionId, _) => completedSessionIds.contains(sessionId));
      _fetchingTableSessionIds
          .removeWhere((sessionId) => completedSessionIds.contains(sessionId));
    }
    setState(() {
      _isLoadingCompleted = true;
      _completedErrorMessage = null;
    });
    List<KitchenListOrder> finalOrders = [];
    String? errorMsg;
    try {
      final servedOrders = await _fetchOrdersWithStatus('served');
      final ordersWithTableNumbers =
          await _fetchTableNumbersForOrders(servedOrders);
      ordersWithTableNumbers.sort((a, b) => b.orderTime.compareTo(a.orderTime));
      finalOrders = ordersWithTableNumbers;
      _completedOrdersLoaded = true;
    } catch (e) {
      errorMsg = "Lỗi tải đơn đã hoàn thành: ${e.toString()}";
      print("Kitchen: Error fetching COMPLETED orders: $e");
    } finally {
      if (mounted) {
        setState(() {
          _completedOrders = finalOrders;
          _completedErrorMessage = errorMsg;
          _isLoadingCompleted = false;
        });
        print(
            "Kitchen: Finished fetching completed orders. Count: ${finalOrders.length}");
      }
    }
  }

  Future<List<KitchenListOrder>> _fetchOrdersWithStatus(String status) async {
    final baseUrl =
        'https://soa-deploy.up.railway.app/kitchen/get-orders-by-status/';
    final url = Uri.parse('$baseUrl$status');
    print("Kitchen API: Fetching orders with status '$status': $url");
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (!mounted) return [];
      if (response.statusCode == 200) {
        final List<dynamic> decodedData =
            jsonDecode(utf8.decode(response.bodyBytes));
        return decodedData
            .map((orderData) =>
                KitchenListOrder.fromJson(orderData as Map<String, dynamic>))
            .toList();
      } else {
        String errorBody = response.body;
        try {
          errorBody = utf8.decode(response.bodyBytes);
        } catch (_) {}
        print(
            "Kitchen API: Error fetching orders with status '$status': ${response.statusCode}, Body: $errorBody");
        throw Exception(
            'Failed to load orders (status $status): ${response.statusCode}');
      }
    } catch (e) {
      print(
          "Kitchen API: Network/Timeout Error fetching orders with status '$status': $e");
      throw Exception('Network error fetching orders (status $status)');
    }
  }

  Future<int?> _fetchTableNumber(int sessionId) async {
    if (_tableNumberCache.containsKey(sessionId)) {
      final cachedValue = _tableNumberCache[sessionId];
      return cachedValue == -1 ? null : cachedValue;
    }
    if (_fetchingTableSessionIds.contains(sessionId)) {
      return null;
    }
    if (!mounted) return null;
    _fetchingTableSessionIds.add(sessionId);
    final url = Uri.parse(
        'https://soa-deploy.up.railway.app/order/session/$sessionId/table-number');
    int? resultTableNumber;
    int cacheValue = -1;
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (!mounted) {
        _fetchingTableSessionIds.remove(sessionId);
        return null;
      }
      if (response.statusCode == 200) {
        final decodedData = jsonDecode(utf8.decode(response.bodyBytes));
        dynamic tableNumberData;
        if (decodedData is Map && decodedData.containsKey('table_number')) {
          tableNumberData = decodedData['table_number'];
        } else if (decodedData is int || decodedData is String) {
          tableNumberData = decodedData;
        }
        if (tableNumberData is int) {
          resultTableNumber = tableNumberData;
        } else if (tableNumberData is String) {
          resultTableNumber = int.tryParse(tableNumberData);
        }
        if (resultTableNumber != null && resultTableNumber > 0) {
          cacheValue = resultTableNumber;
        } else {
          print(
              "Warning: Could not parse a valid table number for session $sessionId from data: $tableNumberData");
          resultTableNumber = null;
          cacheValue = -1;
        }
      } else {
        print(
            "Error fetching table number for session $sessionId: ${response.statusCode}, Body: ${response.body}");
        resultTableNumber = null;
        cacheValue = -1;
      }
    } catch (e) {
      print("Exception fetching table number for session $sessionId: $e");
      resultTableNumber = null;
      cacheValue = -1;
      if (!mounted) {
        _fetchingTableSessionIds.remove(sessionId);
        return null;
      }
    } finally {
      if (mounted) {
        setState(() {
          _tableNumberCache[sessionId] = cacheValue;
          _fetchingTableSessionIds.remove(sessionId);
        });
      } else {
        _tableNumberCache[sessionId] = cacheValue;
        _fetchingTableSessionIds.remove(sessionId);
      }
    }
    return resultTableNumber;
  }

  Future<List<KitchenListOrder>> _fetchTableNumbersForOrders(
      List<KitchenListOrder> orders) async {
    if (orders.isEmpty || !mounted) return [];
    final List<Future<void>> fetchFutures = [];
    final Set<int> sessionIdsToFetch = {};
    for (var order in orders) {
      if (!_tableNumberCache.containsKey(order.sessionId) &&
          !_fetchingTableSessionIds.contains(order.sessionId)) {
        sessionIdsToFetch.add(order.sessionId);
      }
    }
    for (int sessionId in sessionIdsToFetch) {
      fetchFutures.add(_fetchTableNumber(sessionId));
    }
    if (fetchFutures.isNotEmpty) {
      try {
        await Future.wait(fetchFutures);
      } catch (e) {
        print("Error occurred during Future.wait for table numbers: $e");
      }
    }
    if (!mounted) return [];
    List<KitchenListOrder> updatedOrders = [];
    for (var order in orders) {
      final cachedTableNum = _tableNumberCache[order.sessionId];
      if (cachedTableNum != null && order.tableNumber != cachedTableNum) {
        order.tableNumber = cachedTableNum;
      }
      updatedOrders.add(order);
    }
    return updatedOrders;
  }

  // Trong class _KitchenOrderListScreenState

  Future<void> _fetchOrderDetail(
      int orderId, StateSetter setDialogState) async {
    // Kiểm tra xem Widget chính và Dialog có còn được mount không
    if (!mounted) return;
    bool isDialogMounted = true;
    // Sử dụng context được truyền vào từ StatefulBuilder của Dialog
    // Nếu không có context hợp lệ, không tiếp tục
    try {
      (context as Element).widget; // Một cách để kiểm tra context hợp lệ
    } catch (e) {
      isDialogMounted = false;
    }
    if (!isDialogMounted) {
      print(
          "Order detail fetch cancelled: Dialog is no longer mounted for Order $orderId.");
      return;
    }

    // --- Bắt đầu trạng thái loading trong Dialog ---
    try {
      setDialogState(() {
        _isDetailLoading = true;
        _detailErrorMessage = null;
        _detailItems = []; // Xóa dữ liệu cũ
        _updatingItemIds.clear();
        _isCompletingAll = false;
      });
    } catch (e) {
      // Xử lý trường hợp không thể cập nhật state của dialog (có thể do dialog đóng quá nhanh)
      print("Error setting dialog state for loading (Order $orderId): $e");
      // Đảm bảo các cờ loading được reset nếu có lỗi
      _isDetailLoading = false;
      _detailItems = [];
      return; // Không tiếp tục nếu không set state được
    }

    // --- Gọi API ---
    final url = Uri.parse(
        'https://soa-deploy.up.railway.app/kitchen/order/$orderId/items');
    print('Fetching order detail: ${url.toString()}');

    try {
      // ***** GIẢM TIMEOUT *****
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 8)); // Giảm còn 8 giây

      // Kiểm tra lại mount status *sau khi* await
      if (!mounted) return;
      isDialogMounted = true;
      try {
        (context as Element).widget;
      } catch (e) {
        isDialogMounted = false;
      }
      if (!isDialogMounted) {
        print(
            "Order detail fetch cancelled after API call: Dialog no longer mounted for Order $orderId.");
        return;
      }

      // --- Xử lý Response ---
      if (response.statusCode == 200) {
        // Thành công
        final List<dynamic> decodedData =
            jsonDecode(utf8.decode(response.bodyBytes));
        final List<KitchenOrderDetailItem> fetchedItems = decodedData
            .map((jsonItem) => KitchenOrderDetailItem.fromJson(
                jsonItem as Map<String, dynamic>))
            .toList();

        // Cập nhật state của Dialog với dữ liệu mới
        try {
          setDialogState(() {
            _detailItems = fetchedItems;
            _isDetailLoading = false;
          });
        } catch (e) {
          // Fallback nếu set state dialog lỗi
          print("Error setting dialog state with data (Order $orderId): $e");
          _detailItems = fetchedItems;
          _isDetailLoading = false;
        }
      } else {
        // Lỗi từ Server (không phải 200 OK)
        print(
            "Error fetching order detail for $orderId: ${response.statusCode}");
        final errorBody = utf8.decode(response.bodyBytes); // Đọc body lỗi
        String serverErrorMsg = '';
        try {
          // Thử decode JSON để lấy thông tin chi tiết lỗi từ server (nếu có)
          final decodedError = jsonDecode(errorBody);
          if (decodedError is Map && decodedError.containsKey('detail')) {
            serverErrorMsg =
                ': ${decodedError['detail']}'; // Thêm chi tiết lỗi nếu có key 'detail'
          }
        } catch (_) {
          // Bỏ qua nếu body không phải JSON hợp lệ
          print(
              "Server error response body is not valid JSON or doesn't contain 'detail'. Body: $errorBody");
        }

        // Cập nhật state Dialog với thông báo lỗi
        try {
          setDialogState(() {
            _detailErrorMessage =
                'Lỗi tải chi tiết (${response.statusCode})$serverErrorMsg';
            _isDetailLoading = false;
          });
        } catch (e) {
          print(
              "Error setting dialog state with server error (Order $orderId): $e");
          _detailErrorMessage =
              'Lỗi tải chi tiết (${response.statusCode})$serverErrorMsg';
          _isDetailLoading = false;
        }
      }
      // ***** XỬ LÝ TIMEOUT CỤ THỂ *****
    } on TimeoutException catch (e) {
      print("Timeout Error fetching order detail for order $orderId: $e");
      // Kiểm tra mount lại sau khi bắt exception
      if (!mounted) return;
      isDialogMounted = true;
      try {
        (context as Element).widget;
      } catch (e) {
        isDialogMounted = false;
      }
      if (!isDialogMounted) return;

      // Cập nhật state Dialog với thông báo lỗi Timeout
      try {
        setDialogState(() {
          _detailErrorMessage =
              'Yêu cầu quá thời gian quy định (8 giây). Vui lòng thử lại.';
          _isDetailLoading = false;
        });
      } catch (se) {
        // Fallback
        print(
            "Error setting dialog state with timeout error (Order $orderId): $se");
        _detailErrorMessage =
            'Yêu cầu quá thời gian quy định (8 giây). Vui lòng thử lại.';
        _isDetailLoading = false;
      }
    } catch (e) {
      // Xử lý các lỗi khác (mạng, parsing JSON, ...)
      print("Network/Other Error fetching order detail for order $orderId: $e");
      // Kiểm tra mount lại sau khi bắt exception
      if (!mounted) return;
      isDialogMounted = true;
      try {
        (context as Element).widget;
      } catch (e) {
        isDialogMounted = false;
      }
      if (!isDialogMounted) return;

      // Cập nhật state Dialog với thông báo lỗi chung
      try {
        setDialogState(() {
          _detailErrorMessage =
              'Lỗi kết nối hoặc xử lý dữ liệu. Vui lòng thử lại.';
          _isDetailLoading = false;
        });
      } catch (se) {
        // Fallback
        print(
            "Error setting dialog state with catch error (Order $orderId): $se");
        _detailErrorMessage =
            'Lỗi kết nối hoặc xử lý dữ liệu. Vui lòng thử lại.';
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
          // ***** IMPORTANT: Use dialogContext consistently inside builder *****
          return StatefulBuilder(builder: (context, setDialogState) {
            // Use 'context' from builder here
            WidgetsBinding.instance.addPostFrameCallback((_) {
              bool shouldFetch = mounted &&
                  (ModalRoute.of(dialogContext)?.isCurrent ?? false) &&
                  _detailItems.isEmpty &&
                  !_isDetailLoading &&
                  _detailErrorMessage == null;
              if (shouldFetch) {
                _fetchOrderDetail(order.orderId, setDialogState);
              }
            });
            bool canCompleteAll = _detailItems
                    .any((item) => item.status.toLowerCase() != 'served') &&
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
                                  : Colors.grey[600],
                              size: 24),
                          tooltip: 'Hoàn thành tất cả món chưa phục vụ',
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
                        tooltip: 'Tải lại chi tiết đơn',
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
                  _isCompletingAll, dialogContext), // Pass dialogContext
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
                              ? Colors.grey
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
      print(
          "Order detail dialog closed for #${order.orderId}. Local popup state reset.");
    });
  }

  // Trong class _KitchenOrderListScreenState

  // ***** MODIFIED: Use ValueListenableBuilder for auto-closing table orders list *****
  void showOrdersForTable(BuildContext parentContext, int tableNumber) {
    final theme = Theme.of(parentContext);
    print("Showing popup for table $tableNumber.");

    // Biến để lưu trữ tham chiếu đến listener, giúp việc remove dễ dàng hơn
    VoidCallback? _listenerRef;

    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setStateInDialog) {
          // --- Listener Function ---
          _listenerRef = () {
            // Kiểm tra dialog còn tồn tại và màn hình chính còn mounted không
            if (!mounted ||
                !(ModalRoute.of(dialogContext)?.isCurrent ?? false)) {
              if (_listenerRef != null) {
                _pendingOrdersNotifier.removeListener(_listenerRef!);
                print(
                    "Listener removed because dialog/screen is no longer active.");
              }
              return;
            }

            // Lấy danh sách pending mới nhất
            final currentPendingOrders = _pendingOrdersNotifier.value;
            // Kiểm tra xem còn đơn nào cho bàn này không
            bool stillHasOrdersForThisTable = currentPendingOrders
                .any((order) => order.tableNumber == tableNumber);

            if (!stillHasOrdersForThisTable) {
              // Nếu không còn đơn nào -> Đóng dialog
              print(
                  "Table $tableNumber list popup: No more pending orders found. Closing.");
              if (_listenerRef != null) {
                _pendingOrdersNotifier.removeListener(_listenerRef!);
              }
              // Đóng dialog một cách an toàn sau khi build frame hiện tại hoàn tất
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(dialogContext)) {
                  Navigator.of(dialogContext).pop();
                }
              });
            } else {
              // Nếu vẫn còn đơn -> Cập nhật UI của dialog (nếu cần)
              print(
                  "Table $tableNumber list popup: Orders updated, still pending orders remaining.");
              // Gọi setState của StatefulBuilder để rebuild dialog
              if (mounted &&
                  (ModalRoute.of(dialogContext)?.isCurrent ?? false)) {
                setStateInDialog(() {});
              }
            }
          };
          // --- End Listener Function ---

          // --- Add Listener after build ---
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Chỉ thêm listener nếu nó chưa được thêm (tránh thêm nhiều lần khi rebuild)
            // Remove listener cũ trước khi thêm mới để đảm bảo chỉ có 1 listener active
            if (_listenerRef != null) {
              _pendingOrdersNotifier.removeListener(
                  _listenerRef!); // Remove potential previous one
              _pendingOrdersNotifier
                  .addListener(_listenerRef!); // Add the current one
              print("Listener added for table $tableNumber dialog.");
            }
          });
          // --- End Add Listener ---

          // Lọc danh sách đơn hàng cho bàn này (luôn lấy từ notifier)
          final ordersForTable = _pendingOrdersNotifier.value
              .where((order) => order.tableNumber == tableNumber)
              .toList();
          ordersForTable.sort((a, b) => a.orderTime.compareTo(b.orderTime));

          // --- Dialog UI ---
          return WillPopScope(
            onWillPop: () async {
              print(
                  "Table $tableNumber list popup: Manually closing. Removing listener.");
              if (_listenerRef != null) {
                _pendingOrdersNotifier.removeListener(_listenerRef!);
              }
              return true; // Allow pop
            },
            child: AlertDialog(
              title: Text('Đơn hàng Bàn $tableNumber (Đang chờ)'),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(dialogContext).size.height * 0.5),
                child: ordersForTable.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(kDefaultPadding),
                          child: Text(
                            'Không còn đơn hàng nào đang chờ xử lý cho bàn này.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.7)),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: ordersForTable.length,
                        itemBuilder: (context, index) {
                          final order = ordersForTable[index];
                          final formattedTime = DateFormat('HH:mm - dd/MM/yy')
                              .format(order.orderTime);
                          final bool showInProgressIcon =
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
                                  if (showInProgressIcon)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(right: 6),
                                        child: Icon(Icons.hourglass_top_rounded,
                                            color: Colors.yellowAccent[700],
                                            size: 16)),
                                  Flexible(
                                      child: Text('Đơn #${order.orderId}')),
                                ],
                              ),
                              subtitle: Text('TG: $formattedTime'),
                              trailing: const Icon(Icons.arrow_forward_ios,
                                  size: 16, color: Colors.white70),
                              onTap: () {
                                // Gọi popup chi tiết từ context gốc (parentContext)
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
                          color: theme.colorScheme.secondary.withOpacity(0.8))),
                  onPressed: () {
                    _fetchPendingOrders(forceRefresh: true);
                  },
                ),
                TextButton(
                  onPressed: () {
                    if (_listenerRef != null) {
                      _pendingOrdersNotifier.removeListener(_listenerRef!);
                    }
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text('Đóng',
                      style: TextStyle(color: theme.colorScheme.secondary)),
                ),
              ],
              backgroundColor: theme.dialogTheme.backgroundColor,
              shape: theme.dialogTheme.shape,
            ),
          );
          // --- End Dialog UI ---
        });
      },
    ).then((_) {
      // Cleanup listener khi dialog bị đóng (ví dụ: nhấn nút back vật lý)
      if (_listenerRef != null) {
        _pendingOrdersNotifier.removeListener(_listenerRef!);
        print("Listener removed after table $tableNumber dialog closed.");
      }
    });
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
              Text("Đang tải chi tiết...", style: theme.textTheme.bodySmall)
            ],
          ));
    if (_detailErrorMessage != null)
      return Container(
          padding: const EdgeInsets.all(kDefaultPadding * 2),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orangeAccent, size: 40),
            const SizedBox(height: 10),
            Text(_detailErrorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
                onPressed: () =>
                    _fetchOrderDetail(order.orderId, setDialogState),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent[700]))
          ]));
    if (_detailItems.isEmpty)
      return Container(
          height: 100,
          padding: const EdgeInsets.all(kDefaultPadding * 2),
          alignment: Alignment.center,
          child: Text('Không có món ăn nào trong đơn hàng này.',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.white60)));
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
              final bool isThisItemUpdating =
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
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontSize: 14.5,
                                        color: isServed
                                            ? Colors.white.withOpacity(0.6)
                                            : Colors.white,
                                        decoration: isServed
                                            ? TextDecoration.lineThrough
                                            : null,
                                        decorationColor: Colors.white54,
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
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
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
                                    child: isThisItemUpdating
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
                                                  disabledBackgroundColor:
                                                      Colors.grey[600]
                                                          ?.withOpacity(0.5),
                                                  disabledForegroundColor:
                                                      Colors.grey[400],
                                                ),
                                                onPressed: isCompletingAll ||
                                                        isThisItemUpdating
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

  // Trong class _KitchenOrderListScreenState

  // ***** MODIFIED: Gọi API Complete Order khi món cuối được phục vụ *****
  Future<void> _updatePopupOrderItemStatus(
      KitchenListOrder order,
      KitchenOrderDetailItem item,
      String newStatus,
      StateSetter setDialogState,
      BuildContext dialogContext) async {
    // Ngăn chặn cập nhật trùng lặp hoặc khi widget/dialog không còn tồn tại
    if (_updatingItemIds.contains(item.orderItemId) || !mounted) return;
    bool isDialogStillMounted = true;
    try {
      (dialogContext as Element).widget;
    } catch (e) {
      isDialogStillMounted = false;
    }
    if (!isDialogStillMounted) return;

    // --- Bắt đầu trạng thái loading cho item cụ thể ---
    try {
      setDialogState(() {
        _updatingItemIds.add(item.orderItemId);
      });
    } catch (e) {
      print(
          "Error setting dialog state update start (Item ${item.orderItemId}): $e");
      _updatingItemIds.remove(item.orderItemId); // Clean up if error
      return;
    }

    print(
        "Attempting PATCH item status: Item ${item.orderItemId} -> Status '$newStatus'");
    final url = Uri.parse(
            'https://soa-deploy.up.railway.app/kitchen/order-items/${item.orderItemId}/status')
        .replace(queryParameters: {'status': newStatus});
    final headers = {'Content-Type': 'application/json'};
    bool success = false;

    try {
      // Gọi API cập nhật trạng thái món ăn
      final response = await http
          .patch(url, headers: headers)
          .timeout(const Duration(seconds: 10)); // Timeout cho từng món

      // Kiểm tra lại mount status sau await
      if (!mounted) return;
      try {
        (dialogContext as Element).widget;
      } catch (e) {
        isDialogStillMounted = false;
      }

      // Xử lý nếu dialog đóng trong khi chờ API nhưng API thành công
      if (!isDialogStillMounted &&
          response.statusCode >= 200 &&
          response.statusCode < 300) {
        print(
            "Dialog closed after successful item update, state may not reflect immediately.");
        // Có thể cần trigger refresh list chính nếu logic phức tạp hơn
        _fetchPendingOrders(
            forceRefresh: true); // Trigger refresh để đảm bảo đồng bộ
        _updatingItemIds.remove(item.orderItemId); // Clean up
        return;
      }
      // Thoát nếu dialog đóng và API thất bại
      if (!isDialogStillMounted &&
          (response.statusCode < 200 || response.statusCode >= 300)) {
        _updatingItemIds.remove(item.orderItemId); // Clean up
        return;
      }

      // --- Xử lý kết quả API ---
      if (response.statusCode == 200 || response.statusCode == 204) {
        print("API Success: Item ${item.orderItemId} updated to '$newStatus'.");
        success = true;

        // Cập nhật trạng thái item trong danh sách chi tiết của Dialog
        final index =
            _detailItems.indexWhere((i) => i.orderItemId == item.orderItemId);
        if (index != -1) {
          try {
            setDialogState(() => _detailItems[index].status = newStatus);
          } catch (e) {
            // Fallback nếu setState lỗi (ít xảy ra)
            _detailItems[index].status = newStatus;
            print(
                "Error setting dialog state after successful update (Item ${item.orderItemId}): $e");
          }

          // --- Logic Đánh dấu In Progress và Hoàn thành Đơn ---
          bool allItemsInThisOrderServed =
              _detailItems.every((i) => i.status.toLowerCase() == 'served');

          if (allItemsInThisOrderServed) {
            // -- TRƯỜNG HỢP: ĐƠN HÀNG ĐÃ HOÀN THÀNH TẤT CẢ --
            print(
                "Order ${order.orderId} fully served (last single item completed). Triggering final completion API call.");

            // ***** GỌI API HOÀN THÀNH ĐƠN HÀNG *****
            bool completeOrderSuccess =
                await _callCompleteOrderApi(order.orderId);

            // Kiểm tra lại mount status sau khi gọi API complete
            if (!mounted) return;
            try {
              (dialogContext as Element).widget;
            } catch (e) {
              isDialogStillMounted = false;
            }

            if (!completeOrderSuccess) {
              // Nếu API /complete thất bại, hiển thị lỗi và không đóng popup/xóa đơn
              print(
                  "Error: Failed to call complete order API for ${order.orderId} after last item served.");
              String errorMsg =
                  'Lỗi khi xác nhận hoàn thành đơn hàng với server.';
              if (isDialogStillMounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                  content: Text(errorMsg),
                  backgroundColor: Colors.orange,
                ));
              } else if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                  content: Text(errorMsg),
                  backgroundColor: Colors.orange,
                ));
              }
              // Không tiếp tục xử lý UI update phía dưới nếu API complete lỗi
              // Reset updating state cho item cuối cùng này
              try {
                if (isDialogStillMounted)
                  setDialogState(() {
                    _updatingItemIds.remove(item.orderItemId);
                  });
                else
                  _updatingItemIds.remove(item.orderItemId);
              } catch (e) {
                _updatingItemIds.remove(item.orderItemId);
              }
              return; // Dừng ở đây
            }
            // ***** KẾT THÚC GỌI API HOÀN THÀNH *****

            // --- Cập nhật UI ngay lập tức (chỉ khi API /complete thành công) ---
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
            if (isDialogStillMounted && Navigator.canPop(dialogContext)) {
              Navigator.of(dialogContext).pop();
            }
            if (mounted) {
              _fetchCompletedOrders();
            } // Fetch nền
          } else {
            // -- TRƯỜNG HỢP: ĐƠN HÀNG CHƯA HOÀN THÀNH TẤT CẢ --
            // Đánh dấu đơn hàng là đang xử lý nếu chưa được đánh dấu
            if (!_inProgressOrderIds.contains(order.orderId)) {
              if (mounted) {
                setState(() {
                  print("Marking order ${order.orderId} as in progress.");
                  _inProgressOrderIds.add(order.orderId);
                });
              }
            }
            // ***** THÊM SNACKBAR CHO MÓN ĂN ĐƠN LẺ *****
            if (mounted && newStatus.toLowerCase() == 'served') {
              ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                content:
                    Text('Đã hoàn thành: ${item.name} (Đơn #${order.orderId})'),
                backgroundColor: Colors.lightGreen.shade800,
                duration: const Duration(seconds: 2),
              ));
            }
          }
          // --- Kết thúc Logic Đánh dấu ---
        } else {
          // Item không tìm thấy trong list local -> Tải lại chi tiết
          if (isDialogStillMounted) {
            _fetchOrderDetail(order.orderId, setDialogState);
          }
        }
      } else {
        // --- Xử lý lỗi API (statusCode != 200/204) ---
        print(
            "API Error updating item ${item.orderItemId}: ${response.statusCode}, Body: ${utf8.decode(response.bodyBytes)}");
        success = false;
        String errorMsg = 'Lỗi cập nhật món (${response.statusCode})';
        try {
          final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorBody is Map && errorBody.containsKey('detail')) {
            errorMsg += ': ${errorBody['detail']}';
          }
        } catch (_) {}
        // Hiển thị lỗi
        if (isDialogStillMounted) {
          ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
              content: Text(errorMsg), backgroundColor: Colors.redAccent));
        } else if (mounted) {
          ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
              content: Text(errorMsg), backgroundColor: Colors.redAccent));
        }
      }
    } catch (e) {
      // --- Xử lý lỗi mạng/timeout/parsing ---
      if (!mounted) return; // Kiểm tra mount sau catch
      try {
        (dialogContext as Element).widget;
      } catch (e) {
        isDialogStillMounted = false;
      }
      if (!isDialogStillMounted) {
        _updatingItemIds.remove(item.orderItemId);
        return;
      } // Thoát nếu dialog đóng

      print(
          "Network/Timeout/Other Error updating item ${item.orderItemId}: $e");
      success = false;
      String errorMsg = 'Lỗi mạng hoặc timeout khi cập nhật món ăn.';
      if (e is TimeoutException) {
        errorMsg = 'Yêu cầu cập nhật món ăn quá thời gian. Vui lòng thử lại.';
      }
      // Hiển thị lỗi
      if (isDialogStillMounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
            content: Text(errorMsg), backgroundColor: Colors.orangeAccent));
      } else if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
            content: Text(errorMsg), backgroundColor: Colors.orangeAccent));
      }
    } finally {
      // --- Kết thúc trạng thái loading cho item này ---
      if (mounted) {
        try {
          (dialogContext as Element).widget;
        } catch (e) {
          isDialogStillMounted = false;
        }
        if (isDialogStillMounted) {
          try {
            setDialogState(() {
              _updatingItemIds.remove(item.orderItemId);
            });
          } catch (e) {
            _updatingItemIds.remove(item.orderItemId);
          } // Fallback
        } else {
          _updatingItemIds.remove(item.orderItemId);
        }
      } else {
        _updatingItemIds.remove(item.orderItemId);
      }
      print(
          "Finished update attempt for item ${item.orderItemId}. Success: $success");
    }
  }

// ***** THÊM HÀM HELPER MỚI ĐỂ GỌI API COMPLETE ORDER *****
  Future<bool> _callCompleteOrderApi(int orderId) async {
    final url = Uri.parse(
        'https://soa-deploy.up.railway.app/kitchen/order/complete/$orderId');
    final headers = {'Content-Type': 'application/json'};
    print("Calling API (Helper): PATCH ${url.toString()}");
    try {
      final response = await http
          .patch(url, headers: headers)
          .timeout(const Duration(seconds: 10)); // Timeout riêng cho complete

      if (response.statusCode == 200 || response.statusCode == 204) {
        print("API Success (Helper): Order $orderId marked complete.");
        return true; // Success
      } else {
        print(
            "API Error (Helper): Order $orderId failed complete (${response.statusCode}), Body: ${response.body}");
        return false; // Failure
      }
    } catch (e) {
      print("Network/Timeout Error (Helper) for complete order $orderId: $e");
      return false; // Failure on exception
    }
  }

// ***** MODIFIED: Sử dụng API mới, cập nhật UI tức thì + thêm vào Completed + SnackBar *****
  Future<void> _completeAllItemsForOrder(KitchenListOrder order,
      StateSetter setDialogState, BuildContext dialogContext) async {
    if (_isCompletingAll) return; // Prevent double taps
    if (!mounted) return;

    bool isDialogStillMounted = true;
    try {
      (dialogContext as Element).widget;
    } catch (e) {
      isDialogStillMounted = false;
    }
    if (!isDialogStillMounted) return;

    print("Calling API to complete order ${order.orderId} directly.");

    // --- Bắt đầu trạng thái loading ---
    try {
      setDialogState(() {
        _isCompletingAll = true;
      });
    } catch (e) {
      print("Error setting dialog state for 'Complete Order' start: $e");
      _isCompletingAll = false;
      return;
    }

    // --- Gọi API mới ---
    final url = Uri.parse(
        'https://soa-deploy.up.railway.app/kitchen/order/complete/${order.orderId}');
    final headers = {'Content-Type': 'application/json'};
    bool success = false;

    try {
      final response = await http.patch(url, headers: headers).timeout(
          const Duration(seconds: 15)); // Timeout for complete order API

      if (!mounted) return; // Check mount after await
      try {
        (dialogContext as Element).widget;
      } catch (e) {
        isDialogStillMounted = false;
      }

      if (response.statusCode == 200 || response.statusCode == 204) {
        print(
            "API Success: Order ${order.orderId} marked as complete by server.");
        success = true;

        // --- CẬP NHẬT UI NGAY LẬP TỨC & ĐÓNG POPUP ---
        if (mounted) {
          setState(() {
            // Xóa khỏi pending
            _pendingOrders = _pendingOrders
                .where((o) => o.orderId != order.orderId)
                .toList(); // Update notifier via setter
            // Xóa khỏi danh sách đang xử lý
            _inProgressOrderIds.remove(order.orderId);

            // THÊM VÀO COMPLETED (Client-side)
            if (!_completedOrders.any((co) => co.orderId == order.orderId)) {
              _completedOrders.insert(0, order);
              print(
                  "Added order ${order.orderId} to local completed list (API complete).");
            }

            print(
                "Removed order ${order.orderId} from main pending list (API complete).");
            _notifyTableStatusUpdate(
                order.tableNumber); // Thông báo cho MenuScreen
          });

          // THÊM SNACKBAR THÔNG BÁO HOÀN THÀNH ĐƠN
          ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
            content: Text('Đơn hàng #${order.orderId} đã hoàn thành!'),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 3),
          ));
        }
        if (isDialogStillMounted && Navigator.canPop(dialogContext)) {
          Navigator.of(dialogContext).pop(); // Đóng popup chi tiết
        }
        // --- KẾT THÚC CẬP NHẬT UI ---

        // Fetch completed in background without await/loading for consistency
        if (mounted) {
          _fetchCompletedOrders(); // Không cần await
        }
      } else {
        // Xử lý lỗi API
        print(
            "API Error completing order ${order.orderId}: ${response.statusCode}, Body: ${response.body}");
        success = false;
        String errorMsg = 'Lỗi hoàn thành đơn (${response.statusCode})';
        try {
          final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorBody is Map && errorBody.containsKey('detail')) {
            errorMsg += ': ${errorBody['detail']}';
          }
        } catch (_) {}
        // Hiển thị lỗi
        if (isDialogStillMounted) {
          ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
              content: Text(errorMsg), backgroundColor: Colors.redAccent));
          // Tải lại chi tiết để user thấy trạng thái hiện tại
          _fetchOrderDetail(order.orderId, setDialogState);
        } else if (mounted) {
          ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
              content: Text(errorMsg), backgroundColor: Colors.redAccent));
        }
      }
    } catch (e) {
      // Xử lý lỗi mạng/timeout
      print("Network/Timeout Error completing order ${order.orderId}: $e");
      success = false;
      String errorMsg = 'Lỗi mạng hoặc timeout khi hoàn thành đơn.';
      if (e is TimeoutException) {
        errorMsg = 'Yêu cầu hoàn thành đơn quá thời gian. Vui lòng thử lại.';
      }

      if (isDialogStillMounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.orangeAccent,
        ));
        _fetchOrderDetail(
            order.orderId, setDialogState); // Tải lại chi tiết khi có lỗi
      } else if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.orangeAccent,
        ));
      }
    } finally {
      // --- Kết thúc trạng thái loading ---
      if (mounted) {
        try {
          (dialogContext as Element).widget;
        } catch (e) {
          isDialogStillMounted = false;
        }
        if (isDialogStillMounted) {
          try {
            setDialogState(() {
              _isCompletingAll = false;
              _updatingItemIds.clear(); /* Xóa cả item ids nếu có */
            });
          } catch (e) {
            _isCompletingAll = false;
            _updatingItemIds.clear();
          }
        } else {
          _isCompletingAll = false;
          _updatingItemIds.clear();
        }
      } else {
        _isCompletingAll = false;
        _updatingItemIds.clear();
      }
      print(
          "'Complete Order' process finished for order ${order.orderId}. Success: $success");
    }
  }

  void _notifyTableStatusUpdate(int? tableNumber) {
    if (!mounted) return;
    if (tableNumber == null || tableNumber <= 0) {
      print(
          "Warning: Cannot notify table status, invalid table number: $tableNumber");
      _fetchPendingOrders(forceRefresh: true);
      return;
    }
    print("Checking if table $tableNumber is now clear...");
    bool otherPendingForTable = _pendingOrders
        .any((pendingOrder) => pendingOrder.tableNumber == tableNumber);
    if (!otherPendingForTable) {
      print("Table $tableNumber is now clear. Calling onTableCleared.");
      try {
        widget.onTableCleared?.call(tableNumber);
      } catch (e) {
        print("Error calling onTableCleared: $e");
      }
    } else {
      print(
          "Table $tableNumber still has other pending orders. Recalculating counts.");
      Map<int, int> currentCounts = {};
      for (var o in _pendingOrders) {
        if (o.tableNumber != null && o.tableNumber! > 0) {
          currentCounts[o.tableNumber!] =
              (currentCounts[o.tableNumber!] ?? 0) + 1;
        }
      }
      try {
        widget.onOrderUpdate?.call(currentCounts);
      } catch (e) {
        print("Error calling onOrderUpdate after partial table clear: $e");
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildViewSwitcher(theme),
        Expanded(child: _buildBodyContent(theme)),
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
                  _isConnecting
                      ? 'Đang kết nối lại...'
                      : 'Mất kết nối thời gian thực. Đang thử lại...',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white, fontSize: 10.5),
                ),
              ],
            ),
          )
      ],
    );
  }

  Widget _buildViewSwitcher(ThemeData theme) {
    final Color pendingSelCol = Colors.yellowAccent[700]!;
    final Color completedSelCol = Colors.greenAccent;
    final Color unselectedCol = Colors.white70;
    return Padding(
        padding: const EdgeInsets.symmetric(
            vertical: kDefaultPadding, horizontal: kDefaultPadding * 1.5),
        child: SegmentedButton<OrderListView>(
          segments: <ButtonSegment<OrderListView>>[
            ButtonSegment<OrderListView>(
                value: OrderListView.pending,
                label: Text('Đang xử lý',
                    style: TextStyle(
                        color: _currentView == OrderListView.pending
                            ? pendingSelCol
                            : unselectedCol)),
                icon: Icon(Icons.sync,
                    size: 18,
                    color: _currentView == OrderListView.pending
                        ? pendingSelCol
                        : unselectedCol)),
            ButtonSegment<OrderListView>(
                value: OrderListView.completed,
                label: Text('Đã hoàn thành',
                    style: TextStyle(
                        color: _currentView == OrderListView.completed
                            ? completedSelCol
                            : unselectedCol)),
                icon: Icon(Icons.check_circle_outline_rounded,
                    size: 18,
                    color: _currentView == OrderListView.completed
                        ? completedSelCol
                        : unselectedCol)),
          ],
          selected: <OrderListView>{_currentView},
          onSelectionChanged: (Set<OrderListView> newSelection) {
            if (newSelection.isNotEmpty && newSelection.first != _currentView) {
              setState(() {
                _currentView = newSelection.first;
              });
              if (_currentView == OrderListView.completed &&
                  !_completedOrdersLoaded &&
                  !_isLoadingCompleted) {
                _fetchCompletedOrders();
              }
            }
          },
          style: theme.segmentedButtonTheme.style,
        ));
  }

  Widget _buildBodyContent(ThemeData theme) {
    Widget content;
    Future<void> Function() onRefresh;
    if (_currentView == OrderListView.pending) {
      onRefresh = () => _fetchPendingOrders(forceRefresh: true);
      if (_isLoadingPending && _pendingOrders.isEmpty) {
        content = _buildShimmerLoadingList(theme);
      } else if (_pendingErrorMessage != null && _pendingOrders.isEmpty) {
        content = _buildErrorWidget(_pendingErrorMessage!, onRefresh);
      } else if (_pendingOrders.isEmpty && !_isLoadingPending) {
        content = _buildEmptyListWidget('Không có đơn hàng nào đang xử lý.',
            Icons.no_food_outlined, onRefresh);
      } else {
        content = _buildOrderListView(_pendingOrders);
      }
    } else {
      onRefresh = () => _fetchCompletedOrders(forceRefresh: true);
      if (_isLoadingCompleted && _completedOrders.isEmpty) {
        content = _buildShimmerLoadingList(theme);
      } else if (_completedErrorMessage != null && _completedOrders.isEmpty) {
        content = _buildErrorWidget(_completedErrorMessage!, onRefresh);
      } else if (_completedOrders.isEmpty && !_isLoadingCompleted) {
        content = _buildEmptyListWidget('Chưa có đơn hàng nào hoàn thành.',
            Icons.history_toggle_off_outlined, onRefresh);
      } else {
        content = _buildOrderListView(_completedOrders);
      }
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: theme.colorScheme.secondary,
      backgroundColor: theme.scaffoldBackgroundColor,
      child: content,
    );
  }

  Widget _buildShimmerLoadingList(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.cardTheme.color!.withOpacity(0.5),
      highlightColor: theme.cardTheme.color!.withOpacity(0.8),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(kDefaultPadding, kDefaultPadding,
            kDefaultPadding, kDefaultPadding + kBottomActionBarHeight),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8))),
            title: Container(
                width: double.infinity,
                height: 16.0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8)),
            subtitle: Container(width: 120, height: 12.0, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderListView(List<KitchenListOrder> orders) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(kDefaultPadding, kDefaultPadding,
            kDefaultPadding, kDefaultPadding + kBottomActionBarHeight),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final formattedTime =
              DateFormat('HH:mm - dd/MM/yy').format(order.orderTime);
          final bool isServed = _currentView == OrderListView.completed;
          final bool showInProgressIcon =
              !isServed && _inProgressOrderIds.contains(order.orderId);
          final defaultTitleStyle = theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: isServed ? Colors.grey[400] : Colors.white,
            fontSize: 14.5,
          );
          final tableNumberStyle = defaultTitleStyle?.copyWith(
              fontWeight: FontWeight.bold,
              color: isServed ? Colors.grey[350] : Colors.white);
          final tableErrorStyle = defaultTitleStyle?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.error,
            fontStyle: FontStyle.italic,
          );
          int? currentTableNumber = order.tableNumber;
          InlineSpan tableNumberSpan;
          if (currentTableNumber != null) {
            if (currentTableNumber == -1) {
              tableNumberSpan = TextSpan(text: 'Lỗi', style: tableErrorStyle);
            } else {
              tableNumberSpan = TextSpan(
                  text: currentTableNumber.toString(), style: tableNumberStyle);
            }
          } else {
            tableNumberSpan = WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Tooltip(
                message: 'Đang tải số bàn...',
                child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: Colors.grey[500])),
              ),
            );
          }
          return Card(
            margin: const EdgeInsets.only(bottom: kDefaultPadding * 1.5),
            elevation: isServed ? 1.5 : 3.5,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: isServed
                ? theme.cardTheme.color?.withAlpha(180)
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
                  style: defaultTitleStyle,
                  children: [
                    TextSpan(
                        text: 'Bàn ',
                        style: TextStyle(
                            color:
                                isServed ? Colors.grey[400] : Colors.white70)),
                    tableNumberSpan,
                    TextSpan(text: ' - Đơn #${order.orderId}'),
                    if (showInProgressIcon)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(
                              left: kDefaultPadding * 0.75),
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
                  child: Text('Thời gian: $formattedTime',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              isServed ? Colors.grey[500] : Colors.grey[350]))),
              trailing: isServed
                  ? Icon(Icons.visibility_outlined,
                      color: Colors.grey[500], size: 22)
                  : Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () => _showOrderDetailPopup(context, order),
              tileColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      );
    });
  }

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
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 50),
                          const SizedBox(height: 16),
                          Text(message,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white70)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                              onPressed: onRetry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Thử lại'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent[100]))
                        ]))))
      ],
    );
  }

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
                          Icon(icon, size: 60, color: Colors.grey[600]),
                          const SizedBox(height: 16),
                          Text(message,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: Colors.grey[400])),
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
