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
// (Data Models remain unchanged - Keep the existing MenuItem, KitchenListOrder, KitchenOrderDetailItem classes here)
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
    // (ThemeData setup remains unchanged - Keep the existing ThemeData)
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
      inputDecorationTheme: InputDecorationTheme(
        // Added for TextField styling consistency
        hintStyle: GoogleFonts.lato(color: Colors.grey[500], fontSize: 13),
        // Define other default styles if needed
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
// (MenuScreen and its State remain largely unchanged, including search and drawer fixes)
// Keep the existing _MenuScreenState class here, ensuring _buildAppDrawer is the corrected version without hoverColor on ExpansionTile.
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
  bool _showExclamationMark = false; // Related to table scrolling visibility
  double _exclamationMarkAngle = 0.0; // Related to table scrolling visibility
  final GlobalKey<_KitchenOrderListScreenState> _kitchenListKey = GlobalKey();
  int get orderScreenIndex => _categories.isEmpty ? 1 : _categories.length + 1;
  Map<int, int> _pendingOrderCountsByTable = {};
  int? _hoveredTableIndex;

  // --- Search State Variables ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  // ---------------------------

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
    _searchController.addListener(_onSearchChanged); // Add search listener
    _fetchMenuData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _onTableScroll(); // Initial check for exclamation mark
      }
    });
  }

  @override
  void dispose() {
    _tableScrollController.removeListener(_onTableScroll);
    _tableScrollController.dispose();
    _menuScrollController.dispose();
    _searchController
        .removeListener(_onSearchChanged); // Remove search listener
    _searchController.dispose(); // Dispose search controller
    // Dispose other resources if needed
    super.dispose();
  }

  // --- Search Listener and Clear Method ---
  void _onSearchChanged() {
    if (mounted && _searchQuery != _searchController.text) {
      setState(() {
        _searchQuery = _searchController.text;
      });
    } else if (!mounted) {
      _searchQuery = _searchController.text; // Update if not mounted
    }
  }

  void _clearSearch() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear(); // Listener will trigger setState
    } else if (_searchQuery.isNotEmpty) {
      if (mounted) {
        setState(() {
          _searchQuery = "";
        }); // Clear query state directly
      } else {
        _searchQuery = "";
      }
    }
  }
  // -------------------------------------

  Future<void> _fetchMenuData() async {
    // (Keep existing implementation)
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
    // (Keep existing implementation)
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
          // Use setState to update the UI
          setState(() {
            // Update in the category list
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

            // Update in the ID map (important for details view)
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
    // (Keep existing implementation)
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
    // (Keep existing implementation, ensure it calls _updateExclamationMark)
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
    // (Keep existing implementation with _clearSearch call)
    if (categoryIndex < 1 || categoryIndex > _categories.length) {
      print("Error: Invalid category index $categoryIndex requested.");
      return;
    }
    int arrayIndex = categoryIndex - 1; // Convert to 0-based index
    if (arrayIndex >= _categoryKeys.length) {
      print(
          "Error: Category key not found for index $arrayIndex. Keys length: ${_categoryKeys.length}");
      return;
    }

    bool needsViewChange = selectedIndex != categoryIndex;

    if (needsViewChange) {
      _clearSearch(); // Clear search BEFORE changing the index/view
      setState(() {
        selectedIndex = categoryIndex;
        _isMenuCategoriesExpanded = true; // Ensure menu section is expanded
      });
      // Add a small delay to allow the IndexedStack to switch and layout
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _performScroll(arrayIndex);
        }
      });
    } else {
      // Already viewing the correct category, just scroll to the top of it
      _performScroll(arrayIndex);
    }
  }

  void _performScroll(int arrayIndex) {
    // (Keep existing implementation)
    if (!mounted || arrayIndex < 0 || arrayIndex >= _categoryKeys.length)
      return;
    final key = _categoryKeys[arrayIndex];
    final context = key.currentContext;
    if (context != null) {
      // Ensure we are actually in a state where the menu list is potentially visible
      bool isViewingAnyCategory =
          selectedIndex >= 1 && selectedIndex <= _categories.length;
      if (isViewingAnyCategory) {
        // Check if the scroll controller is attached and ready
        if (_menuScrollController.hasClients &&
            _menuScrollController.position.hasContentDimensions) {
          print("Scrolling to category index: $arrayIndex");
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.0, // Align to the top
          );
        } else {
          // If controller not ready, schedule scroll after the next frame
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
      // Optionally, schedule a retry if context might become available later
      // WidgetsBinding.instance.addPostFrameCallback((_) => _performScroll(arrayIndex)); // Be careful with infinite loops
    }
  }

  void _showOrderPopup(BuildContext context, int tableIndex) {
    // (Keep existing implementation)
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
    // (Keep existing implementation)
    if (selectedIndex == 0) return 0; // Tables
    if (selectedIndex == orderScreenIndex) return 1; // Orders
    // If any menu category is selected OR the menu panel is expanded, highlight Menu
    bool isAnyCategorySelected =
        selectedIndex >= 1 && selectedIndex <= _categories.length;
    if (isAnyCategorySelected || _isMenuCategoriesExpanded) return 2;
    return 0; // Default fallback
  }

  int _getCrossAxisCount(BuildContext context) {
    // (Keep existing implementation)
    return MediaQuery.of(context).size.width > 1200
        ? kTableGridCrossAxisCountLarge
        : kTableGridCrossAxisCountSmall;
  }

  bool _isSmallScreen(BuildContext context) {
    // (Keep existing implementation)
    return MediaQuery.of(context).size.width <= 800;
  }

  void _updateTableOrderCounts(Map<int, int> newCounts) {
    // (Keep existing implementation)
    if (!mounted) return;
    bool changed = false;
    _pendingOrderCountsByTable = Map.from(newCounts); // Store the latest counts
    // Update the 'tables' list for UI display
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
      setState(() {}); // Rebuild to show updated badges
    }
  }

  void _handleTableCleared(int tableNumber) {
    // (Keep existing implementation)
    if (!mounted) return;
    print("Received table cleared signal for table: $tableNumber");
    int tableIndex = tableNumber - 1;
    if (tableIndex >= 0 && tableIndex < tables.length) {
      if ((tables[tableIndex]['pendingOrderCount'] as int? ?? 0) > 0) {
        setState(() {
          tables[tableIndex]['pendingOrderCount'] = 0;
          _pendingOrderCountsByTable[tableNumber] =
              0; // Also update the counts map
        });
        print(
            "Set pending order count to 0 for table $tableNumber in MenuScreen.");
        // Optional: Show a snackbar confirmation
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
        // Ensure the counts map is also zero, just in case
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
    // (Keep existing implementation)
    final bool smallScreen = _isSmallScreen(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: smallScreen ? _buildAppBar(theme) : null,
      drawer: smallScreen ? _buildAppDrawer(theme) : null,
      body: Container(
        // Optional: Add a subtle background gradient or pattern
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor,
              theme.scaffoldBackgroundColor
                  .withBlue(theme.scaffoldBackgroundColor.blue + 5)
                  .withGreen(theme.scaffoldBackgroundColor.green +
                      2), // Slightly different shade at bottom
            ],
            stops: const [0.3, 1.0],
          ),
        ),
        child: Stack(
          // Stack for the exclamation mark overlay
          children: [
            Row(
              children: [
                if (!smallScreen) _buildNavigationRail(theme),
                if (!smallScreen)
                  const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Colors.white12), // Subtle separator
                Expanded(
                  child: Column(
                    children: [
                      if (!smallScreen) _buildLargeScreenHeader(theme),
                      if (!smallScreen)
                        Container(
                            height: 0.8,
                            color: theme.dividerTheme.color ??
                                Colors.white24), // Header separator
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets
                              .zero, // Content padding handled internally
                          child: _buildCurrentView(theme),
                        ),
                      ),
                      _buildBottomActionBar(theme),
                    ],
                  ),
                ),
              ],
            ),
            // Overlay for the exclamation mark (related to table scrolling)
            if (selectedIndex == 0 && _showExclamationMark)
              _buildExclamationOverlay(smallScreen),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(ThemeData theme) {
    // (Keep existing implementation)
    return AppBar(
      title: const Text('WELCOME'), // Consider making dynamic later
      actions: _buildAppBarActions(),
    );
  }

  List<Widget> _buildAppBarActions() {
    // (Keep existing implementation)
    return [
      IconButton(
          icon: const Icon(Icons.person_outline),
          tooltip: 'Tài khoản',
          onPressed: () {}),
      IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Tìm kiếm',
          onPressed: () {}), // General search?
      const SizedBox(width: kDefaultPadding / 2),
    ];
  }

  // --- CORRECTED: _buildAppDrawer without hoverColor on ExpansionTile ---
  Widget _buildAppDrawer(ThemeData theme) {
    bool isMenuSelected =
        selectedIndex >= 1 && selectedIndex <= _categories.length;
    Color highlight = theme.colorScheme.secondary;
    final divider = Divider(
      color: theme.dividerTheme.color?.withOpacity(0.5) ?? Colors.white24,
      thickness: theme.dividerTheme.thickness ?? 1,
      height: kDefaultPadding * 1.5, // Adjust spacing
      indent: kDefaultPadding * 2,
      endIndent: kDefaultPadding * 2,
    );

    return Drawer(
      backgroundColor:
          theme.dialogTheme.backgroundColor, // Use consistent dark background
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
            child: Center(child: _buildLogo()), // Add your logo here
          ),
          _buildDrawerItem(theme, Icons.table_restaurant_outlined,
              'Danh sách bàn ăn', 0, selectedIndex, highlight, () {
            _clearSearch(); // Clear search when navigating away
            setState(() {
              selectedIndex = 0;
              _isMenuCategoriesExpanded = false;
              Navigator.pop(context);
            });
          }),
          divider,
          _buildDrawerItem(
              theme,
              Icons.receipt_long_outlined,
              'Danh sách đơn hàng',
              orderScreenIndex,
              selectedIndex,
              highlight, () {
            _clearSearch(); // Clear search when navigating away
            setState(() {
              selectedIndex = orderScreenIndex;
              _isMenuCategoriesExpanded = false;
              Navigator.pop(context);
            });
          }),
          divider,
          ExpansionTile(
            // *** REMOVED hoverColor HERE ***
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
                // Prevent expanding if menu is loading or failed
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_isLoadingMenu
                      ? 'Đang tải menu...'
                      : 'Lỗi tải menu, không thể mở rộng.'),
                  duration: const Duration(seconds: 1),
                ));
                // Ensure the state is reset if expansion was attempted wrongly
                Future.delayed(Duration.zero, () {
                  // Schedule state update after build
                  if (mounted)
                    setState(() => _isMenuCategoriesExpanded = false);
                });
              }
            },
            iconColor: Colors.white, // Color for the arrow icon
            collapsedIconColor: Colors.white70,
            // hoverColor: theme.colorScheme.secondary.withOpacity(0.1), // *** LINE REMOVED ***
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
                                theme, true), // Pass isDrawer=true
              ),
            ],
          ),
          divider,
          // Add other drawer items like Settings, Logout etc. if needed
        ],
      ),
    );
  }
  // --- END CORRECTED _buildAppDrawer ---

  Widget _buildDrawerItem(
      ThemeData theme,
      IconData icon,
      String title,
      int indexValue,
      int currentIndex,
      Color highlightColor,
      VoidCallback onTapAction) {
    // (Keep existing implementation with hoverColor)
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
      hoverColor: theme.colorScheme.secondary
          .withOpacity(0.1), // *** HOVER ADDED HERE ***
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: kDefaultPadding * 2.5),
      dense: true, // Makes the item vertically smaller
    );
  }

  Widget _buildNavigationRail(ThemeData theme) {
    // (Keep existing implementation)
    final Color selectedColor = theme.colorScheme.secondary;
    final Color unselectedColor = Colors.white;
    final railLabelStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: 15.5,
      letterSpacing: 0.3,
    );
    final int currentRailIndex = _getNavigationRailSelectedIndex();

    // Data for destinations
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
          // Use InkWell for better customization and hover/splash
          onTap: () => _handleDestinationSelected(data['index'] as int),
          borderRadius: BorderRadius.circular(10),
          splashColor: selectedColor.withOpacity(0.1),
          highlightColor: selectedColor.withOpacity(0.05),
          hoverColor: selectedColor.withOpacity(0.08), // Explicit hover color
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
                const SizedBox(width: kDefaultPadding * 1.5), // Indent icon
                Icon(
                  data['icon'] as IconData,
                  color: isSelected
                      ? selectedColor
                      : unselectedColor.withOpacity(0.8),
                  size: isSelected ? 30 : 28, // Slightly larger when selected
                ),
                const SizedBox(
                    width:
                        kDefaultPadding * 1.5), // Space between icon and label
                Flexible(
                  // Allow label to take remaining space
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
      // Add dividers between items, except after the last one
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
      color: theme.dialogTheme.backgroundColor, // Consistent background
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start, // Align logo etc. to start
        children: [
          const SizedBox(height: kDefaultPadding * 2.5), // Top padding
          Padding(
            padding: const EdgeInsets.only(
                left: kDefaultPadding * 2), // Logo padding
            child: _buildLogo(),
          ),
          const SizedBox(height: kDefaultPadding * 3.5), // Space below logo
          // Use Column for the navigation items
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: kDefaultPadding), // Padding for the items column
            child: Column(
              mainAxisSize: MainAxisSize.min, // Take only needed vertical space
              children: destinationsWidgets,
            ),
          ),
          // Animated container for category buttons
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: (_isMenuCategoriesExpanded &&
                    !_isLoadingMenu &&
                    _menuErrorMessage == null &&
                    _categories.isNotEmpty)
                ? Flexible(
                    // Allow this section to scroll if needed
                    child: Container(
                      margin: const EdgeInsets.only(
                          top: kDefaultPadding), // Space above buttons
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(kDefaultPadding, 0,
                            kDefaultPadding, kDefaultPadding * 2),
                        child: SingleChildScrollView(
                          // Make buttons scrollable if they overflow
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: kDefaultPadding *
                                    1.5), // Inner padding for grid
                            child: _buildCategoryButtonGrid(
                                theme, false), // isDrawer = false
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(), // Collapsed state
          ),
        ],
      ),
    );
  }

  void _handleDestinationSelected(int index) {
    // (Keep existing implementation with _clearSearch calls)
    setState(() {
      if (index == 0) {
        // Tables
        selectedIndex = 0;
        _isMenuCategoriesExpanded = false;
        _clearSearch(); // Clear search when navigating away
      } else if (index == 1) {
        // Orders
        selectedIndex = orderScreenIndex;
        _isMenuCategoriesExpanded = false;
        _clearSearch(); // Clear search when navigating away
      } else if (index == 2) {
        // Menu section clicked
        if (_isLoadingMenu || _menuErrorMessage != null) {
          // Prevent interaction if menu isn't ready
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isLoadingMenu
                ? 'Đang tải menu...'
                : _menuErrorMessage ?? 'Lỗi menu'),
            duration: const Duration(seconds: 1),
          ));
          return; // Don't change state
        }

        // Toggle expansion
        _isMenuCategoriesExpanded = !_isMenuCategoriesExpanded;

        if (_isMenuCategoriesExpanded) {
          // If expanding, and currently viewing Tables or Orders, or no category selected
          bool isViewingTablesOrOrders =
              (selectedIndex == 0 || selectedIndex == orderScreenIndex);
          bool noCategorySelected =
              !(selectedIndex >= 1 && selectedIndex <= _categories.length);
          if ((isViewingTablesOrOrders || noCategorySelected) &&
              _categories.isNotEmpty) {
            _clearSearch(); // Clear search when first category is shown
            selectedIndex = 1; // Select the first category (index 1)
            // Schedule scroll after state update and potential animation
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && _isMenuCategoriesExpanded) {
                // Check if still expanded
                _scrollToCategory(1); // Scroll to the first category
              }
            });
          }
        } else {
          // If collapsing, and were viewing a category, clear search
          if (selectedIndex >= 1 && selectedIndex <= _categories.length) {
            _clearSearch();
          }
          // Optional: If collapsing, maybe navigate back to Tables?
          // selectedIndex = 0;
        }

        // Handle case where menu is expanded but there are no categories
        if (_isMenuCategoriesExpanded && _categories.isEmpty) {
          _isMenuCategoriesExpanded = false; // Immediately collapse back
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Chưa có danh mục món ăn nào.'),
            duration: Duration(seconds: 2),
          ));
        }
      }
    });
  }

  Widget _buildLogo({double height = kLogoHeight, double? width}) {
    // (Keep existing implementation)
    // IMPORTANT: Replace with your actual logo asset path
    const String logoAssetPath = 'assets/spidermen.jpg'; // <--- YOUR LOGO PATH

    return ClipRRect(
      // Clip logo if needed
      borderRadius: BorderRadius.circular(kDefaultPadding * 0.75),
      child: Image.asset(
        logoAssetPath,
        width: width, // Use provided width or calculate based on height
        height: height,
        fit: BoxFit.contain, // Adjust fit as needed (contain, cover, etc.)
        // Error handling for missing asset
        errorBuilder: (context, error, stackTrace) {
          print("Error loading logo asset '$logoAssetPath': $error");
          return Container(
              height: height,
              width: width ?? height * 1.8, // Estimate width if not provided
              color: Colors.grey[700], // Placeholder background
              child: Column(
                // Center error icon and text
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image_outlined,
                      color: Colors.red[300], size: height * 0.5),
                  const SizedBox(height: 4),
                  Text("Logo Error",
                      style: TextStyle(color: Colors.red[300], fontSize: 10)),
                ],
              ));
        },
        // Optional: Fade-in animation
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
    // (Keep existing implementation)
    return Container(
      color: theme.appBarTheme.backgroundColor, // Match AppBar color
      padding: const EdgeInsets.symmetric(
          horizontal: kDefaultPadding * 2, vertical: kDefaultPadding * 1.5),
      child: Row(
        children: [
          Expanded(
              child: Text('WELCOME',
                  textAlign: TextAlign.center,
                  style: theme.appBarTheme.titleTextStyle)),
          ..._buildAppBarActions(), // Re-use the same actions
        ],
      ),
    );
  }

  Widget _buildTableGrid(ThemeData theme) {
    // (Keep existing implementation)
    int crossAxisCount = _getCrossAxisCount(context);
    return GridView.builder(
      key: const PageStorageKey<String>(
          'tableGrid'), // Keep state when switching views
      padding: const EdgeInsets.all(kDefaultPadding * 1.8),
      controller: _tableScrollController, // Attach scroll controller
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: kTableGridSpacing * 1.4,
        mainAxisSpacing: kTableGridSpacing * 1.4,
        childAspectRatio: 1.0, // Square items
      ),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        int pendingCount = table['pendingOrderCount'] as int? ?? 0;
        bool hasPendingOrders = pendingCount > 0;
        bool isHovered = _hoveredTableIndex == index;

        // Determine colors and styles based on state
        Color cardBackgroundColor;
        Color iconColor;
        Color textColor;
        Color badgeColor =
            theme.colorScheme.error; // Typically red for pending/error
        Color borderColor = Colors.transparent;
        double elevation = kCardElevation; // Base elevation

        if (hasPendingOrders) {
          cardBackgroundColor = Color.lerp(
              theme.cardTheme.color!,
              theme.colorScheme.error.withOpacity(0.4),
              0.5)!; // Blend with error color
          iconColor = Colors.yellowAccent[100]!; // Highlight icon
          textColor = Colors.white;
          borderColor = theme.colorScheme.error.withOpacity(0.8);
          elevation = kCardElevation + 4; // Increase elevation
        } else {
          cardBackgroundColor = theme.cardTheme.color!;
          iconColor = Colors.white.withOpacity(0.65);
          textColor = Colors.white.withOpacity(0.85);
        }

        if (isHovered) {
          cardBackgroundColor = cardBackgroundColor
              .withOpacity(0.85); // Slightly transparent on hover
          borderColor = hasPendingOrders
              ? theme.colorScheme.error
              : theme.colorScheme.secondary
                  .withOpacity(0.7); // Highlight border on hover
          elevation += 4; // Further increase elevation on hover
        }

        // Use MouseRegion for hover effects
        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredTableIndex = index),
          onExit: (_) => setState(() => _hoveredTableIndex = null),
          cursor: SystemMouseCursors.click, // Indicate interactivity
          child: AnimatedContainer(
            // Animate border and shadow changes
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                  14), // Slightly larger radius for the border/shadow container
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isHovered ? 0.35 : 0.2),
                  blurRadius: isHovered ? 10 : 5,
                  spreadRadius: 0,
                  offset: Offset(
                      0, isHovered ? 4 : 2), // Adjust shadow offset on hover
                )
              ],
            ),
            child: Material(
              // Use Material for InkWell splash and elevation visuals
              color: cardBackgroundColor,
              borderRadius:
                  BorderRadius.circular(13), // Inner radius matching card
              clipBehavior: Clip.antiAlias, // Clip ink splash
              elevation: 0, // Elevation handled by AnimatedContainer's shadow
              child: InkWell(
                onTap: () => _showOrderPopup(context, index),
                borderRadius: BorderRadius.circular(13),
                splashColor: theme.colorScheme.secondary.withOpacity(0.15),
                highlightColor: theme.colorScheme.secondary.withOpacity(0.1),
                child: Stack(
                  // Stack for the badge
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(kDefaultPadding * 1.2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.table_restaurant_rounded, // Table icon
                            size: 55, // Adjust size as needed
                            color: iconColor,
                          ),
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
                          // Add more info like status if needed
                        ],
                      ),
                    ),
                    // Pending order count badge
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
                                  width: 1.8), // White border for contrast
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black87,
                                    blurRadius: 5,
                                    offset: Offset(1, 1))
                              ] // Subtle shadow
                              ),
                          constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28), // Ensure minimum size
                          child: Center(
                            child: Text(
                              '$pendingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize:
                                    11.5, // Slightly smaller font for badge
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
      },
    );
  }

  Widget _buildSelectedMenuCategoryList(ThemeData theme) {
    // (Keep existing implementation with Search Bar)
    int categoryArrayIndex = selectedIndex - 1;
    if (categoryArrayIndex < 0 || categoryArrayIndex >= _categories.length) {
      return Center(
          child: Text("Danh mục không hợp lệ.",
              style: theme.textTheme.bodyMedium));
    }
    if (categoryArrayIndex >= _categoryKeys.length) {
      return Center(
          child: Text("Đang chuẩn bị danh mục...",
              style: theme.textTheme.bodySmall)); // Key might not be ready yet
    }

    final String categoryName = _categories[categoryArrayIndex];
    final List<MenuItem> allItemsInCategory = // Get all items for the category
        _menuItemsByCategory[categoryName] ?? [];
    final GlobalKey categoryHeaderKey = _categoryKeys[categoryArrayIndex];

    // --- FILTERING LOGIC based on _searchQuery ---
    final String query = _searchQuery.toLowerCase().trim();
    final List<MenuItem> filteredItems;
    if (query.isEmpty) {
      filteredItems = allItemsInCategory; // No filter applied
    } else {
      filteredItems = allItemsInCategory.where((item) {
        final itemNameLower = item.name.toLowerCase();
        final itemIdString = item.itemId.toString();
        return itemNameLower.contains(query) || itemIdString.contains(query);
      }).toList();
    }
    // --- END FILTERING LOGIC ---

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          key: categoryHeaderKey, // Keep key on the outer padding
          padding: const EdgeInsets.fromLTRB(
              kDefaultPadding * 2,
              kDefaultPadding * 1.5, // Adjust top padding slightly
              kDefaultPadding * 2,
              kDefaultPadding * 0.5), // Adjust bottom padding slightly
          child: Row(
            // Use Row for Title and Search Bar
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space them out
            crossAxisAlignment: CrossAxisAlignment.center, // Align vertically
            children: [
              // Category Title (Flexible to allow shrinking)
              Flexible(
                child: Text(
                  categoryName,
                  style: theme.textTheme.headlineSmall,
                  overflow: TextOverflow.ellipsis, // Prevent overflow
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: kDefaultPadding * 1.5), // Spacer

              // Search Field - Constrained Width
              SizedBox(
                width: 250, // Adjust width as needed
                height: 40, // Fixed height for consistency
                child: TextField(
                  controller: _searchController,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontSize: 13.5), // Input text style
                  decoration: InputDecoration(
                    hintText: 'Tìm món (tên, ID)...',
                    hintStyle: theme.textTheme.bodySmall
                        ?.copyWith(fontSize: 12.5, color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search,
                        size: 18, color: Colors.grey[500]), // Search icon
                    // Clear button appears only when typing
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                size: 18, color: Colors.grey[500]),
                            tooltip: 'Xóa tìm kiếm',
                            splashRadius: 15, // Smaller splash for icon button
                            padding: EdgeInsets.zero, // Remove extra padding
                            constraints:
                                const BoxConstraints(), // Remove constraints for tighter fit
                            onPressed: () {
                              _searchController.clear();
                              // _onSearchChanged listener handles state update
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 0, horizontal: 10), // Adjust padding
                    isDense: true, // Makes the text field more compact
                    filled: true, // Add a background fill
                    fillColor: theme.scaffoldBackgroundColor
                        .withOpacity(0.4), // Darker fill
                    // Border styling
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(20), // Rounded corners
                      borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                          width: 0.5), // Default border
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                          width: 0.5), // Border when enabled
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                          color: theme.colorScheme.secondary.withOpacity(
                              0.7), // Highlight border when focused
                          width: 1.0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding * 2),
          child: Divider(
              // Separator line below header
              color: theme.dividerTheme.color,
              thickness: theme.dividerTheme.thickness),
        ),
        const SizedBox(height: kDefaultPadding),

        // --- Conditional Content based on Filtering ---
        if (allItemsInCategory.isEmpty) // Check if the category itself is empty
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
        else if (filteredItems.isEmpty &&
            query.isNotEmpty) // Specific message for no search results
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(kDefaultPadding * 2),
                child: Text(
                  "Không tìm thấy món ăn nào khớp với \"$query\".",
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else // Display the filtered items (or all items if query is empty)
          Expanded(
            child: ListView.builder(
              // *** Use filteredItems list ***
              key: PageStorageKey<String>(
                  'menuList_${categoryName}_$query'), // Include query in key for state preservation
              controller: _menuScrollController,
              padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
              itemCount: filteredItems.length, // Use count from filtered list
              itemBuilder: (context, itemIndex) {
                // *** Get item from filtered list ***
                MenuItem currentItemFromFiltered = filteredItems[itemIndex];
                // Get the potentially updated item state from the central map
                MenuItem item =
                    _menuItemsById[currentItemFromFiltered.itemId] ??
                        currentItemFromFiltered;

                String? relativePathFromDb = item.img;
                Widget imageWidget;
                if (relativePathFromDb != null &&
                    relativePathFromDb.isNotEmpty) {
                  String assetPath = 'assets/' +
                      (relativePathFromDb.startsWith('/')
                          ? relativePathFromDb.substring(1)
                          : relativePathFromDb);
                  // print("Attempting to load asset: $assetPath for item: ${item.name}"); // Debug print
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
                                  // Fade in image
                                  opacity: frame == null ? 0 : 1,
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeOut,
                                  child: child,
                                ));
                } else {
                  // print("No image path for item: ${item.name}"); // Debug print
                  imageWidget = _buildPlaceholderImage();
                }

                // --- Build the Card using the 'item' (which has potentially updated 'available' status) ---
                return Card(
                  margin: const EdgeInsets.only(
                      bottom: kDefaultPadding * 1.5), // Spacing between cards
                  child: Row(
                    children: [
                      ClipRRect(
                        // Clip image corners
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
                                item.name, // Use name from 'item'
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontSize: 16.5),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: kDefaultPadding * 0.6),
                              Text(
                                "ID: ${item.itemId}", // Use ID from 'item'
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
                          item: item, // Pass the potentially updated 'item'
                          onStatusChanged: _updateItemStatus,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        // --- END Conditional Content ---
      ],
    );
  }

  Widget _buildPlaceholderImage({bool hasError = false}) {
    // (Keep existing implementation)
    return Container(
      width: kMenuItemImageSize,
      height: kMenuItemImageSize,
      color: const Color(0xFF37474F), // Dark background for placeholder
      child: Icon(
        hasError
            ? Icons.image_not_supported_outlined
            : Icons.restaurant, // Different icons for error vs no image
        color: hasError ? Colors.redAccent.withOpacity(0.7) : Colors.grey[500],
        size:
            kMenuItemImageSize * 0.4, // Adjust icon size relative to container
      ),
    );
  }

  Widget _buildBottomActionBar(ThemeData theme) {
    // (Keep existing implementation)
    final footerTextStyle = theme.textTheme.bodySmall?.copyWith(
      color: Colors.white.withOpacity(0.8),
      fontSize: 11.5,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
    );
    return Container(
      height: kBottomActionBarHeight * 0.7, // Reduced height for footer
      decoration: BoxDecoration(
        // Optional: add background or border
        border: Border(
            top: BorderSide(
                color: theme.dividerTheme.color ?? Colors.white24, width: 0.5)),
      ),
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.only(
              bottom: kDefaultPadding * 0.5), // Small bottom padding
          child: Text(
            'SOA Midterm by REAL MEN', // Your footer text
            style: footerTextStyle,
          ),
        ),
      ),
    );
  }

  Widget _buildExclamationOverlay(bool smallScreen) {
    // (Keep existing implementation)
    if (!_showExclamationMark) return const SizedBox.shrink();
    double rightEdge =
        smallScreen ? kDefaultPadding : kRailWidth + kDefaultPadding;
    const String exclamationAssetPath =
        'assets/exclamation_mark.png'; // Make sure this asset exists

    return Positioned(
      right: rightEdge -
          kExclamationMarkSize / 2, // Center horizontally relative to edge
      top: MediaQuery.of(context).size.height / 2 -
          kExclamationMarkSize / 2, // Center vertically
      child: Transform.rotate(
        angle: _exclamationMarkAngle, // Apply rotation animation
        child: IgnorePointer(
          // Prevent interaction with the overlay
          child: Image.asset(
            exclamationAssetPath,
            width: kExclamationMarkSize,
            height: kExclamationMarkSize,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.warning_amber_rounded,
                color: Colors.yellowAccent,
                size: kExclamationMarkSize), // Fallback icon
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryButtonGrid(ThemeData theme, bool isDrawer) {
    // (Keep existing implementation)
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: kMenuCategoryButtonCrossAxisCount, // 2 columns
        crossAxisSpacing: kDefaultPadding,
        mainAxisSpacing: kDefaultPadding,
        childAspectRatio:
            kMenuCategoryButtonAspectRatio, // Adjust for button shape
      ),
      itemCount: _categories.length,
      shrinkWrap: true, // Important for embedding in ListView/Column
      physics:
          const NeverScrollableScrollPhysics(), // Grid itself shouldn't scroll
      itemBuilder: (context, index) {
        final categoryViewIndex =
            index + 1; // 1-based index for selection state
        final isSelected = selectedIndex == categoryViewIndex;
        final categoryName = _categories[index];

        // Styling variables for clarity
        final selectedBgColor = theme.colorScheme.secondary.withOpacity(0.9);
        final unselectedBgColor =
            theme.cardTheme.color?.withOpacity(0.8) ?? const Color(0xFF455A64);
        final selectedBorderColor = theme.colorScheme.secondary;
        final hoverColor = theme.colorScheme.secondary.withOpacity(0.15);
        final splashColor = theme.colorScheme.secondary
            .withOpacity(0.25); // Although NoSplash is used below
        final shadowColor = Colors.black.withOpacity(isSelected ? 0.3 : 0.15);
        const animationDuration = Duration(milliseconds: 250);

        // Use AnimatedContainer for smooth transition effects
        return AnimatedContainer(
          duration: animationDuration,
          curve: Curves.easeInOutCubic,
          margin: EdgeInsets.all(
              isSelected ? 0 : 2.0), // Slightly inset unselected buttons
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
            // Using ElevatedButton for built-in styling and interaction
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith<Color>(
                  (Set<MaterialState> states) {
                if (states.contains(MaterialState.pressed))
                  return splashColor
                      .withOpacity(0.4); // Darken further on press
                return isSelected
                    ? selectedBgColor
                    : unselectedBgColor; // Selected/unselected color
              }),
              foregroundColor:
                  MaterialStateProperty.all<Color>(Colors.white), // Text color
              overlayColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) {
                if (states.contains(MaterialState.hovered))
                  return hoverColor; // Hover overlay
                return null; // Defer to default overlay color otherwise
              }),
              shadowColor: MaterialStateProperty.all(
                  Colors.transparent), // Shadow handled by AnimatedContainer
              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      side: BorderSide(
                          color: isSelected
                              ? selectedBorderColor
                              : Colors.transparent, // Border only when selected
                          width: 1.5))),
              padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                  const EdgeInsets.symmetric(
                      horizontal: kDefaultPadding,
                      vertical: kDefaultPadding * 0.75) // Button padding
                  ),
              minimumSize: MaterialStateProperty.all(
                  const Size(0, 40)), // Ensure minimum height
              splashFactory: NoSplash
                  .splashFactory, // Optional: Disable default splash if using custom effects
              elevation: MaterialStateProperty.all(
                  0), // Elevation handled by AnimatedContainer
            ),
            onPressed: () {
              _clearSearch(); // Clear search when selecting a category button
              _scrollToCategory(categoryViewIndex);
              if (isDrawer)
                Navigator.pop(
                    context); // Close drawer if action originated from there
            },
            child: AnimatedDefaultTextStyle(
              // Animate text style changes
              duration: animationDuration,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.w500, // Bold when selected
                  letterSpacing:
                      isSelected ? 0.4 : 0.2, // Adjust letter spacing
                  fontFamily: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.fontFamily // Use theme font
                  ),
              child: Text(
                categoryName,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis, // Handle long category names
                maxLines: 2, // Allow wrapping slightly
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentView(ThemeData theme) {
    // (Keep existing implementation)
    // Determine which main view to show based on selectedIndex
    int stackIndex = 0; // Default to Table Grid (index 0)
    if (selectedIndex == orderScreenIndex) {
      stackIndex = 1; // Kitchen Order List (index 1)
    } else if (selectedIndex >= 1 && selectedIndex <= _categories.length) {
      stackIndex = 2; // Menu Category List (index 2)
    }

    // List of possible pages for the IndexedStack
    List<Widget> pages = [
      // --- Page 0: Table Grid ---
      _buildTableGrid(theme),

      // --- Page 1: Kitchen Order List ---
      KitchenOrderListScreen(
        key: _kitchenListKey, // Use the GlobalKey
        onOrderUpdate: _updateTableOrderCounts, // Pass callback
        onTableCleared: _handleTableCleared, // Pass callback
      ),

      // --- Page 2: Menu Category List (conditionally built) ---
      Builder(builder: (context) {
        // Use Builder to access context if needed later
        // Check if the current state corresponds to showing a menu category
        bool isMenuView =
            selectedIndex >= 1 && selectedIndex <= _categories.length;

        if (isMenuView) {
          // Handle loading/error states specifically for the menu content
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
                      onPressed: _fetchMenuData, // Retry button
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    )
                  ]),
            ));
          }
          // Handle case where menu loaded but has no categories
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
                            backgroundColor:
                                theme.colorScheme.secondary.withOpacity(0.8)),
                        onPressed: _fetchMenuData, // Retry button
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tải lại Menu'))
                  ],
                ),
              ),
            );
          }
          // If menu is ready and has categories, build the selected category list
          if (stackIndex == 2) return _buildSelectedMenuCategoryList(theme);
        }
        // Fallback: Return an empty container if not showing menu (shouldn't happen with current logic)
        return Container();
      }),
    ];

    // Use IndexedStack to efficiently switch between views without rebuilding them
    return IndexedStack(
      index: stackIndex,
      children: pages,
    );
  }
} // End of _MenuScreenState

