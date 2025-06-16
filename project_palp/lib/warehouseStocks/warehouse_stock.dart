import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';
import 'package:intl/intl.dart';

class WarehouseStockPage extends StatefulWidget {
  const WarehouseStockPage({ super.key });

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
      setState(() => _loading = false);
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
        setState(() => _loading = false);
        return;
      }

      final storeDoc = storeSnapshot.docs.first;
      final storeRef = storeDoc.reference;

      print("Store reference ditemukan: ${storeRef.path}");

      final stocksSnapshot = await FirebaseFirestore.instance
          .collection('warehouseStocks')
          .where('store_ref', isEqualTo: storeRef)
          .get();

      setState(() {
        _storeRef = storeRef;
        _allStocks = stocksSnapshot.docs;
        _loading = false;
      });
    } catch (e) {
      print("Gagal memuat data: $e");
      setState(() => _loading = false);
    }
  }

  Future<String> _getProductName(DocumentReference? productRef) async {
    if (productRef == null) return '-';
    try {
      final doc = await productRef.get();
      final data = doc.data() as Map<String, dynamic>?;
      return data?['name'] ?? '-';
    } catch (e) {
      print("Gagal mendapatkan nama produk: $e");
      return '-';
    }
  }

  Future<String> _getWarehouseName(DocumentReference? warehouseRef) async {
    if (warehouseRef == null) return '-';
    try {
      final doc = await warehouseRef.get();
      final data = doc.data() as Map<String, dynamic>?;
      return data?['name'] ?? '-';
    } catch (e) {
      print("Gagal mendapatkan nama warehouse: $e");
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _loading
              ? Center(child: CircularProgressIndicator())
              : _allStocks.isEmpty
                  ? Center(child: Text('Tidak ada data stok per gudang'))
                  : RefreshIndicator(
                      onRefresh: _loadStocksForStore,
                      child: ListView.builder(
                        itemCount: _allStocks.length,
                        itemBuilder: (context, index) {
                          final stock = _allStocks[index].data() as Map<String, dynamic>;

                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Table(
                                columnWidths: {
                                  0: FlexColumnWidth(1),
                                  1: FlexColumnWidth(1),
                                },
                                children: [
                                  TableRow(
                                    children: [
                                      TableCell(
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0),
                                          child: FutureBuilder<String>(
                                            future: _getProductName(stock['product_ref']),
                                            builder: (context, snapshot) {
                                              return Text("Nama Produk: ${snapshot.data ?? '-'}");
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  TableRow(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          FutureBuilder<String>(
                                            future: _getWarehouseName(stock['warehouse_ref']),
                                            builder: (context, snapshot) {
                                              return Text('Nama Gudang: ${snapshot.data ?? '-'}');
                                            },
                                          ),
                                          Text("Stok: ${stock['qty'] ?? '-'}"),
                                          Text(
                                            'Terakhir diupdate: ${stock['last_updated_at'] != null 
                                              ? DateFormat('dd/MM/yyyy').format((stock['last_updated_at'] as Timestamp).toDate()) 
                                              : '-'}'
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ],
      ),
    );
  }
}