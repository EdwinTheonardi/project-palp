import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import '../services/store_service.dart';
import 'package:intl/intl.dart';
import 'add_receipt.dart';
import 'edit_receipt.dart';

class ReceiptPage extends StatefulWidget {
  const ReceiptPage({super.key});

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  DocumentReference? _storeRef;
  List<DocumentSnapshot> _allReceipts = [];
  bool _loading = true;

  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadReceiptsForStore();
  }

  Future<void> _loadReceiptsForStore() async {
    final storeCode = await StoreService.getStoreCode();
    if (storeCode == null || storeCode.isEmpty) {
      print("Store code tidak ditemukan.");
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final storeSnapshot = await FirebaseFirestore.instance.collection('stores').where('code', isEqualTo: storeCode).limit(1).get();
      if (storeSnapshot.docs.isEmpty) {
        print("Store dengan code $storeCode tidak ditemukan.");
        if (mounted) setState(() => _loading = false);
        return;
      }
      final storeDoc = storeSnapshot.docs.first;
      final storeRef = storeDoc.reference;
      print("Store reference ditemukan: ${storeRef.path}");
      final receiptsSnapshot = await FirebaseFirestore.instance.collection('purchaseGoodsReceipts').where('store_ref', isEqualTo: storeRef).get();
      if (mounted) {
        setState(() {
          _storeRef = storeRef;
          _allReceipts = receiptsSnapshot.docs;
          _loading = false;
        });
      }
    } catch (e) {
      print("Gagal memuat data: $e");
      if (mounted) setState(() => _loading = false);
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
          ? const Center(child: CircularProgressIndicator(color: accentOrange))
          : _allReceipts.isEmpty
              ? Center(
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('Tidak ada data penerimaan', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ))
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadReceiptsForStore,
                        color: accentOrange,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 2.5,
                            child: DataTable2(
                              columnSpacing: 20,
                              horizontalMargin: 16,
                              headingRowColor: WidgetStateProperty.all(midnightBlue.withOpacity(0.05)),
                              headingTextStyle: const TextStyle(color: midnightBlue, fontWeight: FontWeight.bold),
                              columns: const [
                                DataColumn2(label: Center(child: Text('No Form')), size: ColumnSize.M),
                                DataColumn2(label: Center(child: Text('Created At')), size: ColumnSize.L),
                                DataColumn2(label: Center(child: Text('Post Date')), size: ColumnSize.M),
                                DataColumn2(label: Center(child: Text('Grand Total')), size: ColumnSize.L),
                                DataColumn2(label: Center(child: Text('Qty Total')), size: ColumnSize.S),
                                DataColumn2(label: Center(child: Text('Synced')), size: ColumnSize.S),
                                DataColumn2(label: Center(child: Text('Supplier')), size: ColumnSize.L),
                                DataColumn2(label: Center(child: Text('Warehouse')), size: ColumnSize.L),
                                DataColumn2(label: Center(child: Text('Receipt Details')), size: ColumnSize.M),
                                DataColumn2(label: Center(child: Text('Action')), size: ColumnSize.L),
                              ],
                              rows: _allReceipts.map((doc) {
                                final receipt = doc.data() as Map<String, dynamic>;
                                return DataRow(cells: [
                                  DataCell(Text(receipt['no_form'] ?? '-')),
                                  DataCell(Text(receipt['created_at'] != null ? DateFormat('dd MMM yyyy, HH:mm').format(receipt['created_at'].toDate()) : '-')),
                                  DataCell(Text(receipt['post_date'] != null ? DateFormat('dd/MM/yyyy').format((receipt['post_date'] as Timestamp).toDate()) : '-')),
                                  DataCell(Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(receipt['grandtotal'] ?? 0)),
                                  )),
                                  DataCell(Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(receipt['item_total']?.toString() ?? '-'),
                                  )),
                                  DataCell(Align(
                                    alignment: Alignment.center,
                                    child: Icon(
                                      receipt['synced'] == true ? Icons.check_circle : Icons.cancel,
                                      color: receipt['synced'] == true ? Colors.green : Colors.red,
                                    ),
                                  )),
                                  DataCell(FutureBuilder<String>(
                                    future: _getSupplierName(receipt['supplier_ref']),
                                    builder: (context, snapshot) => Text(snapshot.data ?? '...'),
                                  )),
                                  DataCell(FutureBuilder<String>(
                                    future: _getWarehouseName(receipt['warehouse_ref']),
                                    builder: (context, snapshot) => Text(snapshot.data ?? '...'),
                                  )),
                                  DataCell(Center(
                                    child: TextButton(
                                      style: TextButton.styleFrom(foregroundColor: accentOrange),
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => ReceiptDetailsPage(receiptRef: doc.reference)),
                                        );
                                        await _loadReceiptsForStore();
                                      },
                                      child: const Text("Detail"),
                                    ),
                                  )),
                                  DataCell(Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined, color: Colors.blueGrey[600]),
                                          tooltip: "Edit Receipt",
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => EditReceiptPage(receiptRef: doc.reference)),
                                            );
                                            await _loadReceiptsForStore();
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline, color: Colors.redAccent[400]),
                                          tooltip: "Delete Receipt",
                                          onPressed: () {
                                            _showDeleteConfirmationDialog(context, doc.reference);
                                          },
                                        ),
                                      ],
                                    ),
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16, right: 16, top: 16),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddReceiptPage()),
                            );
                            await _loadReceiptsForStore();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentOrange,
                            foregroundColor: cleanWhite,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          label: const Text('Tambah Receipt'),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi'),
        content: const Text('Yakin ingin menghapus receipt ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
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
              final wsQuery = await FirebaseFirestore.instance.collection('warehouseStocks').where('product_ref', isEqualTo: productRef).where('warehouse_ref', isEqualTo: warehouseRef).limit(1).get();
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Gagal menghapus receipt."),
            backgroundColor: Colors.red,
          ));
        }
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

  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final detailsSnapshot = await widget.receiptRef.collection('details').get();
      if (mounted) {
        setState(() {
          _allDetails = detailsSnapshot.docs;
          _loading = false;
        });
      }
    } catch (e) {
      print("Gagal memuat detail: $e");
      if (mounted) setState(() => _loading = false);
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
      appBar: AppBar(title: const Text('Detail Penerimaan'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accentOrange))
          : _allDetails.isEmpty
              ? Center(
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('Tidak ada detail produk.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ))
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _allDetails.length,
                  itemBuilder: (context, index) {
                    final data = _allDetails[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      elevation: 2,
                      color: cleanWhite,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.inventory_2_outlined, color: midnightBlue),
                        title: FutureBuilder<String>(
                          future: _getProductName(data['product_ref']),
                          builder: (context, snapshot) {
                            return Text(snapshot.data ?? 'Memuat...', style: const TextStyle(fontWeight: FontWeight.bold, color: midnightBlue));
                          },
                        ),
                        subtitle: Text(
                            "Qty: ${data['qty'] ?? '-'} ${data['unit_name'] ?? ''}  •  Harga: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(data['price'] ?? 0)}"),
                        trailing: Text(
                          NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(data['subtotal'] ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}