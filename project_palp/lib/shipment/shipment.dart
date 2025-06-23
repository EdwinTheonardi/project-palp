import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/store_service.dart';
import 'add_shipment.dart';
import 'edit_shipment.dart';

class ShipmentPage extends StatefulWidget {
  const ShipmentPage({super.key});

  @override
  State<ShipmentPage> createState() => _ShipmentPageState();
}

class _ShipmentPageState extends State<ShipmentPage> {
  DocumentReference? _storeRef;
  List<DocumentSnapshot> _allShipments = [];
  bool _loading = true;

  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadShipmentsForStore();
  }

  Future<void> _loadShipmentsForStore() async {
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
      final shipmentsSnapshot = await FirebaseFirestore.instance.collection('salesGoodsShipment').where('store_ref', isEqualTo: storeRef).get();
      if (mounted) {
        setState(() {
          _storeRef = storeRef;
          _allShipments = shipmentsSnapshot.docs;
          _loading = false;
        });
      }
    } catch (e) {
      print("Gagal memuat data: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator(color: accentOrange))
              : _allShipments.isEmpty
                  ? Center(
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text('Tidak ada data pengiriman', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ))
                  : RefreshIndicator(
                      onRefresh: _loadShipmentsForStore,
                      color: accentOrange,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                        itemCount: _allShipments.length,
                        itemBuilder: (context, index) {
                          final shipment = _allShipments[index].data() as Map<String, dynamic>;
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'No Form: ${shipment['no_form'] ?? '-'}',
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: midnightBlue,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(4),
                                            tooltip: "Edit Shipment",
                                            icon: Icon(Icons.edit_outlined, color: Colors.blueGrey[600], size: 20),
                                            onPressed: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => EditShipmentPage(
                                                    shipmentRef: _allShipments[index].reference,
                                                  ),
                                                ),
                                              );
                                              await _loadShipmentsForStore();
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(4),
                                            tooltip: "Hapus Shipment",
                                            icon: Icon(Icons.delete_outline, color: Colors.redAccent[400], size: 20),
                                            onPressed: () async {
                                              _showDeleteConfirmationDialog(
                                                context,
                                                _allShipments[index].reference,
                                              );
                                            },
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Text('Nama Penerima: ${shipment['receiver_name'] ?? '-'}', style: TextStyle(color: Colors.grey[800])),
                                  Text('Item Total: ${shipment['item_total'] ?? '-'}', style: TextStyle(color: Colors.grey[800])),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Post Date: ${shipment['post_date'] != null ? DateFormat('dd MMM yyyy').format((shipment['post_date'] as Timestamp).toDate()) : '-'}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      TextButton(
                                        style: TextButton.styleFrom(foregroundColor: accentOrange),
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
                                        child: const Text("Lihat Detail"),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          Positioned(
            bottom: 16,
            right: 16,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Tambah Pengiriman'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddShipmentPage()),
                );
                await _loadShipmentsForStore();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentOrange,
                foregroundColor: cleanWhite,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        content: const Text('Yakin ingin menghapus pengiriman ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: cleanWhite),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
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
            final stockQuery = await FirebaseFirestore.instance.collection('warehouseStocks').where('product_ref', isEqualTo: productRef).where('warehouse_ref', isEqualTo: warehouseRef).limit(1).get();
            final productDoc = await productRef.get();
            if (productDoc.exists) {
              final productData = productDoc.data() as Map<String, dynamic>;
              final currentGlobalStock = productData['stock'] ?? 0;
              await productRef.update({'stock': currentGlobalStock + qty});
            }
            if (stockQuery.docs.isNotEmpty) {
              final stockDoc = stockQuery.docs.first;
              final currentStock = stockDoc['qty'] ?? 0;
              await stockDoc.reference.update({'qty': currentStock + qty});
            }
          }
          await doc.reference.delete();
        }
        await ref.delete();
        await _loadShipmentsForStore();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus shipment: $e')),
          );
        }
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
      final detailsSnapshot = await widget.shipmentRef.collection('details').get();
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
      appBar: AppBar(title: const Text('Detail Pengiriman'), centerTitle: true),
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
                            return Text(snapshot.data ?? 'Memuat...', style: const TextStyle(fontWeight: FontWeight.bold));
                          },
                        ),
                        trailing: Text(
                          "Qty: ${data['qty'] ?? '-'} ${data['unit_name'] ?? '-'}",
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}