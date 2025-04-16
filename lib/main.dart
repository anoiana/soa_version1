// ****** CODE HOÀN CHỈNH - ĐẦY ĐỦ FILE - KHÔNG CÒN PLACEHOLDER ******
import 'package:flutter/material.dart';
import 'screens/signInScreen.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart'; // For groupBy and MapEquality
import 'package:intl/intl.dart'; // For date formatting
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:midterm/screens/signInScreen.dart';
import 'package:shimmer/shimmer.dart'; // Import Shimmer
import 'package:web_socket_channel/web_socket_channel.dart'; // Import WebSocket
import 'package:web_socket_channel/status.dart'
    as status;
// Comment out or remove if you don't have this file and the ManagementScreen class
// import 'management_screen.dart';

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
const double kExclamationMarkSize = 35.0;
const double kLogoHeight = 100.0;
const double kBottomActionBarHeight = 60.0;

// --- Data Models ---
class MenuItem {
  final int itemId;
  final String name;
  final String category;
  final bool available;
  final String? img;
  const MenuItem({
    required this.itemId,
    required this.name,
    required this.category,
    required this.available,
    this.img,
  });
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    bool isAvailable = false;
    final availableValue = json['available'];
    if (availableValue != null) {
      if (availableValue is bool) {
        isAvailable = availableValue;
      } else if (availableValue is int) {
        isAvailable = availableValue == 1;
      } else if (availableValue is String) {
        String v = availableValue.toLowerCase();
        isAvailable = v == '1' || v == 'true';
      } else {
        print(
            "Warning: Unexpected type for 'available' field: ${availableValue.runtimeType} for item_id: ${json['item_id']}");
      }
    }
    return MenuItem(
      itemId: json['item_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown Item',
      category: json['category'] as String? ?? 'Uncategorized',
      available: isAvailable,
      img: json['img'] as String?,
    );
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
}

class KitchenListOrder {
  final int orderId;
  final int sessionId;
  final DateTime orderTime;
  int? tableNumber;
  KitchenListOrder({
    required this.orderId,
    required this.sessionId,
    required this.orderTime,
    this.tableNumber,
  });
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
  KitchenOrderDetailItem({
    required this.orderItemId,
    required this.orderId,
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.status,
  });
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

// --- Main App Setup ---
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // --- Theme Data ---
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
          foregroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
            if (states.contains(MaterialState.selected)) return Colors.white;
            return Colors.white70;
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
      home: LoginScreen(),
    );
  }
}

// --- Menu Screen ---
class MenuScreen extends StatefulWidget {
  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  // --- State variables ---
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

