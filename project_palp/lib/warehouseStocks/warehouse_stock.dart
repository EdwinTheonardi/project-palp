import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart'; 
import 'package:intl/intl.dart';

const Color midnightBlue = Color(0xFF003366);
const Color accentOrange = Color(0xFFFFA500);
const Color cleanWhite = Colors.white;

class WarehouseStockPage extends StatefulWidget {
  const WarehouseStockPage({super.key});

  @override
  State<WarehouseStockPage> createState() => _WarehouseStockPageState();
}

class _WarehouseStockPageState extends State<WarehouseStockPage> {
  DocumentReference? _storeRef;
  List<DocumentSnapshot> _allStocks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStocksForStore();
  }


  Future<void> _loadStocksForStore() async {
    final storeCode = await StoreService.getStoreCode();

    if (storeCode == null || storeCode.isEmpty) {
      print("Store code tidak ditemukan.");
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final storeSnapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('code', isEqualTo: storeCode)
          .limit(1)
          .get();

      if (storeSnapshot.docs.isEmpty) {
        print("Store dengan code $storeCode tidak ditemukan.");
        if (mounted) setState(() => _loading = false);
        return;
      }

      final storeDoc = storeSnapshot.docs.first;
      final storeRef = storeDoc.reference;

      print("Store reference ditemukan: ${storeRef.path}");

      final stocksSnapshot = await FirebaseFirestore.instance
          .collection('warehouseStocks')
          .where('store_ref', isEqualTo: storeRef)
          .get();

      if (mounted) {
        setState(() {
          _storeRef = storeRef;
          _allStocks = stocksSnapshot.docs;
          _loading = false;
        });
      }
    } catch (e) {
      print("Gagal memuat data: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _getProductName(DocumentReference? productRef) async {
    if (productRef == null) return 'Produk Tidak Ditemukan';
    try {
      final doc = await productRef.get();
      final data = doc.data() as Map<String, dynamic>?;
      return data?['name'] ?? 'Tanpa Nama';
    } catch (e) {
      print("Gagal mendapatkan nama produk: $e");
      return 'Error';
    }
  }

  Future<String> _getWarehouseName(DocumentReference? warehouseRef) async {
    if (warehouseRef == null) return 'Gudang Tidak Ditemukan';
    try {
      final doc = await warehouseRef.get();
      final data = doc.data() as Map<String, dynamic>?;
      return data?['name'] ?? 'Tanpa Nama';
    } catch (e) {
      print("Gagal mendapatkan nama warehouse: $e");
      return 'Error';
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accentOrange))
          : _allStocks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum Ada Stok',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tarik ke bawah untuk menyegarkan.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStocksForStore,
                  color: accentOrange, 
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _allStocks.length,
                    itemBuilder: (context, index) {
                      final stock = _allStocks[index].data() as Map<String, dynamic>;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        elevation: 2,
                        color: cleanWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FutureBuilder<String>(
                                future: _getProductName(stock['product_ref']),
                                builder: (context, snapshot) {
                                  return Text(
                                    snapshot.data ?? 'Memuat...',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: midnightBlue,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: FutureBuilder<String>(
                                      future: _getWarehouseName(stock['warehouse_ref']),
                                      builder: (context, snapshot) {
                                        return _buildInfoRow(
                                          icon: Icons.warehouse_outlined,
                                          text: snapshot.data ?? 'Memuat...',
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        "Jumlah Stok",
                                        style: TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                      Text(
                                        "${stock['qty'] ?? '0'}",
                                        style: const TextStyle(
                                          color: accentOrange,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 24),

                              _buildInfoRow(
                                icon: Icons.calendar_today_outlined,
                                text: 'Update: ${stock['last_updated_at'] != null ? DateFormat('dd MMM yyyy').format((stock['last_updated_at'] as Timestamp).toDate()) : '-'}',
                                iconSize: 14,
                                textSize: 12,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
    double iconSize = 16,
    double textSize = 14,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: iconSize),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: textSize, color: Colors.grey[700]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}