// --- Availability Switch Widget ---
// (AvailabilitySwitch remains unchanged - Keep the existing AvailabilitySwitch class here)
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
  late bool _optimisticValue; // Display this while API call is in progress

  @override
  void initState() {
    super.initState();
    _optimisticValue = widget.item.available;
  }

  // Update optimistic value if the actual item prop changes from outside
  // (e.g., fetched data refresh) and it differs from the current optimistic state,
  // but only if we are not already in the middle of an update initiated by this switch.
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
    bool displayValue = _optimisticValue; // Show optimistic value

    // Determine color and text based on optimistic state and loading status
    Color statusColor = _isUpdating
        ? (Colors.grey[500] ?? Colors.grey)
        : (displayValue
            ? (Colors.greenAccent[100] ??
                Colors.greenAccent) // Lighter accent for text
            : (Colors.redAccent[100] ?? Colors.redAccent));
    String statusText = _isUpdating ? '...' : (displayValue ? 'Có sẵn' : 'Hết');

    return Column(
      // Column for Switch and Text
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          // Constrain size for the switch/indicator area
          height: 35, // Adjust height as needed
          width: 55, // Adjust width as needed
          child: Center(
            child: _isUpdating
                ? SizedBox(
                    // Show loading indicator
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.secondary)),
                  )
                : Switch(
                    // Actual Switch widget
                    value: displayValue, // Use optimistic value
                    onChanged: (newValue) async {
                      // Optimistically update UI immediately
                      setState(() {
                        _optimisticValue = newValue;
                        _isUpdating = true;
                      });

                      // Call the API function passed from the parent
                      bool success =
                          await widget.onStatusChanged(widget.item, newValue);

                      // After API call completes, update UI based on success/failure
                      if (mounted) {
                        // Check if widget is still in the tree
                        setState(() {
                          if (!success) {
                            // If API failed, revert the optimistic update
                            _optimisticValue = !newValue;
                            print(
                                "API update failed, reverting switch for ${widget.item.name}");
                          } else {
                            // If API succeeded, the parent widget's state update
                            // should eventually reflect the change in widget.item.available.
                            // No need to change _optimisticValue back here.
                            print(
                                "API update succeeded for ${widget.item.name}");
                          }
                          _isUpdating = false; // Stop loading indicator
                        });
                      } else {
                        print(
                            "Switch widget unmounted after API call for ${widget.item.name}");
                      }
                    },
                    // Styling from theme
                    materialTapTargetSize: MaterialTapTargetSize
                        .shrinkWrap, // Reduce tap target size
                    activeColor: switchTheme.thumbColor
                        ?.resolve({MaterialState.selected}),
                    inactiveThumbColor: switchTheme.thumbColor?.resolve({}),
                    activeTrackColor: switchTheme.trackColor
                        ?.resolve({MaterialState.selected}),
                    inactiveTrackColor: switchTheme.trackColor?.resolve({}),
                  ),
          ),
        ),
        const SizedBox(height: 4), // Space between switch and text
        Text(
          // Status text below the switch
          statusText,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10.5, // Small font size for status text
            color: statusColor,
            fontWeight:
                FontWeight.w500, // Slightly bolder than default bodySmall
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

// --- Optimized Kitchen Order List Screen ---
class KitchenOrderListScreen extends StatefulWidget {
  final OrderUpdateCallback? onOrderUpdate; // Callback to MenuScreen
  final TableClearedCallback? onTableCleared; // Callback to MenuScreen

  const KitchenOrderListScreen({
    Key? key,
    this.onOrderUpdate,
    this.onTableCleared,
  }) : super(key: key);

  @override
  State<KitchenOrderListScreen> createState() => _KitchenOrderListScreenState();
}

class _KitchenOrderListScreenState extends State<KitchenOrderListScreen>
    with AutomaticKeepAliveClientMixin {
  // Use ValueNotifier for efficient updates of the pending list
  final ValueNotifier<List<KitchenListOrder>> _pendingOrdersNotifier =
      ValueNotifier([]);
  List<KitchenListOrder> get _pendingOrders => _pendingOrdersNotifier.value;
  // Setter ensures the notifier is updated when the list changes
  set _pendingOrders(List<KitchenListOrder> newList) {
    _pendingOrdersNotifier.value = newList;
  }

  List<KitchenListOrder> _completedOrders =
      []; // Standard list for completed orders

  // Loading and error states
  bool _isLoadingPending = true;
  String? _pendingErrorMessage;
  bool _isLoadingCompleted = false;
  String? _completedErrorMessage;
  bool _completedOrdersLoaded = false; // Track if completed loaded once

  OrderListView _currentView = OrderListView.pending; // Current tab

  // State for order details and updates
  final Set<int> _inProgressOrderIds = {}; // Orders being actively worked on
  bool _isDetailLoading = false;
  String? _detailErrorMessage;
  List<KitchenOrderDetailItem> _detailItems = [];
  final Set<int> _updatingItemIds =
      {}; // Items currently updating status in popup
  bool _isCompletingAll = false; // "Complete All" action in progress

  // Table number fetching cache and state
  // Cache stores sessionId -> tableNumber (null=not fetched, -1=error/not found, >0=valid)
  final Map<int, int?> _tableNumberCache = {};
  // Tracks sessionIds currently being fetched to prevent duplicates
  final Set<int> _fetchingTableSessionIds = {};

  // WebSocket state (unchanged)
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 10;
  final Duration _initialReconnectDelay = const Duration(seconds: 3);
  final Duration _maxReconnectDelay = const Duration(minutes: 1);

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  @override
  void initState() {
    super.initState();
    print("KitchenOrderListScreen initState");
    _fetchPendingOrders(); // Initial fetch
    _connectWebSocket();
  }

  @override
  void dispose() {
    print("KitchenOrderListScreen dispose");
    _disconnectWebSocket();
    _reconnectTimer?.cancel();
    _pendingOrdersNotifier.dispose(); // Dispose ValueNotifier
    super.dispose();
  }

  // --- WebSocket Methods ---
  // (Keep existing _connectWebSocket, _disconnectWebSocket, _scheduleReconnect, _handleWebSocketMessage)
  // These methods remain unchanged from the previous version.
  void _connectWebSocket() {
    if (_isConnecting || _isConnected || _channel != null) return;
    if (!mounted) return;
    setState(() {
      _isConnecting = true;
    });
    print("WebSocket: Attempting to connect to $kWebSocketUrl...");
    try {
      _channel = WebSocketChannel.connect(Uri.parse(kWebSocketUrl));
      _isConnected = false; // Set connected only on successful listen setup
      if (!mounted) {
        // Check mount immediately after sync connect call
        _channel?.sink.close(status.goingAway);
        _channel = null;
        _isConnecting = false;
        return;
      }
      print("WebSocket: Connection established, listening for messages...");
      setState(() {
        _isConnected = true; // Now connected
        _isConnecting = false;
        _reconnectAttempts = 0; // Reset attempts on success
      });
      _reconnectTimer?.cancel(); // Cancel any pending reconnect timer

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
          _scheduleReconnect(); // Attempt to reconnect on error
        },
        onDone: () {
          if (!mounted) return;
          print(
              "WebSocket: Connection closed (onDone). Code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason}");
          setState(() {
            _isConnected = false;
            _isConnecting = false;
          });
          // Reconnect only if closure was unexpected
          if (_channel?.closeCode != status.goingAway &&
              _channel?.closeCode != status.normalClosure) {
            _scheduleReconnect();
          } else {
            _channel = null; // Clean up channel if closed normally
          }
        },
        cancelOnError: false, // Keep listening even after an error
      );
    } catch (e) {
      if (!mounted) return;
      print("WebSocket: Connection failed: $e");
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
      _channel = null;
      _scheduleReconnect(); // Attempt to reconnect on initial connection failure
    }
  }

  void _disconnectWebSocket() {
    print("WebSocket: Disconnecting...");
    _reconnectTimer?.cancel();
    _channel?.sink.close(status.goingAway); // Indicate intentional closure
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    // Do not reset reconnect attempts here, allow manual reconnect if needed
  }

  void _scheduleReconnect() {
    if (!mounted || _reconnectTimer?.isActive == true || _isConnecting)
      return; // Don't schedule if already trying/connected
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print("WebSocket: Max reconnect attempts reached.");
      _reconnectAttempts = 0; // Reset for potential future manual attempts
      return;
    }
    _reconnectAttempts++;
    // Exponential backoff with jitter could be added, simple exponential for now
    final delay =
        _initialReconnectDelay * math.pow(1.5, _reconnectAttempts - 1);
    final clampedDelay = delay > _maxReconnectDelay
        ? _maxReconnectDelay
        : delay; // Cap the delay

    print(
        "WebSocket: Scheduling reconnect attempt #$_reconnectAttempts in ${clampedDelay.inSeconds} seconds...");
    _reconnectTimer = Timer(clampedDelay, () {
      if (mounted) {
        _connectWebSocket(); // Attempt connection after delay
      }
    });
  }

  void _handleWebSocketMessage(dynamic message) {
    // Basic handling: Assume any message means potential update, refresh pending orders
    print("WebSocket: Handling message - Triggering pending order refresh.");
    // Optional: Decode message if it contains specific instructions
    dynamic decodedMessage;
    if (message is String) {
      try {
        decodedMessage = jsonDecode(message);
        print("WebSocket: Decoded message: $decodedMessage");
        // TODO: Implement more specific logic based on message content if needed
        // e.g., if message says orderId X updated, only refresh details for X?
      } catch (e) {
        print("WebSocket: Message is not valid JSON: $message");
      }
    } else {
      print(
          "WebSocket: Received non-string message type: ${message.runtimeType}");
    }

    if (mounted) {
      // Force refresh might be slightly less efficient but ensures consistency
      // if the WebSocket message doesn't specify what changed.
      _fetchPendingOrders(forceRefresh: true);
    }
  }

  // --- OPTIMIZED Data Fetching Methods ---

  // Fetches pending orders ('ordered' and 'in_progress') and their table numbers.
  Future<void> _fetchPendingOrders({bool forceRefresh = false}) async {
    if (_isLoadingPending && !forceRefresh) return;
    if (!mounted) return;

    // Clear caches if forcing refresh (only for previously pending orders)
    if (forceRefresh) {
      print("Kitchen: Force refreshing pending orders.");
      final pendingSessionIds = _pendingOrders.map((o) => o.sessionId).toSet();
      _tableNumberCache
          .removeWhere((sessionId, _) => pendingSessionIds.contains(sessionId));
      _fetchingTableSessionIds
          .removeWhere((sessionId) => pendingSessionIds.contains(sessionId));
    }

    // Set loading state - only one setState call here for the start
    setState(() {
      _isLoadingPending = true;
      _pendingErrorMessage = null;
      if (forceRefresh) _inProgressOrderIds.clear();
    });

    List<KitchenListOrder> finalOrders = [];
    String? errorMsg;
    Map<int, int> countsByTable = {};

    try {
      // 1. Fetch 'ordered' and 'in_progress' concurrently
      final results = await Future.wait([
        _fetchOrdersWithStatus('ordered'),
        _fetchOrdersWithStatus('in_progress'),
      ], eagerError: true); // Throw error immediately if one fails

      if (!mounted) return; // Check mount after awaits

      final orderedOrders = results[0];
      final inProgressOrders = results[1];

      // 2. Combine, deduplicate, and sort
      List<KitchenListOrder> combinedPendingOrders = [
        ...orderedOrders,
        ...inProgressOrders
      ];
      final uniquePendingOrdersMap = <int, KitchenListOrder>{
        for (var order in combinedPendingOrders) order.orderId: order
      };
      final sortedOrders = uniquePendingOrdersMap.values.toList()
        ..sort((a, b) => a.orderTime.compareTo(b.orderTime)); // Oldest first

      // 3. Fetch table numbers for the combined list (essential step before final state update)
      // This now populates the cache or uses existing cached values.
      final ordersWithTableNumbers =
          await _fetchTableNumbersForOrders(sortedOrders);
      finalOrders = ordersWithTableNumbers;

      if (!mounted) return; // Check mount again

      // 4. Calculate counts *after* table numbers are fetched/resolved
      countsByTable.clear();
      for (var order in finalOrders) {
        // Use valid, non-error table numbers for counting
        if (order.tableNumber != null &&
            order.tableNumber! > 0 &&
            order.tableNumber! != -1) {
          countsByTable[order.tableNumber!] =
              (countsByTable[order.tableNumber!] ?? 0) + 1;
        }
      }

      // 5. Notify parent screen (MenuScreen)
      try {
        widget.onOrderUpdate?.call(countsByTable);
      } catch (e) {
        print("Kitchen: Error calling onOrderUpdate callback: $e");
      }

      // 6. Update the local set of 'in_progress' orders
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
      // Notify parent with empty counts on error
      if (mounted) {
        try {
          widget.onOrderUpdate?.call({});
        } catch (e) {
          print(
              "Kitchen: Error calling onOrderUpdate callback during error handling: $e");
        }
      }
    } finally {
      // 7. Final State Update: Update the list (ValueNotifier) and loading/error state
      // Only one setState call here for the entire pending order fetch process.
      if (mounted) {
        setState(() {
          _pendingOrders = finalOrders; // Update ValueNotifier via setter
          _pendingErrorMessage = errorMsg;
          _isLoadingPending = false;
        });
        print(
            "Kitchen: Finished fetching pending orders. Count: ${finalOrders.length}. Pending Counts: $countsByTable");
      }
    }
  }

  // Fetches completed orders ('served') and their table numbers.
  Future<void> _fetchCompletedOrders({bool forceRefresh = false}) async {
    if (_isLoadingCompleted && !forceRefresh) return;
    if (!mounted) return;

    // Clear relevant caches if forcing refresh
    if (forceRefresh) {
      // (Similar cache clearing as in _fetchPendingOrders)
      print("Kitchen: Force refreshing completed orders.");
      final completedSessionIds =
          _completedOrders.map((o) => o.sessionId).toSet();
      _tableNumberCache.removeWhere(
          (sessionId, _) => completedSessionIds.contains(sessionId));
      _fetchingTableSessionIds
          .removeWhere((sessionId) => completedSessionIds.contains(sessionId));
    }

    // Set loading state
    setState(() {
      _isLoadingCompleted = true;
      _completedErrorMessage = null;
    });

    List<KitchenListOrder> finalOrders = [];
    String? errorMsg;

    try {
      // 1. Fetch 'served' orders
      final servedOrders = await _fetchOrdersWithStatus('served');
      if (!mounted) return;

      // 2. Fetch table numbers (might use cache)
      final ordersWithTableNumbers =
          await _fetchTableNumbersForOrders(servedOrders);
      if (!mounted) return;

      // 3. Sort (newest first for completed)
      ordersWithTableNumbers.sort((a, b) => b.orderTime.compareTo(a.orderTime));
      finalOrders = ordersWithTableNumbers;
      _completedOrdersLoaded = true; // Mark as loaded
    } catch (e) {
      errorMsg = "Lỗi tải đơn đã hoàn thành: ${e.toString()}";
      print("Kitchen: Error fetching COMPLETED orders: $e");
    } finally {
      // 4. Final State Update
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

  // Fetches orders for a specific status (unchanged)
  Future<List<KitchenListOrder>> _fetchOrdersWithStatus(String status) async {
    // (Keep existing implementation)
    final baseUrl =
        'https://soa-deploy.up.railway.app/kitchen/get-orders-by-status/';
    final url = Uri.parse('$baseUrl$status');
    print("Kitchen API: Fetching orders with status '$status': $url");
    try {
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 15)); // 15s timeout
      if (!mounted) return []; // Check mount after await
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
        } catch (_) {} // Try decode body
        print(
            "Kitchen API: Error fetching orders with status '$status': ${response.statusCode}, Body: $errorBody");
        throw Exception(
            'Failed to load orders (status $status): ${response.statusCode}');
      }
    } catch (e) {
      // Handle timeout or network errors
      print(
          "Kitchen API: Network/Timeout Error fetching orders with status '$status': $e");
      throw Exception('Network error fetching orders (status $status)');
    }
  }

  // Fetches table number for a single session ID, using cache.
  // OPTIMIZED: Removed setState from here.
  Future<int?> _fetchTableNumber(int sessionId) async {
    // 1. Check cache first
    if (_tableNumberCache.containsKey(sessionId)) {
      final cachedValue = _tableNumberCache[sessionId];
      // print("Cache hit for session $sessionId: $cachedValue");
      return cachedValue == -1 ? null : cachedValue;
    }

    // 2. Check if already fetching this specific session ID
    if (_fetchingTableSessionIds.contains(sessionId)) {
      // print("Already fetching table number for session $sessionId");
      return null; // Indicate loading (will be picked up on next refresh)
    }

    // 3. Check mount before network call
    if (!mounted) return null;

    // 4. Mark as fetching (without setState)
    _fetchingTableSessionIds.add(sessionId);
    // print("Fetching table number for session $sessionId...");

    final url = Uri.parse(
        'https://soa-deploy.up.railway.app/order/session/$sessionId/table-number');
    int? resultTableNumber;
    int cacheValue = -1; // Default to error/not found state for cache

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      // Check mount again after await
      if (!mounted) {
        _fetchingTableSessionIds.remove(sessionId); // Clean up fetching state
        return null;
      }

      if (response.statusCode == 200) {
        // (Keep existing JSON parsing and validation logic)
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
          cacheValue = resultTableNumber; // Cache the valid number
        } else {
          print(
              "Warning: Could not parse a valid table number for session $sessionId from data: $tableNumberData");
          resultTableNumber = null;
          cacheValue = -1; // Cache -1 for invalid/not found
        }
      } else {
        print(
            "Error fetching table number for session $sessionId: ${response.statusCode}, Body: ${response.body}");
        resultTableNumber = null;
        cacheValue = -1; // Cache error state
      }
    } catch (e) {
      print("Exception fetching table number for session $sessionId: $e");
      resultTableNumber = null;
      cacheValue = -1; // Cache error state
      if (!mounted) {
        // Check mount in catch block
        _fetchingTableSessionIds.remove(sessionId);
        return null;
      }
    } finally {
      // 5. IMPORTANT: Update cache and remove from fetching set *without* setState.
      // The calling function (_fetchTableNumbersForOrders) will handle the UI update
      // after all necessary fetches are done.
      _tableNumberCache[sessionId] = cacheValue;
      _fetchingTableSessionIds.remove(sessionId);
      // print("Finished fetching/caching for session $sessionId. Result: $resultTableNumber, Cached: $cacheValue");
    }
    return resultTableNumber; // Return the fetched/parsed number (or null on error)
  }

  // Fetches table numbers for a list of orders, utilizing the cache and concurrent fetches.
  Future<List<KitchenListOrder>> _fetchTableNumbersForOrders(
      List<KitchenListOrder> orders) async {
    if (orders.isEmpty) return orders; // No need to fetch if list is empty

    final List<Future<void>> fetchFutures = [];
    final Set<int> sessionIdsToFetch = {};

    // Identify which session IDs *actually* need fetching
    for (var order in orders) {
      if (!_tableNumberCache.containsKey(order.sessionId) &&
          !_fetchingTableSessionIds.contains(order.sessionId)) {
        sessionIdsToFetch.add(order.sessionId);
      }
    }

    // Create and start fetch futures only for those needed
    if (sessionIdsToFetch.isNotEmpty) {
      print("Need to fetch table numbers for sessions: $sessionIdsToFetch");
      for (int sessionId in sessionIdsToFetch) {
        fetchFutures.add(_fetchTableNumber(
            sessionId)); // Add the future, don't await individually
      }
      // Await all necessary fetches concurrently
      try {
        await Future.wait(fetchFutures);
        print("Finished Future.wait for table numbers.");
      } catch (e) {
        print(
            "Error occurred during Future.wait for table numbers (individual errors logged in _fetchTableNumber): $e");
      }
    } else {
      // print("All required table numbers were cached or are already fetching.");
    }

    // After fetches complete (or if all were cached), update the order objects
    // This assumes _fetchTableNumber has updated the cache correctly.
    if (!mounted) return orders; // Check mount again after awaits

    // Create a new list with updated table numbers from the cache
    List<KitchenListOrder> updatedOrders = orders.map((order) {
      final cachedTableNum = _tableNumberCache[order.sessionId];
      // Update the order's tableNumber property if it's not already set correctly
      // The cache should now contain either a valid number, -1 (error), or still be null if the fetch is somehow ongoing (unlikely here)
      if (order.tableNumber != cachedTableNum) {
        order.tableNumber = cachedTableNum;
      }
      return order;
    }).toList();

    return updatedOrders;
  }

  // Fetches details for a specific order (unchanged)
  Future<void> _fetchOrderDetail(
      int orderId, StateSetter setDialogState) async {
    // (Keep existing implementation - was already reasonably optimized with timeout)
    if (!mounted) return;
    bool isDialogMounted = true;
    try {
      (context as Element).widget;
    } catch (e) {
      isDialogMounted = false;
    }
    if (!isDialogMounted) {
      print(
          "Order detail fetch cancelled: Dialog is no longer mounted for Order $orderId.");
      return;
    }

    try {
      setDialogState(() {
        /* ... set loading ... */ _isDetailLoading = true;
        _detailErrorMessage = null;
        _detailItems = [];
        _updatingItemIds.clear();
        _isCompletingAll = false;
      });
    } catch (e) {
      print("Error setting dialog state for loading (Order $orderId): $e");
      _isDetailLoading = false;
      _detailItems = [];
      return;
    }

    final url = Uri.parse(
        'https://soa-deploy.up.railway.app/kitchen/order/$orderId/items');
    print('Fetching order detail: ${url.toString()}');

    try {
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 8)); // Keep 8s timeout

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
          _detailItems = fetchedItems;
          _isDetailLoading = false;
        }
      } else {
        print(
            "Error fetching order detail for $orderId: ${response.statusCode}");
        final errorBody = utf8.decode(response.bodyBytes);
        String serverErrorMsg = '';
        try {
          final decodedError = jsonDecode(errorBody);
          if (decodedError is Map && decodedError.containsKey('detail')) {
            serverErrorMsg = ': ${decodedError['detail']}';
          }
        } catch (_) {}
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
    } on TimeoutException catch (e) {
      print("Timeout Error fetching order detail for order $orderId: $e");
      if (!mounted) return;
      isDialogMounted = true;
      try {
        (context as Element).widget;
      } catch (e) {
        isDialogMounted = false;
      }
      if (!isDialogMounted) return;
      try {
        setDialogState(() {
          _detailErrorMessage =
              'Yêu cầu quá thời gian quy định (8 giây). Vui lòng thử lại.';
          _isDetailLoading = false;
        });
      } catch (se) {
        print(
            "Error setting dialog state with timeout error (Order $orderId): $se");
        _detailErrorMessage =
            'Yêu cầu quá thời gian quy định (8 giây). Vui lòng thử lại.';
        _isDetailLoading = false;
      }
    } catch (e) {
      print("Network/Other Error fetching order detail for order $orderId: $e");
      if (!mounted) return;
      isDialogMounted = true;
      try {
        (context as Element).widget;
      } catch (e) {
        isDialogMounted = false;
      }
      if (!isDialogMounted) return;
      try {
        setDialogState(() {
          _detailErrorMessage =
              'Lỗi kết nối hoặc xử lý dữ liệu. Vui lòng thử lại.';
          _isDetailLoading = false;
        });
      } catch (se) {
        print(
            "Error setting dialog state with catch error (Order $orderId): $se");
        _detailErrorMessage =
            'Lỗi kết nối hoặc xử lý dữ liệu. Vui lòng thử lại.';
        _isDetailLoading = false;
      }
    }
  }

  // --- Popup & Order Management Methods ---

  // Shows the order detail popup (unchanged)
  void _showOrderDetailPopup(BuildContext context, KitchenListOrder order) {
    // (Keep existing implementation)
    final theme = Theme.of(context);
    // Reset local popup state before showing
    _isDetailLoading = false;
    _detailErrorMessage = null;
    _detailItems = [];
    _updatingItemIds.clear();
    _isCompletingAll = false;

    showDialog<void>(
        context: context, // Use the BuildContext from where this was called
        barrierDismissible:
            !_isCompletingAll, // Prevent dismissal during critical operations
        builder: (BuildContext dialogContext) {
          // dialogContext is specific to this dialog
          return StatefulBuilder(
              // Use StatefulBuilder to manage dialog's internal state
              builder: (context, setDialogState) {
            // 'context' here is the same as dialogContext

            // Fetch details only once when the dialog builds, if needed
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Check if dialog is still current and details haven't been loaded/are not loading
              bool shouldFetch = mounted &&
                  (ModalRoute.of(dialogContext)?.isCurrent ?? false) &&
                  _detailItems.isEmpty &&
                  !_isDetailLoading &&
                  _detailErrorMessage == null;
              if (shouldFetch) {
                _fetchOrderDetail(order.orderId, setDialogState);
              }
            });

            // Determine if the "Complete All" button should be enabled
            bool canCompleteAll = _detailItems
                    .any((item) => item.status.toLowerCase() != 'served') &&
                !_isDetailLoading &&
                !_isCompletingAll &&
                _updatingItemIds.isEmpty;

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(
                  16.0, 16.0, 8.0, 10.0), // Custom padding
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                      // Allow title to shrink
                      child: Text(
                    'Chi tiết Đơn #${order.orderId}',
                    style: theme.dialogTheme.titleTextStyle,
                    overflow: TextOverflow.ellipsis,
                  )),
                  // Action Icons Row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isCompletingAll) // Show spinner when completing all
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.lightBlueAccent)),
                        )
                      else // Show Complete All button
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
                      // Refresh Button
                      IconButton(
                        icon: Icon(Icons.refresh,
                            color: theme.colorScheme.secondary.withOpacity(0.8),
                            size: 22),
                        tooltip: 'Tải lại chi tiết đơn',
                        // Disable refresh if already loading/updating
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
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 8.0), // Adjust content padding
              content: _buildPopupContent(
                  theme,
                  setDialogState,
                  order,
                  _isCompletingAll,
                  dialogContext), // Build the main content area
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              actions: [
                TextButton(
                  onPressed: _updatingItemIds.isNotEmpty || _isCompletingAll
                      ? null
                      : () => Navigator.of(dialogContext)
                          .pop(), // Disable close if updating
                  child: Text('Đóng',
                      style: TextStyle(
                          color: _updatingItemIds.isNotEmpty || _isCompletingAll
                              ? Colors.grey
                              : theme.colorScheme.secondary)),
                ),
              ],
              backgroundColor:
                  theme.dialogTheme.backgroundColor, // Consistent background
              shape: theme.dialogTheme.shape, // Consistent shape
            );
          });
        }).then((_) {
      // This runs when the dialog is closed (popped)
      // Reset any state specific to the *last shown* popup to avoid carry-over
      _updatingItemIds.clear();
      _detailItems = [];
      _isDetailLoading = false;
      _detailErrorMessage = null;
      _isCompletingAll = false;
      print(
          "Order detail dialog closed for #${order.orderId}. Local popup state reset.");
    });
  }

  // Shows pending orders for a specific table, uses ValueListenableBuilder for efficiency (unchanged)
  void showOrdersForTable(BuildContext parentContext, int tableNumber) {
    // (Keep existing implementation using ValueListenableBuilder)
    final theme = Theme.of(parentContext);
    print("Showing popup for table $tableNumber.");

    // Use ValueListenableBuilder to automatically rebuild the dialog content
    // when the _pendingOrdersNotifier changes.
    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return ValueListenableBuilder<List<KitchenListOrder>>(
          valueListenable: _pendingOrdersNotifier,
          builder: (context, currentPendingOrders, child) {
            // Filter orders for the specific table from the latest notifier value
            final ordersForTable = currentPendingOrders
                .where((order) => order.tableNumber == tableNumber)
                .toList();
            ordersForTable.sort(
                (a, b) => a.orderTime.compareTo(b.orderTime)); // Oldest first

            // If no more orders for this table, close the dialog automatically
            if (ordersForTable.isEmpty && Navigator.canPop(dialogContext)) {
              print(
                  "Table $tableNumber list popup: No more pending orders found (detected by listener). Closing.");
              // Schedule the pop after the current build frame
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(dialogContext)) {
                  // Double check if still can pop
                  Navigator.of(dialogContext).pop();
                }
              });
              // Return an empty container temporarily while closing
              return const SizedBox.shrink();
            }

            // Build the dialog UI
            return AlertDialog(
              title: Text('Đơn hàng Bàn $tableNumber (Đang chờ)'),
              content: Container(
                width: double.maxFinite, // Use available width
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(dialogContext).size.height *
                        0.5), // Limit height
                child: ordersForTable.isEmpty
                    ? Center(
                        // Should technically not be reached due to auto-close logic above
                        child: Padding(
                          padding: const EdgeInsets.all(kDefaultPadding),
                          child: Text(
                            'Không còn đơn hàng nào đang chờ.', /* ... style ... */
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
                                // Close this list popup *before* showing the detail popup
                                // Might feel smoother than having two popups potentially overlap
                                // Navigator.of(dialogContext).pop(); // Optional: close this one first
                                _showOrderDetailPopup(parentContext,
                                    order); // Show detail using parent context
                              },
                              dense: true,
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton.icon(
                  // Add a manual refresh button inside this popup too
                  icon: Icon(Icons.refresh,
                      size: 16,
                      color: theme.colorScheme.secondary.withOpacity(0.8)),
                  label: Text('Làm mới DS',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.secondary.withOpacity(0.8))),
                  onPressed: () {
                    _fetchPendingOrders(forceRefresh: true);
                  }, // Trigger a full refresh
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
      },
    ); // Don't need .then() cleanup as ValueListenableBuilder handles listener removal
  }

  // Builds the content of the order detail popup (unchanged)
  Widget _buildPopupContent(
      ThemeData theme,
      StateSetter setDialogState,
      KitchenListOrder order,
      bool isCompletingAll,
      BuildContext dialogContext) {
    // (Keep existing implementation)
    if (_isDetailLoading) {
      return Container(
          height: 150, // Fixed height for loading indicator consistency
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
    // --- Error State ---
    if (_detailErrorMessage != null) {
      return Container(
          padding: const EdgeInsets.all(kDefaultPadding * 2),
          alignment: Alignment.center,
          child: Column(
              mainAxisSize: MainAxisSize.min, // Take minimum height needed
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orangeAccent, size: 40),
                const SizedBox(height: 10),
                Text(_detailErrorMessage!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white70)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                    onPressed: () => _fetchOrderDetail(
                        order.orderId, setDialogState), // Retry button
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent[700]))
              ]));
    }
    // --- Empty State ---
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
    // --- Success State: Build the List ---
    return Container(
        width: double.maxFinite, // Use max width available in dialog
        constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height * 0.6), // Limit max height
        child: ListView.builder(
            shrinkWrap:
                true, // Make ListView height fit content (up to constraints)
            padding: const EdgeInsets.symmetric(
                horizontal: kDefaultPadding * 0.5), // Padding around the list
            itemCount: _detailItems.length,
            itemBuilder: (context, index) {
              final item = _detailItems[index];
              final bool isServed = item.status.toLowerCase() == 'served';
              final bool isThisItemUpdating = _updatingItemIds.contains(
                  item.orderItemId); // Check if this specific item is loading

              // Slightly dim served items
              return Opacity(
                  opacity: isServed ? 0.65 : 1.0,
                  child: Card(
                      elevation: isServed ? 1 : 3, // Less elevation for served
                      margin: const EdgeInsets.symmetric(
                          vertical: kDefaultPadding * 0.7,
                          horizontal: kDefaultPadding / 2),
                      color: theme.cardTheme.color?.withAlpha(isServed
                          ? 200
                          : 255), // Slightly transparent if served
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: kDefaultPadding * 1.2,
                              vertical: kDefaultPadding),
                          child: Row(children: [
                            // Item Name and Status
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                    '${item.name} (SL: ${item.quantity})',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontSize: 14.5,
                                      color: isServed
                                          ? Colors.white.withOpacity(0.6)
                                          : Colors.white,
                                      decoration: isServed
                                          ? TextDecoration.lineThrough
                                          : null, // Strikethrough if served
                                      decorationColor: Colors.white54,
                                      decorationThickness: 1.5,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
                                  // Status Icon and Text
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
                            // Action Button / Indicator
                            SizedBox(
                                // Container to manage size of button/indicator
                                width:
                                    85, // Fixed width for button/indicator area
                                height: 30, // Fixed height
                                child: Center(
                                    child: isThisItemUpdating
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors
                                                    .lightBlueAccent)) // Loading indicator for this item
                                        : isServed
                                            ? Icon(Icons.check_circle,
                                                color: Colors.greenAccent
                                                    .withOpacity(0.9),
                                                size:
                                                    28) // Checkmark for served
                                            : ElevatedButton(
                                                // "Complete" button
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
                                                  disabledBackgroundColor: Colors
                                                      .grey[600]
                                                      ?.withOpacity(
                                                          0.5), // Style when disabled
                                                  disabledForegroundColor:
                                                      Colors.grey[400],
                                                ),
                                                // Disable button if completing all or this item is already updating
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

  // Updates a single item's status from the popup (unchanged)
  Future<void> _updatePopupOrderItemStatus(
      KitchenListOrder order,
      KitchenOrderDetailItem item,
      String newStatus,
      StateSetter setDialogState,
      BuildContext dialogContext) async {
    // (Keep existing implementation including checks, API call, state updates, and _callCompleteOrderApi logic)
    // Prevent concurrent updates and check mounts
    if (_updatingItemIds.contains(item.orderItemId) || !mounted) return;
    bool isDialogStillMounted = true;
    try {
      (dialogContext as Element).widget;
    } catch (e) {
      isDialogStillMounted = false;
    }
    if (!isDialogStillMounted) return;

    // --- Start Loading State for this item ---
    try {
      setDialogState(() => _updatingItemIds.add(item.orderItemId));
    } catch (e) {
      /* ... handle set state error ... */ return;
    }

    print(
        "Attempting PATCH item status: Item ${item.orderItemId} -> Status '$newStatus'");
    final url = Uri.parse(
            'https://soa-deploy.up.railway.app/kitchen/order-items/${item.orderItemId}/status')
        .replace(queryParameters: {'status': newStatus});
    final headers = {'Content-Type': 'application/json'};
    bool success = false;

    try {
      final response = await http
          .patch(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      // --- Check Mounts After Await ---
      if (!mounted) return;
      isDialogStillMounted = true; // Reset flag
      try {
        (dialogContext as Element).widget;
      } catch (e) {
        isDialogStillMounted = false;
      }

      // Handle edge case: Dialog closed while API was running
      if (!isDialogStillMounted &&
          (response.statusCode >= 200 && response.statusCode < 300)) {
        print(
            "Dialog closed after successful item update for ${item.orderItemId}. Triggering full refresh.");
        _fetchPendingOrders(
            forceRefresh: true); // Refresh main list to ensure consistency
        _updatingItemIds.remove(item.orderItemId); // Clean up local state
        return;
      }
      if (!isDialogStillMounted) {
        // If dialog closed and API failed/didn't run
        _updatingItemIds.remove(item.orderItemId);
        return;
      }

      // --- Process API Response ---
      if (response.statusCode == 200 || response.statusCode == 204) {
        print("API Success: Item ${item.orderItemId} updated to '$newStatus'.");
        success = true;

        // Update item status in the local dialog list (_detailItems)
        final index =
            _detailItems.indexWhere((i) => i.orderItemId == item.orderItemId);
        if (index != -1) {
          try {
            setDialogState(() => _detailItems[index].status = newStatus);
          } catch (e) {
            /* Fallback */ _detailItems[index].status = newStatus;
          }

          // --- Check if the ENTIRE order is now served ---
          bool allItemsInThisOrderServed =
              _detailItems.every((i) => i.status.toLowerCase() == 'served');

          if (allItemsInThisOrderServed) {
            // --- ORDER COMPLETE ---
            print(
                "Order ${order.orderId} fully served (last single item completed). Triggering final completion API call.");

            // Call the separate API to mark the whole order as complete
            bool completeOrderSuccess =
                await _callCompleteOrderApi(order.orderId);

            // Check mounts again after the second API call
            if (!mounted) return;
            isDialogStillMounted = true;
            try {
              (dialogContext as Element).widget;
            } catch (e) {
              isDialogStillMounted = false;
            }

            if (!completeOrderSuccess) {
              // If /complete API fails, show error, keep dialog open
              print(
                  "Error: Failed to call complete order API for ${order.orderId} after last item served.");
              String errorMsg =
                  'Lỗi khi xác nhận hoàn thành đơn hàng với server.';
              // Show error in dialog or main screen
              if (isDialogStillMounted)
                ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                    content: Text(errorMsg), backgroundColor: Colors.orange));
              else if (mounted)
                ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                    content: Text(errorMsg), backgroundColor: Colors.orange));

              // DO NOT close popup or remove order from pending list here
              // Reset the updating state for the *current* item only
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
              return; // Stop further processing
            }

            // --- UI Update for Order Complete (only if /complete API succeeded) ---
            if (mounted) {
              setState(() {
                // Update the main screen's state
                _pendingOrders = _pendingOrders
                    .where((o) => o.orderId != order.orderId)
                    .toList(); // Remove from pending (updates notifier)
                _inProgressOrderIds
                    .remove(order.orderId); // Remove from in-progress set
                // Add to completed list (client-side)
                if (!_completedOrders
                    .any((co) => co.orderId == order.orderId)) {
                  _completedOrders.insert(0, order);
                }
                _notifyTableStatusUpdate(
                    order.tableNumber); // Notify MenuScreen about table status
              });
              // Show confirmation SnackBar on main screen
              ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                content: Text('Đơn hàng #${order.orderId} đã hoàn thành!'),
                backgroundColor: Colors.green[700],
                duration: const Duration(seconds: 3),
              ));
            }
            // Close the detail popup
            if (isDialogStillMounted && Navigator.canPop(dialogContext)) {
              Navigator.of(dialogContext).pop();
            }
            // Optionally refresh completed list in background
            if (mounted) _fetchCompletedOrders();
          } else {
            // --- ORDER NOT YET COMPLETE ---
            // Mark order as in progress in the main list if it wasn't already
            if (!_inProgressOrderIds.contains(order.orderId)) {
              if (mounted) {
                setState(() {
                  print("Marking order ${order.orderId} as in progress.");
                  _inProgressOrderIds.add(order.orderId);
                });
              }
            }
            // Show snackbar for individual item completion
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
          // Item not found in local list - should not happen normally
          print(
              "Error: Item ${item.orderItemId} not found in local _detailItems after update.");
          if (isDialogStillMounted)
            _fetchOrderDetail(order.orderId, setDialogState); // Refresh details
        }
      } else {
        // --- Handle API Error (Non-200) ---
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
        // Show error SnackBar (dialog or main screen)
        if (isDialogStillMounted) {
          ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
              content: Text(errorMsg), backgroundColor: Colors.redAccent));
        } else if (mounted) {
          ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
              content: Text(errorMsg), backgroundColor: Colors.redAccent));
        }
      }
    } catch (e) {
      // Handle Network/Timeout/Other Errors
      if (!mounted) return; // Check mount after catch
      isDialogStillMounted = true;
      try {
        (dialogContext as Element).widget;
      } catch (e) {
        isDialogStillMounted = false;
      }
      if (!isDialogStillMounted) {
        _updatingItemIds.remove(item.orderItemId);
        return;
      } // Exit if dialog closed

      print(
          "Network/Timeout/Other Error updating item ${item.orderItemId}: $e");
      success = false;
      String errorMsg = 'Lỗi mạng hoặc timeout khi cập nhật món ăn.';
      if (e is TimeoutException) {
        errorMsg = 'Yêu cầu cập nhật món ăn quá thời gian. Vui lòng thử lại.';
      }
      // Show error SnackBar (dialog or main screen)
      if (isDialogStillMounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
            content: Text(errorMsg), backgroundColor: Colors.orangeAccent));
      } else if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
            content: Text(errorMsg), backgroundColor: Colors.orangeAccent));
      }
    } finally {
      // --- End Loading State for this item ---
      if (mounted) {
        isDialogStillMounted = true;
        try {
          (dialogContext as Element).widget;
        } catch (e) {
          isDialogStillMounted = false;
        }
        if (isDialogStillMounted) {
          try {
            setDialogState(() => _updatingItemIds.remove(item.orderItemId));
          } catch (e) {
            _updatingItemIds.remove(item.orderItemId);
          }
        } else {
          _updatingItemIds
              .remove(item.orderItemId); // Clean up state even if dialog closed
        }
      } else {
        _updatingItemIds
            .remove(item.orderItemId); // Clean up if main screen disposed
      }
      print(
          "Finished update attempt for item ${item.orderItemId}. Success: $success");
    }
  }

  // Helper to call the specific "complete order" API endpoint (unchanged)
  Future<bool> _callCompleteOrderApi(int orderId) async {
    // (Keep existing implementation)
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

  // Completes all items for an order using the direct API (unchanged)
  Future<void> _completeAllItemsForOrder(KitchenListOrder order,
      StateSetter setDialogState, BuildContext dialogContext) async {
    // (Keep existing implementation)
    if (_isCompletingAll) return; // Prevent double execution
    if (!mounted) return;

    bool isDialogStillMounted = true;
    try {
      (dialogContext as Element).widget;
    } catch (e) {
      isDialogStillMounted = false;
    }
    if (!isDialogStillMounted) return;

    print("Calling API to complete order ${order.orderId} directly.");

    // --- Start Loading State ---
    try {
      setDialogState(() => _isCompletingAll = true);
    } catch (e) {
      print("Error setting dialog state for 'Complete Order' start: $e");
      _isCompletingAll = false;
      return;
    }

    // --- Call API ---
    bool success = await _callCompleteOrderApi(order.orderId); // Use the helper

    // --- Check Mounts After Await ---
    if (!mounted) return;
    isDialogStillMounted = true;
    try {
      (dialogContext as Element).widget;
    } catch (e) {
      isDialogStillMounted = false;
    }

    if (success) {
      print(
          "API Success: Order ${order.orderId} marked as complete by server (via Complete All).");

      // --- UI Update for Order Complete ---
      if (mounted) {
        setState(() {
          // Update main screen state
          _pendingOrders = _pendingOrders
              .where((o) => o.orderId != order.orderId)
              .toList(); // Remove from pending
          _inProgressOrderIds.remove(order.orderId); // Remove from in-progress
          // Add to completed list
          if (!_completedOrders.any((co) => co.orderId == order.orderId)) {
            _completedOrders.insert(0, order);
          }
          _notifyTableStatusUpdate(order.tableNumber); // Notify parent
        });
        // Show confirmation SnackBar on main screen
        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
          content: Text('Đơn hàng #${order.orderId} đã hoàn thành!'),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 3),
        ));
      }
      // Close the detail popup
      if (isDialogStillMounted && Navigator.canPop(dialogContext)) {
        Navigator.of(dialogContext).pop();
      }
      // Optionally refresh completed list in background
      if (mounted) _fetchCompletedOrders();
    } else {
      // --- Handle API Error ---
      print("API Error completing order ${order.orderId} (via Complete All).");
      String errorMsg = 'Lỗi hoàn thành đơn hàng.'; // Simple error message
      // Show error SnackBar (dialog or main screen)
      if (isDialogStillMounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
            content: Text(errorMsg), backgroundColor: Colors.redAccent));
        _fetchOrderDetail(
            order.orderId, setDialogState); // Refresh details on error
      } else if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
            content: Text(errorMsg), backgroundColor: Colors.redAccent));
      }
    }

    // --- End Loading State ---
    if (mounted) {
      isDialogStillMounted = true;
      try {
        (dialogContext as Element).widget;
      } catch (e) {
        isDialogStillMounted = false;
      }
      if (isDialogStillMounted) {
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
    } else {
      _isCompletingAll = false;
      _updatingItemIds.clear();
    }
    print(
        "'Complete Order' process finished for order ${order.orderId} (via Complete All). Success: $success");
  }

  // Notifies MenuScreen about table status changes (unchanged)
  void _notifyTableStatusUpdate(int? tableNumber) {
    // (Keep existing implementation)
    if (!mounted) return;
    if (tableNumber == null || tableNumber <= 0 || tableNumber == -1) {
      print(
          "Warning: Cannot notify table status, invalid table number: $tableNumber. Refreshing all pending.");
      _fetchPendingOrders(
          forceRefresh: true); // Refresh all if table number is bad
      return;
    }

    print("Checking if table $tableNumber is now clear...");
    // Check if there are ANY orders left in the current pending list for this table
    bool otherPendingForTable = _pendingOrders
        .any((pendingOrder) => pendingOrder.tableNumber == tableNumber);

    if (!otherPendingForTable) {
      print("Table $tableNumber is now clear. Calling onTableCleared.");
      try {
        widget.onTableCleared
            ?.call(tableNumber); // Notify parent: table is clear
      } catch (e) {
        print("Error calling onTableCleared: $e");
      }
    } else {
      print(
          "Table $tableNumber still has other pending orders. Recalculating counts.");
      // If table not clear, still update the counts for the parent
      Map<int, int> currentCounts = {};
      for (var o in _pendingOrders) {
        if (o.tableNumber != null &&
            o.tableNumber! > 0 &&
            o.tableNumber! != -1) {
          currentCounts[o.tableNumber!] =
              (currentCounts[o.tableNumber!] ?? 0) + 1;
        }
      }
      try {
        widget.onOrderUpdate
            ?.call(currentCounts); // Notify parent: update counts
      } catch (e) {
        print("Error calling onOrderUpdate after partial table clear: $e");
      }
    }
  }

  // --- Helper Methods for Status Display ---
  // (Keep existing _getStatusColor, _getStatusIcon, _getStatusText implementations)
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
    super.build(context); // Keep state
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildViewSwitcher(theme), // Pending/Completed tabs
        Expanded(child: _buildBodyContent(theme)), // List content area
        // Connection status indicator (unchanged)
        if (!_isConnected && _reconnectAttempts > 0)
          Container(/* ... connection status indicator ... */)
      ],
    );
  }

  // Builds the Pending/Completed switcher (unchanged)
  Widget _buildViewSwitcher(ThemeData theme) {
    // (Keep existing implementation)
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

  // Builds the main content area (list, shimmer, error, empty) (unchanged)
  Widget _buildBodyContent(ThemeData theme) {
    // (Keep existing implementation)
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

  // Builds the shimmer loading list (unchanged)
  Widget _buildShimmerLoadingList(ThemeData theme) {
    // (Keep existing implementation)
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

  // Builds the actual list view for orders (pending or completed)
  // Optimized to handle table number loading state within the list item build.
  Widget _buildOrderListView(List<KitchenListOrder> orders) {
    final theme = Theme.of(context);
    // Using ListView.builder is already efficient for potentially long lists
    return ListView.builder(
      physics:
          const AlwaysScrollableScrollPhysics(), // Needed for RefreshIndicator
      padding: EdgeInsets.fromLTRB(
          kDefaultPadding,
          kDefaultPadding,
          kDefaultPadding,
          kDefaultPadding + kBottomActionBarHeight), // Adjust padding
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final formattedTime =
            DateFormat('HH:mm - dd/MM/yy').format(order.orderTime);
        final bool isServed = _currentView == OrderListView.completed;
        final bool showInProgressIcon =
            !isServed && _inProgressOrderIds.contains(order.orderId);

        // --- Styling for Order Title ---
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
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.error,
          fontStyle: FontStyle.italic,
        );

        // --- Determine how to display table number ---
        // Access the potentially updated table number directly from the order object
        int? currentTableNumber = order.tableNumber;
        InlineSpan tableNumberSpan;

        if (currentTableNumber == null) {
          // State: Still loading table number (or fetch hasn't happened yet)
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
        } else if (currentTableNumber == -1) {
          // State: Error fetching table number (cached as -1)
          tableNumberSpan = TextSpan(text: 'Lỗi', style: tableErrorStyle);
        } else {
          // State: Valid table number available
          tableNumberSpan = TextSpan(
              text: currentTableNumber.toString(), style: tableNumberStyle);
        }
        // --- End Table Number Display Logic ---

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
              // Use Text.rich for combining styled spans
              TextSpan(
                style: defaultTitleStyle, // Base style for the title line
                children: [
                  TextSpan(
                      text: 'Bàn ',
                      style: TextStyle(
                          color: isServed ? Colors.grey[400] : Colors.white70)),
                  tableNumberSpan, // Insert the dynamically created span here
                  TextSpan(text: ' - Đơn #${order.orderId}'),
                  if (showInProgressIcon)
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }

  // Builds the error widget (unchanged)
  Widget _buildErrorWidget(String message, Future<void> Function() onRetry) {
    // (Keep existing implementation)
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

  // Builds the empty list widget (unchanged)
  Widget _buildEmptyListWidget(
      String message, IconData icon, Future<void> Function() onRefresh) {
    // (Keep existing implementation)
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
                              // Add refresh text button
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
}
