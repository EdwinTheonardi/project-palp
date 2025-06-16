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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Penerimaan Barang',
      debugShowCheckedModeBanner: false,
      home: initialStoreCode != null
          ? NavigationHomePage()
          : LoginPage(), // arahkan ke login jika belum login
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
    Navigator.pop(context); // Menutup drawer setelah memilih
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitles[_selectedIndex]),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                ' ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.receipt),
              title: Text('Invoices'),
              selected: _selectedIndex == 5,
              onTap: () => _onDrawerItemTapped(5),
            ),
            ListTile(
              leading: Icon(Icons.receipt),
              title: Text('Receipts'),
              selected: _selectedIndex == 0,
              onTap: () => _onDrawerItemTapped(0),
            ),
            ListTile(
              leading: Icon(Icons.local_shipping),
              title: Text('Shipments'),
              selected: _selectedIndex == 1,
              onTap: () => _onDrawerItemTapped(1),
            ),
            ListTile(
              leading: Icon(Icons.people),
              title: Text('Suppliers'),
              selected: _selectedIndex == 2,
              onTap: () => _onDrawerItemTapped(2),
            ),
            ListTile(
              leading: Icon(Icons.warehouse),
              title: Text('Warehouses'),
              selected: _selectedIndex == 3,
              onTap: () => _onDrawerItemTapped(3),
            ),
            ListTile(
              leading: Icon(Icons.shopping_bag),
              title: Text('Products'),
              selected: _selectedIndex == 4,
              onTap: () => _onDrawerItemTapped(4),
            ),
            ListTile(
              leading: Icon(Icons.shopping_bag),
              title: Text('Warehouse Stock'),
              selected: _selectedIndex == 6,
              onTap: () => _onDrawerItemTapped(6),
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text("Konfirmasi Logout"),
                    content: Text("Apakah kamu yakin ingin logout?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text("Batal"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text("Logout"),
                      ),
                    ],
                  ),
                );

                if (shouldLogout == true) {
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
}
