import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import '../services/store_service.dart';
import 'package:intl/intl.dart';
import 'add_receipt.dart';
import 'edit_receipt.dart';

class ReceiptPage extends StatefulWidget {
  const ReceiptPage({ super.key });

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  DocumentReference? _storeRef;
  List<DocumentSnapshot> _allReceipts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReceiptsForStore();
  }

  Future<void> _loadReceiptsForStore() async {
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

      final receiptsSnapshot = await FirebaseFirestore.instance
          .collection('purchaseGoodsReceipts')
          .where('store_ref', isEqualTo: storeRef)
          .get();

      setState(() {
        _storeRef = storeRef;
        _allReceipts = receiptsSnapshot.docs;
        _loading = false;
      });
    } catch (e) {
      print("Gagal memuat data: $e");
      setState(() => _loading = false);
    }
  }

  Future<String> _getSupplierName(DocumentReference? supplierRef) async {
    if (supplierRef == null) return '-';
    try {
      final doc = await supplierRef.get();
      final data = doc.data() as Map<String, dynamic>?;
      return data?['name'] ?? '-';
    } catch (e) {
      print("Gagal mendapatkan nama supplier: $e");
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
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _allReceipts.isEmpty
              ? Center(child: Text('Tidak ada data penerimaan'))
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadReceiptsForStore,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            child: DataTable2(
                              columnSpacing: 20,
                              horizontalMargin: 16,
                              headingRowColor: WidgetStateProperty.all(Colors.blue[100]),
                              columns: [
                                DataColumn2(
                                  label: Center(child: Text('No Form')),
                                  size: ColumnSize.M,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Created At')),
                                  size: ColumnSize.M,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Post Date')),
                                  size: ColumnSize.M,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Grand Total')),
                                  size: ColumnSize.M,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Qty Total')),
                                  size: ColumnSize.S,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Synced')),
                                  size: ColumnSize.S,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Supplier')),
                                  size: ColumnSize.L,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Warehouse')),
                                  size: ColumnSize.L,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Receipt Details')),
                                  size: ColumnSize.L,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Action')),
                                  size: ColumnSize.L,
                                ),
                              ],
                              rows: _allReceipts.map((doc) {
                                final receipt = doc.data() as Map<String, dynamic>;
                                return DataRow(cells: [
                                  DataCell(Text(receipt['no_form'] ?? '-')),
                                  DataCell(Text(
                                  receipt['created_at'] != null
                                      ? DateFormat('dd MMMM yyyy, HH:mm:ss').format(receipt['created_at'].toDate())
                                      : '-',
                                  )),
                                  DataCell(Text(
                                    receipt['post_date'] != null 
                                      ? DateFormat('dd/MM/yyyy').format((receipt['post_date'] as Timestamp).toDate()) 
                                      : '-'
                                  )),
                                  DataCell(
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        NumberFormat.currency(
                                          locale: 'id_ID',
                                          symbol: 'Rp. ',
                                          decimalDigits: 0,
                                        ).format(receipt['grandtotal'] ?? 0),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(receipt['item_total']?.toString() ?? '-'),
                                    ),
                                  ),
                                  DataCell(
                                    Align(
                                      alignment: Alignment.center,
                                      child: Text(receipt['synced']?.toString() ?? '-'),
                                    ),
                                  ),
                                  DataCell(
                                    FutureBuilder<String>(
                                      future: _getSupplierName(receipt['supplier_ref']),
                                      builder: (context, snapshot) {
                                        return Text(snapshot.data ?? '-');
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    FutureBuilder<String>(
                                      future: _getWarehouseName(receipt['warehouse_ref']),
                                      builder: (context, snapshot) {
                                        return Text(snapshot.data ?? '-');
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    Align(
                                      alignment: Alignment.center,
                                      child: TextButton(
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ReceiptDetailsPage(receiptRef: doc.reference),
                                            ),
                                          );
                                          await _loadReceiptsForStore();
                                        },
                                        child: Text("Detail"),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Align(
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.edit, color: Colors.lightBlue),
                                            tooltip: "Edit Receipt",
                                            onPressed: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => EditReceiptPage(receiptRef: doc.reference),
                                                ),
                                              );
                                              await _loadReceiptsForStore();
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete, color: Colors.redAccent),
                                            tooltip: "Delete Receipt",
                                            onPressed: () async {
                                              _showDeleteConfirmationDialog(context, doc.reference);
                                              await _loadReceiptsForStore();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16, right: 16),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: SizedBox(
                          width: 180,
                          height: 45,
                          child: ElevatedButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AddReceiptPage()),
                              );
                              await _loadReceiptsForStore();
                            },
                            child: Text('Tambah Receipt'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, DocumentReference ref) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi'),
        content: Text('Yakin ingin menghapus receipt ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        final receiptSnapshot = await ref.get();
        final receiptData = receiptSnapshot.data() as Map<String, dynamic>;
        final warehouseRef = receiptData['warehouse_ref'] as DocumentReference?;

        final detailsSnapshot = await ref.collection('details').get();

        for (final doc in detailsSnapshot.docs) {
          final data = doc.data();
          final productRef = data['product_ref'] as DocumentReference?;
          final qty = data['qty'] ?? 0;

          if (productRef != null) {
            final productSnapshot = await productRef.get();
            final productData = productSnapshot.data() as Map<String, dynamic>?;
            if (productData != null) {
              final currentStock = productData['stock'] ?? 0;
              final updatedStock = currentStock - qty;
              await productRef.update({'stock': updatedStock});
            }

            if (warehouseRef != null) {
              final wsQuery = await FirebaseFirestore.instance
                .collection('warehouseStocks')
                .where('product_ref', isEqualTo: productRef)
                .where('warehouse_ref', isEqualTo: warehouseRef)
                .limit(1)
                .get();

              if (wsQuery.docs.isNotEmpty) {
                final wsDoc = wsQuery.docs.first;
                final wsData = wsDoc.data();
                final wsQty = wsData['qty'] ?? 0;
                final updatedWsQty = wsQty - qty;
                await wsDoc.reference.update({'qty': updatedWsQty});
              }
            }
          }
          await doc.reference.delete();
        }
        await ref.delete();
        await _loadReceiptsForStore();
      } catch (e) {
        print("Gagal menghapus receipt dan update stok: $e");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Gagal menghapus receipt."),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
}

class ReceiptDetailsPage extends StatefulWidget {
  final DocumentReference receiptRef;

  const ReceiptDetailsPage({super.key, required this.receiptRef});

  @override
  State<ReceiptDetailsPage> createState() => _ReceiptDetailsPageState();
}

class _ReceiptDetailsPageState extends State<ReceiptDetailsPage> {
  List<DocumentSnapshot> _allDetails = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final detailsSnapshot =
          await widget.receiptRef.collection('details').get();

      setState(() {
        _allDetails = detailsSnapshot.docs;
        _loading = false;
      });
    } catch (e) {
      print("Gagal memuat detail: $e");
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
      print("Gagal mendapatkan nama product: $e");
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Details')
        ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _allDetails.isEmpty
              ? const Center(child: Text('Tidak ada detail produk.'))
              : ListView.builder(
                  itemCount: _allDetails.length,
                  itemBuilder: (context, index) {
                    final data =
                        _allDetails[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder<String>(
                              future: _getProductName(data['product_ref']),
                              builder: (context, snapshot) {
                                return Text(snapshot.data ?? '-');
                              },
                            ),
                            Text("Qty: ${data['qty'] ?? '-'}"),
                            Text("Unit: ${data['unit_name'] ?? '-'}"),
                            Text("Price: ${data['price'] ?? '-'}"),
                            Text("Subtotal: ${data['subtotal'] ?? '-'}"),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}