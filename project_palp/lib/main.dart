import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/store_service.dart';
import 'receipt/receipt.dart';
import 'supplier/supplier.dart';
import 'warehouse/warehouse.dart';
import 'product/product.dart';
import 'shipment/shipment.dart';
import 'warehouseStocks/warehouse_stock.dart';
import 'invoice/invoice.dart';
import 'login/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  String? storeCode = await StoreService.getStoreCode();

  runApp(MyApp(initialStoreCode: storeCode));
}

class MyApp extends StatelessWidget {
  final String? initialStoreCode;

  MyApp({required this.initialStoreCode});

  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;
  static const Color lightGray = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Penerimaan Barang',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: midnightBlue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: midnightBlue,
          primary: midnightBlue,
          secondary: accentOrange,
          background: lightGray,
        ),
        scaffoldBackgroundColor: lightGray,
        appBarTheme: const AppBarTheme(
          backgroundColor: midnightBlue,
          foregroundColor: cleanWhite,
          elevation: 2.0,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: cleanWhite, // INI PERBAIKANNYA
          ),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: cleanWhite,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accentOrange,
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        useMaterial3: true,
      ),
      home: initialStoreCode != null ? NavigationHomePage() : LoginPage(),
    );
  }
}

class NavigationHomePage extends StatefulWidget {
  @override
  _NavigationHomePageState createState() => _NavigationHomePageState();
}

class _NavigationHomePageState extends State<NavigationHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    ReceiptPage(),
    ShipmentPage(),
    SupplierPage(),
    WarehousePage(),
    ProductPage(),
    InvoicePage(),
    WarehouseStockPage()
  ];

  final List<String> _pageTitles = [
    'Receipts',
    'Shipments',
    'Suppliers',
    'Warehouses',
    'Products',
    'Invoices',
    'Warehouse Stock',
  ];

  void _onDrawerItemTapped(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitles[_selectedIndex]),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: MyApp.midnightBlue,
              ),
              child: Center(
                child: Text(
                  'Menu Utama',
                  style: TextStyle(
                    color: MyApp.cleanWhite,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            _buildDrawerItem(icon: Icons.receipt_long, title: 'Invoices', index: 5),
            _buildDrawerItem(icon: Icons.receipt, title: 'Receipts', index: 0),
            _buildDrawerItem(icon: Icons.local_shipping, title: 'Shipments', index: 1),
            _buildDrawerItem(icon: Icons.people_alt_outlined, title: 'Suppliers', index: 2),
            _buildDrawerItem(icon: Icons.warehouse, title: 'Warehouses', index: 3),
            _buildDrawerItem(icon: Icons.inventory_2_outlined, title: 'Products', index: 4),
            _buildDrawerItem(icon: Icons.inventory, title: 'Warehouse Stock', index: 6),
            const Divider(height: 1, thickness: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text("Konfirmasi Logout"),
                    content: const Text("Apakah kamu yakin ingin logout?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text("Batal"),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: MyApp.cleanWhite,
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text("Logout"),
                      ),
                    ],
                  ),
                );

                if (shouldLogout == true && mounted) {
                  await StoreService.clearStore();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => LoginPage()),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }

  Widget _buildDrawerItem({required IconData icon, required String title, required int index}) {
    final bool isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? MyApp.accentOrange.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? MyApp.accentOrange : Colors.grey[700]),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? MyApp.accentOrange : Colors.black87,
          ),
        ),
        selected: isSelected,
        onTap: () => _onDrawerItemTapped(index),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}