  // --- initState & dispose ---
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
            });
    _tableScrollController.addListener(_onTableScroll);
    _fetchMenuData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _onTableScroll();
        _updateExclamationMark();
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

  // --- Data Fetching & Logic Methods ---
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
        final groupedItems =
            groupBy(allItems, (MenuItem item) => item.category);
        final uniqueCategories = groupedItems.keys.toList()..sort();
        final newCategoryKeys =
            List.generate(uniqueCategories.length, (_) => GlobalKey());
        final Map<int, MenuItem> itemsById = {
          for (var item in allItems) item.itemId: item
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
            }
            if (_menuItemsById.containsKey(item.itemId)) {
              _menuItemsById[item.itemId] = updatedItem;
            }
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Đã cập nhật: ${item.name} (${newStatus ? "Có sẵn" : "Hết hàng"})'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green[700],
          ));
        }
        return true;
      } else {
        print(
            'API update failed for item ${item.itemId}. Status: ${response.statusCode}, Body: ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Lỗi cập nhật trạng thái món ăn. Server: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
          ));
        }
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      print('Error calling update API for item ${item.itemId}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Lỗi mạng hoặc timeout khi cập nhật.'),
          backgroundColor: Colors.orangeAccent,
        ));
      }
      return false;
    }
  }

  void _updateExclamationMark() {
    if (!_tableScrollController.hasClients || !mounted) {
      if (_showExclamationMark) setState(() => _showExclamationMark = false);
      return;
    }
    final bool needsMark = tables.any((table) => !(table['isVisible'] as bool));
    if (needsMark != _showExclamationMark) {
      setState(() {
        _showExclamationMark = needsMark;
        if (needsMark) {
          _exclamationMarkAngle =
              (_exclamationMarkAngle + math.pi / 16) % (2 * math.pi);
        }
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
      if ((tables[i]['isVisible'] as bool) != currentlyVisible) {
        tables[i]['isVisible'] = currentlyVisible;
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
      setState(() {
        selectedIndex = categoryIndex;
        _isMenuCategoriesExpanded = true;
      });
    }
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _performScroll(arrayIndex);
      }
    });
  }

  void _performScroll(int arrayIndex) {
    if (!mounted || arrayIndex < 0 || arrayIndex >= _categoryKeys.length)
      return;
    final key = _categoryKeys[arrayIndex];
    final context = key.currentContext;
    if (context != null) {
      if (selectedIndex == arrayIndex + 1) {
        if (_menuScrollController.hasClients &&
            _menuScrollController.position.hasContentDimensions) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.0,
          );
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _menuScrollController.hasClients)
              Scrollable.ensureVisible(context,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease);
          });
        }
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

  void _updateTableOrderCounts(Map<int, int> newCounts) {
    if (!mounted) return;
    bool changed = false;
    for (int i = 0; i < tables.length; i++) {
      int tableNum = i + 1;
      int newCount = newCounts[tableNum] ?? 0;
      if (tables[i]['pendingOrderCount'] != newCount) {
        tables[i]['pendingOrderCount'] = newCount;
        changed = true;
      }
    }
    _pendingOrderCountsByTable = Map.from(newCounts);
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
      if (tables[tableIndex]['pendingOrderCount'] > 0) {
        setState(() {
          tables[tableIndex]['pendingOrderCount'] = 0;
          _pendingOrderCountsByTable[tableNumber] = 0;
        });
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
            "Table $tableNumber already had 0 pending orders in MenuScreen state.");
      }
    } else {
      print(
          "Warning: Received cleared signal for invalid table number: $tableNumber");
    }
  }

  // --- Helper Methods ---
  int _getNavigationRailSelectedIndex() {
    if (selectedIndex == 0) return 0;
    if (selectedIndex == orderScreenIndex) return 1;
    if ((selectedIndex >= 1 && selectedIndex <= _categories.length) ||
        _isMenuCategoriesExpanded) return 2;
    print(
        "Warning: _getNavigationRailSelectedIndex reached unexpected state. Defaulting to 0.");
    return 0;
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width > 1200
        ? kTableGridCrossAxisCountLarge
        : kTableGridCrossAxisCountSmall;
  }

  bool _isSmallScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width <= 800;
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
            if (selectedIndex == 0) _buildExclamationOverlay(smallScreen),
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
            decoration: BoxDecoration(color: theme.cardTheme.color),
            child: Center(child: _buildLogo()),
          ),
          _buildDrawerItem(theme, Icons.table_restaurant, 'Danh sách bàn ăn', 0,
              selectedIndex, highlight, () {
            setState(() {
              selectedIndex = 0;
              _isMenuCategoriesExpanded = false;
            });
          }),
          divider,
          _buildDrawerItem(theme, Icons.receipt_long, 'Danh sách đơn hàng',
              orderScreenIndex, selectedIndex, highlight, () {
            setState(() {
              selectedIndex = orderScreenIndex;
              _isMenuCategoriesExpanded = false;
            });
          }),
          divider,
          ExpansionTile(
            leading: Icon(Icons.restaurant_menu,
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
                            : _buildCategoryButtonGrid(
                                theme, true), // isDrawer = true
              ),
            ],
          ),
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
      onTap: () {
        onTapAction();
        Navigator.pop(context);
      },
      selected: isSelected,
      selectedTileColor: theme.colorScheme.secondary.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: kDefaultPadding * 2.5),
    );
  }

  Widget _buildNavigationRail(ThemeData theme) {
    final Color selectedColor = theme.colorScheme.secondary;
    final Color unselectedColor = Colors.white;
    final railLabelStyle =
        theme.textTheme.titleMedium?.copyWith(fontSize: 15.5);
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
      final bool isSelected = currentRailIndex == data['index'] as int;
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
                Text(
                  data['label'] as String,
                  style: isSelected
                      ? railLabelStyle?.copyWith(
                          color: selectedColor, fontWeight: FontWeight.w600)
                      : railLabelStyle?.copyWith(
                          color: unselectedColor.withOpacity(0.7),
                          fontWeight: FontWeight.w500),
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
        children: [
          const SizedBox(height: kDefaultPadding * 2.5),
          _buildLogo(),
          const SizedBox(height: kDefaultPadding * 3.5),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: destinationsWidgets,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: _isMenuCategoriesExpanded &&
                    !_isLoadingMenu &&
                    _menuErrorMessage == null &&
                    _categories.isNotEmpty
                ? Expanded(
                    child: Container(
                    margin: const EdgeInsets.only(top: kDefaultPadding),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(kDefaultPadding, 0,
                          kDefaultPadding, kDefaultPadding * 2),
                      child: SingleChildScrollView(
                        child: _buildCategoryButtonGrid(theme, false),
                      ),
                    ),
                  ))
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
          }
          if (_categories.isEmpty) {
            _isMenuCategoriesExpanded = false;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Chưa có danh mục món ăn nào.'),
              duration: Duration(seconds: 2),
            ));
          }
        }
      }
    });
  }

  Widget _buildLogo({double height = kLogoHeight, double? width}) {
    const String logoAssetPath =
        'assets/spidermen.jpg'; // !! THAY BẰNG LOGO CỦA BẠN !!
    return ClipRRect(
      borderRadius: BorderRadius.circular(kDefaultPadding),
      child: Image.asset(
        logoAssetPath,
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
            height: height,
            width: width ?? height * 1.8,
            color: Colors.grey[700],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image,
                    color: Colors.red[300], size: height * 0.5),
                const SizedBox(height: 4),
                Text("Logo Error",
                    style: TextStyle(color: Colors.red[300], fontSize: 10))
              ],
            )),
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
                            Icon(
                              Icons.table_restaurant_rounded,
                              size: 55,
                              color: iconColor,
                            ),
                            const SizedBox(height: kDefaultPadding * 1.5),
                            Text(
                              table['name'],
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
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                            child: Center(
                              child: Text(
                                '$pendingCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
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
                padding:
                    const EdgeInsets.symmetric(horizontal: kDefaultPadding),
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
                    print("Attempting to load asset: $assetPath");
                    imageWidget = Image.asset(assetPath,
                        width: kMenuItemImageSize,
                        height: kMenuItemImageSize,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) {
                          print("Error loading asset '$assetPath': $e");
                          return _buildPlaceholderImage(hasError: true);
                        },
                        frameBuilder: (c, child, frame, wasSyncLoaded) =>
                            wasSyncLoaded
                                ? child
                                : AnimatedOpacity(
                                    child: child,
                                    opacity: frame == null ? 0 : 1,
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOut,
                                  ));
                  } else {
                    print("No image path for item: ${item.name}");
                    imageWidget = _buildPlaceholderImage();
                  }
                  return Card(
                    margin:
                        const EdgeInsets.only(bottom: kDefaultPadding * 1.5),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12)),
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
                                Text(item.name,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontSize: 16.5)),
                                const SizedBox(height: kDefaultPadding * 0.6),
                                Text("ID: ${item.itemId}",
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              right: kDefaultPadding * 1.5),
                          child: AvailabilitySwitch(
                            item: item,
                            onStatusChanged: _updateItemStatus,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
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
            color: theme.dividerTheme.color ?? Colors.white24,
            width: 0.5,
          ),
        ),
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
    const String exclamationAssetPath =
        'assets/exclamation_mark.png'; // !! THAY BẰNG ASSET CỦA BẠN !!
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
          final unselectedBgColor = theme.cardTheme.color?.withOpacity(0.8) ??
              const Color(0xFF455A64);
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
                child: Text(categoryName,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
              ),
            ),
          );
        });
  }

  Widget _buildCurrentView(ThemeData theme) {
    int stackIndex = 0;
    if (selectedIndex == orderScreenIndex) {
      stackIndex = 1;
    } else if (selectedIndex >= 1 && selectedIndex <= _categories.length) {
      stackIndex = 2;
    }
    List<Widget> pages = [
      _buildTableGrid(theme), // Page 0
      KitchenOrderListScreen(
        key: _kitchenListKey,
        onOrderUpdate: _updateTableOrderCounts,
        onTableCleared: _handleTableCleared,
      ), // Page 1
      Builder(builder: (context) {
        // Page 2
        bool isMenuView =
            selectedIndex >= 1 && selectedIndex <= _categories.length;
        if (isMenuView) {
          if (_isLoadingMenu) {
            return Center(
                child: CircularProgressIndicator(
                    color: theme.colorScheme.secondary));
          }
          if (_menuErrorMessage != null) {
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off,
                              color: Colors.redAccent, size: 50),
                          const SizedBox(height: kDefaultPadding * 2),
                          Text(_menuErrorMessage!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white70)),
                          const SizedBox(height: kDefaultPadding * 2),
                          ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent),
                              onPressed: _fetchMenuData,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Thử lại'))
                        ])));
          }
          if (_categories.isEmpty && !_isLoadingMenu) {
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
                                  backgroundColor: theme.colorScheme.secondary),
                              onPressed: _fetchMenuData,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tải lại Menu'))
                        ])));
          }
          if (stackIndex == 2) {
            return _buildSelectedMenuCategoryList(theme);
          }
        }
        // Fallback return để đảm bảo Builder luôn trả về Widget
        print(
            "Warning: _buildCurrentView's Builder reached end without returning widget. Returning empty Container.");
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
  const AvailabilitySwitch(
      {Key? key, required this.item, required this.onStatusChanged})
      : super(key: key);
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
    if (widget.item.available != oldWidget.item.available &&
        widget.item.available != _optimisticValue &&
        !_isUpdating) {
      if (mounted) setState(() => _optimisticValue = widget.item.available);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final switchTheme = theme.switchTheme;
    bool displayValue = _optimisticValue;
    Color statusColor = _isUpdating
        ? Colors.grey[500]!
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
                          if (!success) _optimisticValue = !newValue;
                          _isUpdating = false;
                        });
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
              fontSize: 10.5, color: statusColor, fontWeight: FontWeight.w500),
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
  // --- State Variables ---
  List<KitchenListOrder> _pendingOrders = [];
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
  // --- WebSocket Variables ---
  final String _webSocketUrl =
      'wss://web-socket-soa-midterm.onrender.com/ws/kitchen';
  WebSocketChannel? _channel;
  bool _isWebSocketConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 10;
  // --- Lifecycle Methods ---
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _fetchPendingOrders();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _disconnectWebSocket();
    super.dispose();
  }

  // --- WebSocket Connection Management ---
  void _connectWebSocket() {
    if (_isWebSocketConnected || _reconnectAttempts >= _maxReconnectAttempts) {
      print('WebSocket: Already connected or max reconnect attempts reached.');
      return;
    }
    print(
        'WebSocket: Attempting to connect to $_webSocketUrl (Attempt #${_reconnectAttempts + 1})...');
    _reconnectAttempts++;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_webSocketUrl));
      _isWebSocketConnected = true;
      print('WebSocket: Connection established.');
      _reconnectAttempts = 0;
      _channel?.stream.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketDone,
        cancelOnError: true,
      );
    } catch (e) {
      print('WebSocket: Connection error during connect(): $e');
      _isWebSocketConnected = false;
      _scheduleReconnect();
    }
  }

  void _disconnectWebSocket() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = _maxReconnectAttempts;
    if (_channel != null) {
      print('WebSocket: Closing connection.');
      _channel?.sink.close(status.goingAway);
      _channel = null;
    }
    _isWebSocketConnected = false;
    print('WebSocket: Connection closed and resources released.');
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('WebSocket: Max reconnect attempts reached. Stopping.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Mất kết nối real-time tới bếp. Vui lòng kiểm tra mạng và thử làm mới thủ công.'),
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 5),
        ));
      }
      return;
    }
    _isWebSocketConnected = false;
    _reconnectTimer?.cancel();
    final reconnectDelay =
        Duration(seconds: math.min(30, 2 + _reconnectAttempts * 2));
    print(
        'WebSocket: Scheduling reconnect attempt #${_reconnectAttempts + 1} in ${reconnectDelay.inSeconds} seconds...');
    _reconnectTimer = Timer(reconnectDelay, _connectWebSocket);
  }

  // --- WebSocket Event Handlers ---
  void _handleWebSocketMessage(dynamic message) {
    print('WebSocket: Received message: $message');
    try {
      final data = jsonDecode(message);
      print('WebSocket: Decoded data: $data');
      print(
          'WebSocket: Triggering pending order list refresh due to received message.');
      if (mounted) {
        _fetchPendingOrders(forceRefresh: true);
      }
    } catch (e) {
      print('WebSocket: Error decoding message or processing: $e');
      print('WebSocket: Triggering refresh despite processing error.');
      if (mounted) {
        _fetchPendingOrders(forceRefresh: true);
      }
    }
  }

  void _handleWebSocketError(error) {
    print('WebSocket: Stream Error: $error');
    _isWebSocketConnected = false;
    _scheduleReconnect();
  }

  void _handleWebSocketDone() {
    print('WebSocket: Connection closed (onDone).');
    _isWebSocketConnected = false;
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
    }
  }

  // --- Data Fetching Methods ---
  Future<void> _fetchPendingOrders({bool forceRefresh = false}) async {
    if (!mounted) return;
    print("Fetching pending orders... (Force refresh: $forceRefresh)");
    if (forceRefresh) {
      _tableNumberCache.clear();
      _fetchingTableSessionIds.clear();
    }
    setState(() {
      _isLoadingPending = true;
      _pendingErrorMessage = null;
      if (forceRefresh) _inProgressOrderIds.clear();
    });
    List<KitchenListOrder> fetchedOrders = [];
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
        ...inProgressOrders
      ];
      final uniquePendingOrdersMap = <int, KitchenListOrder>{
        for (var order in combinedPendingOrders) order.orderId: order
      };
      fetchedOrders = uniquePendingOrdersMap.values.toList()
        ..sort((a, b) => a.orderTime.compareTo(b.orderTime));
      await _fetchTableNumbersForOrders(fetchedOrders);
      _inProgressOrderIds.clear();
      for (var order in fetchedOrders) {
        if (inProgressOrders
            .any((ipOrder) => ipOrder.orderId == order.orderId)) {
          _inProgressOrderIds.add(order.orderId);
        }
      }
      countsByTable.clear();
      for (var order in fetchedOrders) {
        if (order.tableNumber != null && order.tableNumber! > 0) {
          countsByTable[order.tableNumber!] =
              (countsByTable[order.tableNumber!] ?? 0) + 1;
        }
      }
      try {
        if (mounted) {
          Map<int, int> currentCounts = {};
          _pendingOrders.forEach((order) {
            if (order.tableNumber != null && order.tableNumber! > 0) {
              currentCounts[order.tableNumber!] =
                  (currentCounts[order.tableNumber!] ?? 0) + 1;
            }
          });
          if (!const MapEquality().equals(countsByTable, currentCounts)) {
            print(
                "[Callback] Order counts changed, calling onOrderUpdate: $countsByTable");
            widget.onOrderUpdate?.call(countsByTable);
          } else {
            print("[Callback] Order counts unchanged, skipping onOrderUpdate.");
          }
        }
      } catch (e) {
        print("Error calling onOrderUpdate callback: $e");
      }
    } catch (e) {
      errorMsg = "Lỗi tải đơn hàng: ${e.toString()}";
      print("Error fetching PENDING orders: $e");
      if (mounted) {
        try {
          widget.onOrderUpdate?.call({});
        } catch (e) {
          print("Error calling onOrderUpdate during error handling: $e");
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _pendingOrders = fetchedOrders;
          _pendingErrorMessage = errorMsg;
          _isLoadingPending = false;
          print(
              "Finished _fetchPendingOrders. isLoadingPending: $_isLoadingPending");
        });
      }
    }
  }

  Future<void> _fetchCompletedOrders({bool forceRefresh = false}) async {
    if (!mounted) return;
    print("Fetching completed orders... (Force refresh: $forceRefresh)");
    if (forceRefresh) {
      _tableNumberCache.clear();
      _fetchingTableSessionIds.clear();
    }
    setState(() {
      _isLoadingCompleted = true;
      _completedErrorMessage = null;
    });
    List<KitchenListOrder> fetchedOrders = [];
    String? errorMsg;
    try {
      fetchedOrders = await _fetchOrdersWithStatus('served');
      await _fetchTableNumbersForOrders(fetchedOrders);
      fetchedOrders.sort((a, b) => b.orderTime.compareTo(a.orderTime));
      _completedOrdersLoaded = true;
    } catch (e) {
      errorMsg = "Lỗi tải đơn hàng đã hoàn thành: ${e.toString()}";
      print("Error fetching COMPLETED orders: $e");
    } finally {
      if (mounted) {
        setState(() {
          _completedOrders = fetchedOrders;
          _completedErrorMessage = errorMsg;
          _isLoadingCompleted = false;
        });
      }
    }
  }

  Future<List<KitchenListOrder>> _fetchOrdersWithStatus(String status) async {
    final baseUrl =
        'https://soa-deploy.up.railway.app/kitchen/get-orders-by-status/';
    final url = Uri.parse('$baseUrl$status');
    print("Fetching orders with status '$status': $url");
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
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
            "Error fetching orders with status '$status': ${response.statusCode}, Body: $errorBody");
        throw Exception(
            'Failed to load orders (status $status): ${response.statusCode}');
      }
    } catch (e) {
      print("Network/Timeout Error fetching orders with status '$status': $e");
      throw Exception('Network error fetching orders (status $status)');
    }
  }

  Future<int?> _fetchTableNumber(int sessionId) async {
    if (_tableNumberCache.containsKey(sessionId)) {
      return _tableNumberCache[sessionId];
    }
    if (_fetchingTableSessionIds.contains(sessionId)) {
      print("[Table API] Already fetching $sessionId. Skipping.");
      return null;
    }
    _fetchingTableSessionIds.add(sessionId);
    final url = Uri.parse(
        'https://soa-deploy.up.railway.app/order/session/$sessionId/table-number');
    print("[Table API] Fetching $sessionId - URL: $url");
    int? resultTableNumber;
    String rawBody = "N/A";
    int? statusCode = -1;
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      statusCode = response.statusCode;
      try {
        rawBody = utf8.decode(response.bodyBytes);
      } catch (e) {
        rawBody = "Error decoding body: $e";
      }
      print(
          "[Table API] Response $sessionId | Status: $statusCode | Body: $rawBody");
      if (response.statusCode == 200) {
        final decodedData = jsonDecode(rawBody);
        dynamic tableNumberData;
        if (decodedData is Map && decodedData.containsKey('table_number')) {
          tableNumberData = decodedData['table_number'];
        } else if (decodedData is int || decodedData is String) {
          tableNumberData = decodedData;
        } else if (decodedData is Map &&
            decodedData.containsKey('data') &&
            decodedData['data'] is Map &&
            decodedData['data'].containsKey('table_number')) {
          tableNumberData = decodedData['data']['table_number'];
          print("[Table API] Parsed nested 'data' for $sessionId");
        }
        if (tableNumberData is int) {
          resultTableNumber = tableNumberData;
        } else if (tableNumberData is String) {
          if (tableNumberData.isNotEmpty) {
            resultTableNumber = int.tryParse(tableNumberData);
          } else {
            print(
                "[Table API] Warning: Empty string for table number $sessionId.");
            resultTableNumber = -1;
          }
        } else if (tableNumberData == null) {
          print("[Table API] Warning: Null value for table number $sessionId.");
          resultTableNumber = -1;
        }
        if (resultTableNumber == null) {
          print(
              "[Table API] Warning: Could not parse table number for $sessionId from type: ${tableNumberData?.runtimeType} (Value: '$tableNumberData')");
          resultTableNumber = -1;
        } else {
          print(
              "[Table API] Success: Parsed table number for $sessionId: $resultTableNumber");
        }
      } else {
        print("[Table API] Error fetching $sessionId: Status $statusCode");
        resultTableNumber = -1;
      }
    } catch (e) {
      print(
          "[Table API] Exception fetching $sessionId: $e (Status was: $statusCode)");
      resultTableNumber = -1;
    } finally {
      _fetchingTableSessionIds.remove(sessionId);
      if (mounted) {
        _tableNumberCache[sessionId] = resultTableNumber ?? -1;
        print(
            "[Table API] Cached result for $sessionId: ${_tableNumberCache[sessionId]}");
      } else {
        print(
            "[Table API] Widget disposed before caching result for $sessionId.");
      }
    }
    return resultTableNumber;
  }

  Future<void> _fetchTableNumbersForOrders(
      List<KitchenListOrder> orders) async {
    if (orders.isEmpty) return;
    final List<Future<void>> fetchFutures = [];
    final Set<int> sessionsToFetch = {};
    for (var order in orders) {
      if (!_tableNumberCache.containsKey(order.sessionId) &&
          !_fetchingTableSessionIds.contains(order.sessionId)) {
        sessionsToFetch.add(order.sessionId);
      }
    }
    if (sessionsToFetch.isNotEmpty) {
      print(
          "[Table Fetch] Need to fetch table numbers for sessions: ${sessionsToFetch.toList()}");
      _fetchingTableSessionIds.addAll(sessionsToFetch);
      for (int sessionId in sessionsToFetch) {
        fetchFutures.add(_fetchTableNumber(sessionId));
      }
      try {
        await Future.wait(fetchFutures);
        print(
            "[Table Fetch] Finished fetching batch for sessions: ${sessionsToFetch.toList()}");
      } catch (e) {
        print(
            "[Table Fetch] Error occurred during Future.wait for table numbers: $e");
      } finally {
        _fetchingTableSessionIds.removeAll(sessionsToFetch);
        print(
            "[Table Fetch] Removed fetched sessions from fetching set: ${sessionsToFetch.toList()}");
        if (mounted) {
          print(
              "[Table Fetch] Triggering setState after fetching table numbers.");
          setState(() {/* Trigger rebuild */});
        }
      }
    } else {
      print(
          "[Table Fetch] All required table numbers seem to be cached or already fetching.");
    }
    for (var order in orders) {
      order.tableNumber = _tableNumberCache[order.sessionId];
    }
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
      print("Error setting dialog state for loading (Order $orderId): $e");
      return;
    }
    final url = Uri.parse(
        'https://soa-deploy.up.railway.app/kitchen/order/$orderId/items');
    print('Fetching order detail: ${url.toString()}');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> decodedData =
            jsonDecode(utf8.decode(response.bodyBytes));
        final List<KitchenOrderDetailItem> fetchedItems = decodedData
            .map((jsonItem) => KitchenOrderDetailItem.fromJson(
                jsonItem as Map<String, dynamic>))
            .toList();
        try {
          setDialogState(() {
            _detailItems = fetchedItems;
            _isDetailLoading = false;
          });
        } catch (e) {
          print("Error setting dialog state with data (Order $orderId): $e");
        }
      } else {
        print(
            "Error fetching order detail for $orderId: ${response.statusCode}, Body: ${utf8.decode(response.bodyBytes)}");
        try {
          setDialogState(() {
            _detailErrorMessage = 'Lỗi tải chi tiết (${response.statusCode})';
            _isDetailLoading = false;
          });
        } catch (e) {
          print("Error setting dialog state with error (Order $orderId): $e");
        }
      }
    } catch (e) {
      print(
          "Network/Timeout Error fetching order detail for order $orderId: $e");
      if (!mounted) return;
      try {
        setDialogState(() {
          _detailErrorMessage = 'Lỗi mạng hoặc timeout.';
          _isDetailLoading = false;
        });
      } catch (e) {
        print(
            "Error setting dialog state with catch error (Order $orderId): $e");
      }
    }
  }

  // --- UI Interaction Methods ---
  void _showOrderDetailPopup(BuildContext context, KitchenListOrder order) {
    final theme = Theme.of(context);
    _isDetailLoading = false;
    _detailErrorMessage = null;
    _detailItems = [];
    _updatingItemIds.clear();
    _isCompletingAll = false;
    showDialog<void>(
        context: context,
        barrierDismissible: !_isCompletingAll && _updatingItemIds.isEmpty,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(builder: (context, setDialogState) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_detailItems.isEmpty &&
                  !_isDetailLoading &&
                  _detailErrorMessage == null) {
                _fetchOrderDetail(order.orderId, setDialogState);
              }
            });
            bool canCompleteAll = _detailItems
                .any((item) => item.status.toLowerCase() != 'served');
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.secondary)),
                        )
                      else
                        IconButton(
                          icon: Icon(Icons.done_all,
                              color: canCompleteAll
                                  ? theme.colorScheme.secondary
                                  : Colors.grey[600],
                              size: 24),
                          tooltip: 'Hoàn thành tất cả món chưa phục vụ',
                          onPressed: _isDetailLoading ||
                                  _updatingItemIds.isNotEmpty ||
                                  !canCompleteAll
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
              content: _buildPopupContent(
                  theme, setDialogState, order, _isCompletingAll),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              actions: [
                TextButton(
                  onPressed: _updatingItemIds.isNotEmpty || _isCompletingAll
                      ? null
                      : () {
                          if (Navigator.canPop(dialogContext)) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
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

  void showOrdersForTable(BuildContext parentContext, int tableNumber) {
    final theme = Theme.of(parentContext);
    final List<KitchenListOrder> ordersForTable = _pendingOrders.where((order) {
      final cachedTableNum = _tableNumberCache[order.sessionId];
      return cachedTableNum != null && cachedTableNum == tableNumber;
    }).toList();
    ordersForTable.sort((a, b) => a.orderTime.compareTo(b.orderTime));
    print(
        "Showing popup for table $tableNumber with ${ordersForTable.length} pending orders found in local list.");
    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
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
                        'Không có đơn hàng nào đang chờ xử lý cho bàn này trong danh sách hiện tại.\n(Có thể cần làm mới danh sách bếp)',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.white70),
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
                        color: theme.cardTheme.color,
                        child: ListTile(
                          leading: Icon(Icons.receipt_long,
                              color: theme.colorScheme.secondary),
                          title: Row(
                            children: [
                              if (showInProgressIcon)
                                Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(Icons.hourglass_top_rounded,
                                        color: Colors.yellowAccent[700],
                                        size: 16)),
                              Flexible(child: Text('Đơn #${order.orderId}')),
                            ],
                          ),
                          subtitle: Text('TG: $formattedTime'),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.white70),
                          onTap: () {
                            _showOrderDetailPopup(parentContext, order);
                          },
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
              label: Text('Làm mới DS Bếp',
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.secondary.withOpacity(0.8))),
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
        );
      },
    );
  }

  Widget _buildPopupContent(ThemeData theme, StateSetter setDialogState,
      KitchenListOrder order, bool isCompletingAll) {
    if (_isDetailLoading) {
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
    }
    if (_detailErrorMessage != null) {
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
    }
    if (_detailItems.isEmpty) {
      return Container(
          height: 100,
          padding: const EdgeInsets.all(kDefaultPadding * 2),
          alignment: Alignment.center,
          child: Text('Không có món ăn nào trong đơn hàng này.',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.white60)));
    }
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
                    color: theme.cardTheme.color,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: kDefaultPadding * 1.2,
                            vertical: kDefaultPadding),
                        child: Row(children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('${item.name} (SL: ${item.quantity})',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                            fontSize: 14.5,
                                            color: isServed
                                                ? Colors.white.withOpacity(0.6)
                                                : Colors.white,
                                            decoration: isServed
                                                ? TextDecoration.lineThrough
                                                : null,
                                            decorationColor: Colors.white54),
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
                                                backgroundColor:
                                                    Colors.green[600],
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
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
                                                    Colors.grey[600],
                                                disabledForegroundColor:
                                                    Colors.grey[300],
                                              ),
                                              onPressed: isCompletingAll ||
                                                      _updatingItemIds
                                                          .isNotEmpty
                                                  ? null
                                                  : () {
                                                      _updatePopupOrderItemStatus(
                                                          order,
                                                          item,
                                                          'served',
                                                          setDialogState);
                                                    },
                                              child: const Text('Hoàn thành'))))
                        ]))),
              );
            }));
  }

  Future<void> _updatePopupOrderItemStatus(
      KitchenListOrder order,
      KitchenOrderDetailItem item,
      String newStatus,
      StateSetter setDialogState) async {
    if (_updatingItemIds.contains(item.orderItemId)) return;
    if (!mounted) return;
    try {
      setDialogState(() {
        _updatingItemIds.add(item.orderItemId);
      });
    } catch (e) {
      print(
          "Error setting dialog state for update start (Item ${item.orderItemId}): $e");
      _updatingItemIds.remove(item.orderItemId);
      return;
    }
    print("Attempting PATCH: Item ${item.orderItemId} -> Status '$newStatus'");
    final url = Uri.parse(
            'https://soa-deploy.up.railway.app/kitchen/order-items/${item.orderItemId}/status')
        .replace(queryParameters: {'status': newStatus});
    final headers = {'Content-Type': 'application/json'};
    bool success = false;
    try {
      final response = await http
          .patch(url, headers: headers)
          .timeout(const Duration(seconds: 10));
      if (!mounted) {
        print("Widget disposed during API call for item ${item.orderItemId}.");
        return;
      }
      if (response.statusCode == 200 || response.statusCode == 204) {
        print("API Success: Item ${item.orderItemId} updated to '$newStatus'.");
        success = true;
        final index =
            _detailItems.indexWhere((i) => i.orderItemId == item.orderItemId);
        if (index != -1) {
          try {
            setDialogState(() => _detailItems[index].status = newStatus);
          } catch (e) {
            print(
                "Error setting dialog state with success data (dialog might have closed): $e");
            if (mounted) _detailItems[index].status = newStatus;
          }
          bool allItemsInThisOrderServed =
              _detailItems.every((i) => i.status.toLowerCase() == 'served');
          if (allItemsInThisOrderServed) {
            print("Order ${order.orderId} fully served.");
            Future.delayed(Duration(milliseconds: 100), () {
              if (mounted) {
                print(
                    "Refreshing pending orders after order ${order.orderId} completion.");
                _fetchPendingOrders(forceRefresh: true);
              }
            });
            if (order.tableNumber != null && order.tableNumber! > 0) {
              print("Calling onTableCleared for table ${order.tableNumber}");
              try {
                widget.onTableCleared?.call(order.tableNumber!);
              } catch (e) {
                print("Error calling onTableCleared: $e");
              }
            } else {
              print(
                  "Warning: Cannot call onTableCleared (invalid table number ${order.tableNumber}) for order ${order.orderId}");
              if (mounted)
                Future.delayed(Duration(milliseconds: 200),
                    () => _fetchPendingOrders(forceRefresh: true));
            }
          }
        } else {
          print(
              "Warning: Updated item ${item.orderItemId} not found in local _detailItems list after successful API call.");
        }
      } else {
        print(
            "API Error updating item ${item.orderItemId}: ${response.statusCode}, Body: ${utf8.decode(response.bodyBytes)}");
        String errorMsg = 'Lỗi cập nhật món (${response.statusCode})';
        try {
          final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorBody is Map && errorBody.containsKey('detail')) {
            errorMsg += ': ${errorBody['detail']}';
          }
        } catch (_) {}
        if (mounted)
          ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
              content: Text(errorMsg), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      if (!mounted) return;
      print(
          "Network/Timeout Error updating order item ${item.orderItemId} status: $e");
      if (mounted)
        ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(
            content: Text('Lỗi mạng khi cập nhật trạng thái.'),
            backgroundColor: Colors.orangeAccent));
    } finally {
      if (mounted) {
        try {
          setDialogState(() {
            _updatingItemIds.remove(item.orderItemId);
          });
        } catch (e) {
          print(
              "Error setting dialog state in finally (dialog might have closed): $e");
          _updatingItemIds.remove(item.orderItemId);
        }
      } else {
        _updatingItemIds.remove(item.orderItemId);
      }
    }
  }

  Future<void> _completeAllItemsForOrder(KitchenListOrder order,
      StateSetter setDialogState, BuildContext originalDialogContext) async {
    if (_isCompletingAll || _updatingItemIds.isNotEmpty) return;
    if (!mounted) return;
    final List<int> itemsToComplete = _detailItems
        .where((item) => item.status.toLowerCase() != 'served')
        .map((item) => item.orderItemId)
        .toList();
    if (itemsToComplete.isEmpty) return;
    print(
        "Starting 'Complete All' for order ${order.orderId}, items: $itemsToComplete");
    try {
      setDialogState(() {
        _isCompletingAll = true;
      });
    } catch (e) {
      print("Error setting dialog state for 'Complete All' start: $e");
      return;
    }
    List<Future<bool>> updateFutures = itemsToComplete
        .map((itemId) => _callUpdateItemApi(itemId, 'served'))
        .toList();
    bool allSucceeded = false;
    try {
      final List<bool> results = await Future.wait(updateFutures);
      allSucceeded = results.every((success) => success);
      if (!mounted) return;
      if (allSucceeded) {
        print("'Complete All' API calls successful for order ${order.orderId}");
        if (Navigator.canPop(originalDialogContext)) {
          Navigator.of(originalDialogContext).pop();
          print(
              "Popped dialog after successful Complete All for order ${order.orderId}.");
        } else {
          print(
              "Could not pop dialog after Complete All (maybe already closed?).");
        }
        if (mounted) {
          setState(() {
            _pendingOrders.removeWhere((o) => o.orderId == order.orderId);
            _inProgressOrderIds.remove(order.orderId);
            print(
                "Removed order ${order.orderId} from local pending list immediately after Complete All.");
          });
          if (order.tableNumber != null && order.tableNumber! > 0) {
            print(
                "Calling onTableCleared for table ${order.tableNumber} after Complete All");
            try {
              widget.onTableCleared?.call(order.tableNumber!);
            } catch (e) {
              print("Error calling onTableCleared: $e");
            }
          } else {
            print(
                "Warning: Cannot call onTableCleared (invalid table number ${order.tableNumber}) after Complete All for order ${order.orderId}");
            _fetchPendingOrders(forceRefresh: true);
          }
          if (_currentView == OrderListView.completed) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) _fetchCompletedOrders();
            });
          }
        }
      } else {
        print(
            "'Complete All' failed for order ${order.orderId}: One or more item updates failed.");
        bool isDialogStillMounted = true;
        try {
          (originalDialogContext as Element).widget;
        } catch (e) {
          isDialogStillMounted = false;
        }
        if (mounted && isDialogStillMounted) {
          ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(
            content: Text(
                'Lỗi: Không thể hoàn thành tất cả các món. Vui lòng thử lại hoặc hoàn thành từng món.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 3),
          ));
          try {
            _fetchOrderDetail(order.orderId, setDialogState);
          } catch (e) {
            print(
                "Error refreshing dialog details after partial Complete All failure: $e");
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      print(
          "Error during 'Complete All' process for order ${order.orderId}: $e");
      bool isDialogStillMounted = true;
      try {
        (originalDialogContext as Element).widget;
      } catch (e) {
        isDialogStillMounted = false;
      }
      if (mounted && isDialogStillMounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(
          content: Text('Đã xảy ra lỗi trong quá trình hoàn thành tất cả.'),
          backgroundColor: Colors.orangeAccent,
        ));
        try {
          _fetchOrderDetail(order.orderId, setDialogState);
        } catch (e) {
          print(
              "Error refreshing dialog details after Complete All exception: $e");
        }
      }
    } finally {
      if (mounted) {
        bool isDialogStillMounted = true;
        try {
          (originalDialogContext as Element).widget;
        } catch (e) {
          isDialogStillMounted = false;
        }
        if (isDialogStillMounted) {
          try {
            setDialogState(() {
              _isCompletingAll = false;
            });
          } catch (e) {
            _isCompletingAll = false;
          }
        } else {
          _isCompletingAll = false;
        }
      } else {
        _isCompletingAll = false;
      }
      print("'Complete All' process finished for order ${order.orderId}");
    }
  }

  Future<bool> _callUpdateItemApi(int orderItemId, String newStatus) async {
    final url = Uri.parse(
            'https://soa-deploy.up.railway.app/kitchen/order-items/$orderItemId/status')
        .replace(queryParameters: {'status': newStatus});
    final headers = {'Content-Type': 'application/json'};
    print("Calling API (Helper): PATCH ${url.toString()}");
    try {
      final response = await http
          .patch(url, headers: headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 || response.statusCode == 204) {
        print(
            "API Success (Helper): Item $orderItemId updated to '$newStatus'.");
        return true;
      } else {
        print(
            "API Error (Helper): Item $orderItemId failed update (${response.statusCode}), Body: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Network/Timeout Error (Helper) for item $orderItemId: $e");
      return false;
    }
  }

  // --- Helper Functions for Status Display ---
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
        return 'Đang thực hiện';
      case 'ready':
        return 'Sẵn sàng';
      case 'served':
        return 'Đã phục vụ';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status.isNotEmpty
            ? status[0].toUpperCase() + status.substring(1)
            : 'Không rõ';
    }
  }

  // --- Build Methods ---
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildViewSwitcher(theme),
        Expanded(child: _buildBodyContent(theme)),
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
                          : unselectedCol))
            ],
            selected: <OrderListView>{
              _currentView
            },
            onSelectionChanged: (Set<OrderListView> newSelection) {
              if (newSelection.isNotEmpty &&
                  newSelection.first != _currentView) {
                setState(() => _currentView = newSelection.first);
                if (_currentView == OrderListView.completed &&
                    !_completedOrdersLoaded &&
                    !_isLoadingCompleted) {
                  _fetchCompletedOrders();
                }
              }
            },
            style: theme.segmentedButtonTheme.style));
  }

  Widget _buildBodyContent(ThemeData theme) {
    Widget content;
    Future<void> Function() onRefresh;
    if (_currentView == OrderListView.pending) {
      onRefresh = () => _fetchPendingOrders(forceRefresh: true);
      if (_isLoadingPending && _pendingOrders.isEmpty)
        content = _buildShimmerLoadingList(theme);
      else if (_pendingErrorMessage != null && _pendingOrders.isEmpty)
        content = _buildErrorWidget(_pendingErrorMessage!, onRefresh);
      else if (_pendingOrders.isEmpty && !_isLoadingPending)
        content = _buildEmptyListWidget('Không có đơn hàng nào đang xử lý.',
            Icons.coffee_outlined, onRefresh);
      else
        content = _buildOrderListView(_pendingOrders);
    } else {
      onRefresh = () => _fetchCompletedOrders(forceRefresh: true);
      if (_isLoadingCompleted && _completedOrders.isEmpty)
        content = _buildShimmerLoadingList(theme);
      else if (_completedErrorMessage != null && _completedOrders.isEmpty)
        content = _buildErrorWidget(_completedErrorMessage!, onRefresh);
      else if (_completedOrders.isEmpty && !_isLoadingCompleted)
        content = _buildEmptyListWidget('Chưa có đơn hàng nào hoàn thành.',
            Icons.history_toggle_off_outlined, onRefresh);
      else
        content = _buildOrderListView(_completedOrders);
    }
    return RefreshIndicator(
        onRefresh: onRefresh,
        color: theme.colorScheme.secondary,
        backgroundColor: theme.scaffoldBackgroundColor,
        child: content);
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
            color: isServed ? Colors.grey[350] : Colors.white,
          );
          final tableErrorStyle = defaultTitleStyle?.copyWith(
              fontWeight: FontWeight.bold, color: theme.colorScheme.error);
          final tableLoadingStyle = defaultTitleStyle?.copyWith(
              fontStyle: FontStyle.italic, color: Colors.grey[500]);
          int? currentTableNumber = _tableNumberCache[order.sessionId];
          bool isFetchingThisTable =
              _fetchingTableSessionIds.contains(order.sessionId);
          order.tableNumber = currentTableNumber;
          InlineSpan tableNumberSpan;
          if (isFetchingThisTable) {
            tableNumberSpan =
                TextSpan(text: 'Đang tải...', style: tableLoadingStyle);
          } else if (currentTableNumber == null &&
              !_tableNumberCache.containsKey(order.sessionId)) {
            tableNumberSpan = WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Tooltip(
                message: 'Đang tải số bàn...',
                child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.grey[500],
                    )),
              ),
            );
          } else if (currentTableNumber == -1) {
            tableNumberSpan = TextSpan(text: 'Lỗi', style: tableErrorStyle);
          } else if (currentTableNumber != null && currentTableNumber != -1) {
            tableNumberSpan = TextSpan(
                text: currentTableNumber.toString(), style: tableNumberStyle);
          } else {
            tableNumberSpan = TextSpan(text: '?', style: tableErrorStyle);
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
              leading: Icon(Icons.receipt_long_outlined,
                  color:
                      isServed ? Colors.grey[600] : theme.colorScheme.secondary,
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
                style: isServed
                    ? const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.white54)
                    : null,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5.0),
                  child: Text('Thời gian: $formattedTime',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              isServed ? Colors.grey[500] : Colors.grey[350]))),
              trailing: isServed
                  ? Icon(Icons.check_circle_outline,
                      color: Colors.greenAccent.withOpacity(0.6))
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
                              style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                              onPressed: onRetry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Thử lại'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent))
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
} // *** End of _KitchenOrderListScreenState ***
