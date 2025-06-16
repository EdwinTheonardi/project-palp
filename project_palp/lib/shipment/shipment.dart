import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';
import 'add_shipment.dart';
import 'edit_shipment.dart';

class ShipmentPage extends StatefulWidget {
  const ShipmentPage({ super.key });

  @override
  State<ShipmentPage> createState() => _ShipmentPageState();
}

class _ShipmentPageState extends State<ShipmentPage> {
  DocumentReference? _storeRef;
  List<DocumentSnapshot> _allShipments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadShipmentsForStore();
  }

  Future<void> _loadShipmentsForStore() async {
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

      final shipmentsSnapshot = await FirebaseFirestore.instance
          .collection('salesGoodsShipment')
          .where('store_ref', isEqualTo: storeRef)
          .get();

      setState(() {
        _storeRef = storeRef;
        _allShipments = shipmentsSnapshot.docs;
        _loading = false;
      });
    } catch (e) {
      print("Gagal memuat data: $e");
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _loading
              ? Center(child: CircularProgressIndicator())
              : _allShipments.isEmpty
                  ? Center(child: Text('Tidak ada data pengiriman'))
                  : RefreshIndicator(
                      onRefresh: _loadShipmentsForStore,
                      child: ListView.builder(
                        itemCount: _allShipments.length,
                        itemBuilder: (context, index) {
                          final shipment = _allShipments[index].data() as Map<String, dynamic>;

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
                                          child: Text(
                                            'No Form: ${shipment['no_form'] ?? '-'}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      TableCell(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.edit, color: Colors.lightBlue),
                                              tooltip: "Edit Shipment",
                                              onPressed: () async {
                                                final updated = await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => EditShipmentPage(
                                                      shipmentRef: _allShipments[index].reference,
                                                    ),
                                                  ),
                                                );
                                                await _loadShipmentsForStore(); // Refresh list setelah kembali
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete, color: Colors.lightBlue),
                                              tooltip: "Hapus Shipment",
                                              onPressed: () async {
                                                _showDeleteConfirmationDialog(
                                                  context,
                                                  _allShipments[index].reference,
                                                );                          
                                                await _loadShipmentsForStore(); 
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Baris 2: Info kiri & kanan
                                  TableRow(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Nama Penerima: ${shipment['receiver_name'] ?? '-'}'),
                                          Text('Item Total: ${shipment['item_total'] ?? '-'}'),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Created At: ${shipment['created_at']?.toDate() ?? '-'}'),
                                          Text('Post Date: ${shipment['post_date'] ?? '-'}'),
                                        ],
                                      ),
                                    ],
                                  ),
                                  // Baris 3: Tombol
                                  TableRow(
                                    children: [
                                      TableCell(child: SizedBox()), // Kosong
                                      TableCell(
                                        child: Align(
                                          alignment: Alignment.bottomRight,
                                          child: TextButton(
                                            onPressed: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => ShipmentDetailsPage(
                                                    shipmentRef: _allShipments[index].reference,
                                                  ),
                                                ),
                                              );
                                              await _loadShipmentsForStore();
                                            },
                                            child: Text("Lihat Detail"),
                                          ),
                                        ),
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
          // Tombol Tambah di kanan bawah
          Positioned(
            bottom: 16,
            right: 16,
            child: SizedBox(
              width: 180,
              height: 45,
              child: ElevatedButton(  
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddShipmentPage()),
                  );
                  await _loadShipmentsForStore(); // Refresh data setelah tambah
                },
                child: Text('Tambah Shipment'),
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
        content: Text('Yakin ingin menghapus shipment ini?'),
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
        final detailsSnapshot = await ref.collection('details').get();

        for (final doc in detailsSnapshot.docs) {
          final detailData = doc.data();
          final productRef = detailData['product_ref'] as DocumentReference?;
          final warehouseRef = detailData['warehouse_ref'] as DocumentReference?;
          final qty = (detailData['qty'] ?? 0) as int;

          if (productRef != null && warehouseRef != null) {
            final stockQuery = await FirebaseFirestore.instance
                .collection('warehouseStocks')
                .where('product_ref', isEqualTo: productRef)
                .where('warehouse_ref', isEqualTo: warehouseRef)
                .limit(1)
                .get();

            final productDoc = await productRef.get();
            if (productDoc.exists) {
              final productData = productDoc.data() as Map<String, dynamic>;
              final currentGlobalStock = productData['stock'] ?? 0;

              await productRef.update({
                'stock': currentGlobalStock + qty,
              });
            }

            if (stockQuery.docs.isNotEmpty) {
              final stockDoc = stockQuery.docs.first;
              final currentStock = stockDoc['qty'] ?? 0;
              await stockDoc.reference.update({
                'qty': currentStock + qty,
              });
            }
          }
          await doc.reference.delete();
        }
        await ref.delete();
        await _loadShipmentsForStore();
      } catch (e) {
        print('Gagal menghapus shipment: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus shipment: $e')),
        );
      }
    }
  }
}

class ShipmentDetailsPage extends StatefulWidget {
  final DocumentReference shipmentRef;

  const ShipmentDetailsPage({super.key, required this.shipmentRef});

  @override
  State<ShipmentDetailsPage> createState() => _ShipmentDetailsPageState();
}

class _ShipmentDetailsPageState extends State<ShipmentDetailsPage> {
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
          await widget.shipmentRef.collection('details').get();

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
      appBar: AppBar(title: const Text('Shipment Details')),
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
                                return Text("Nama Produk: ${snapshot.data ?? '-'}");
                              },
                            ),
                            Text("Qty: ${data['qty'] ?? '-'} ${data['unit_name'] ?? '-'}"),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}