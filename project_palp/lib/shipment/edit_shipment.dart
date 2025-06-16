import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';

class EditShipmentPage extends StatefulWidget {
  final DocumentReference shipmentRef;

  const EditShipmentPage({super.key, required this.shipmentRef});

  @override
  State<EditShipmentPage> createState() => _EditShipmentPageState();
}

class _EditShipmentPageState extends State<EditShipmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _formNumberController = TextEditingController();
  final _formReceiverNameController = TextEditingController();
  final _formPostDateController = TextEditingController();

  List<DocumentSnapshot> _products = [];

  final List<_DetailItem> _details = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final shipmentSnap = await widget.shipmentRef.get();
      if (!shipmentSnap.exists) return;

      final shipmentData = shipmentSnap.data() as Map<String, dynamic>;

      final storeCode = await StoreService.getStoreCode();
      if (storeCode == null) return;

      final storeQuery = await FirebaseFirestore.instance
          .collection('stores')
          .where('code', isEqualTo: storeCode)
          .limit(1)
          .get();

      if (storeQuery.docs.isEmpty) return;
      final storeRef = storeQuery.docs.first.reference;

      final productSnap = await FirebaseFirestore.instance
          .collection('products')
          .where('store_ref', isEqualTo: storeRef)
          .get();

      final detailsSnap = await widget.shipmentRef.collection('details').get();

      setState(() {
        _formNumberController.text = shipmentData['no_form'] ?? '';
        _formReceiverNameController.text = shipmentData['receiver_name'] ?? '';
        _formPostDateController.text = shipmentData['post_date'] ?? '';
        _products = productSnap.docs;

        _details.clear();
        for (var doc in detailsSnap.docs) {
          final data = doc.data();
          _details.add(_DetailItem(
            products: _products,
            productRef: data['product_ref'],
            qty: data['qty'],
            unitName: data['unit_name'],
            docId: doc.id,
          ));
        }

        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading receipt data: $e');
    }
  }

  int get itemTotal => _details.fold(0, (sum, item) => sum + item.qty);

  Future<void> _updateShipment() async {
    if (!_formKey.currentState!.validate() ||
        _details.isEmpty) {
      return;
    }

    final detailCollection = widget.shipmentRef.collection('details');

    final oldDetails = await detailCollection.get();
    for (var doc in oldDetails.docs) {
      final data = doc.data();
      final productRef = data['product_ref'] as DocumentReference;
      final qty = data['qty'] as int;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final productSnap = await transaction.get(productRef);
        if (!productSnap.exists) return;

        final currentStock = productSnap.get('stock') ?? 0;
        transaction.update(productRef, {
          'stock': currentStock + qty,
        });
      });

      await doc.reference.delete();
    }

    final updatedData = {
      'no_form': _formNumberController.text.trim(),
      'receiver_name': _formReceiverNameController.text.trim(),
      'post_date': _formPostDateController.text.trim(),
      'item_total': itemTotal,
      'updated_at': DateTime.now(),
    };

    await widget.shipmentRef.update(updatedData);

    for (final detail in _details) {
      await detailCollection.add(detail.toMap());

      if (detail.productRef != null) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final productSnap = await transaction.get(detail.productRef!);
          if (!productSnap.exists) return;

          final currentStock = productSnap.get('stock') ?? 0;
          transaction.update(detail.productRef!, {
            'stock': currentStock - detail.qty,
          });
        });
      }
    }

    if (mounted) Navigator.pop(context);
  }

  void _addDetail() {
    setState(() {
      _details.add(_DetailItem(products: _products));
    });
  }

  void _removeDetail(int index) {
    setState(() {
      _details.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Pengiriman')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KIRI
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _formNumberController,
                            decoration: InputDecoration(labelText: 'No. Form'),
                            validator: (val) =>
                                val == null || val.isEmpty ? 'Wajib diisi' : null,
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _formReceiverNameController,
                            decoration: InputDecoration(labelText: 'Nama Penerima'),
                            validator: (val) =>
                                val == null || val.isEmpty ? 'Wajib diisi' : null,
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _formPostDateController,
                            decoration: InputDecoration(labelText: 'Tanggal'),
                            validator: (val) =>
                                val == null || val.isEmpty ? 'Wajib diisi' : null,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 24),
                    // KANAN
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Detail Produk',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          ..._details.asMap().entries.map((entry) {
                            final i = entry.key;
                            final item = entry.value;

                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    DropdownButtonFormField<DocumentReference>(
                                      value: item.productRef,
                                      items: _products.map((doc) {
                                        return DropdownMenuItem(
                                          value: doc.reference,
                                          child: Text(doc['name']),
                                        );
                                      }).toList(),
                                      onChanged: (value) => setState(() {
                                        item.productRef = value;
                                        item.unitName = 'pcs';
                                      }),
                                      decoration:
                                          InputDecoration(labelText: "Produk"),
                                      validator: (value) =>
                                          value == null ? 'Pilih produk' : null,
                                    ),
                                    TextFormField(
                                      initialValue: item.qty.toString(),
                                      decoration:
                                          InputDecoration(labelText: "Jumlah"),
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) => setState(() =>
                                          item.qty = int.tryParse(val) ?? 1),
                                      validator: (val) => val == null ||
                                              val.isEmpty
                                          ? 'Wajib diisi'
                                          : null,
                                    ),
                                    SizedBox(height: 8),
                                    Text("Satuan: ${item.unitName}"),
                                    TextButton.icon(
                                      onPressed: () => _removeDetail(i),
                                      icon: Icon(Icons.delete, color: Colors.red),
                                      label: Text("Hapus"),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          ElevatedButton.icon(
                            onPressed: _addDetail,
                            icon: Icon(Icons.add),
                            label: Text('Tambah Produk'),
                          ),
                          SizedBox(height: 16),
                          Text("Item Total: $itemTotal"),
                          SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _updateShipment,
                            child: Text("Update Shipment"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DetailItem {
  DocumentReference? productRef;
  int qty;
  String unitName;
  String? docId;
  final List<DocumentSnapshot> products;

  _DetailItem({
    required this.products,
    this.productRef,
    this.qty = 1,
    this.unitName = 'unit',
    this.docId,
  });

  Map<String, dynamic> toMap() {
    return {
      'product_ref': productRef,
      'qty': qty,
      'unit_name': unitName,
    };
  }
}
