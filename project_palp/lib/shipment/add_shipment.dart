import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';

class AddShipmentPage extends StatefulWidget {
  const AddShipmentPage({super.key});

  @override
  State<AddShipmentPage> createState() => _AddShipmentPageState();
}

class _AddShipmentPageState extends State<AddShipmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _formNumberController = TextEditingController();
  final _formReceiverNameController = TextEditingController();
  final _formPostDateController = TextEditingController();
  DateTime? _postDate;

  List<DocumentSnapshot> _products = [];
  List<DocumentSnapshot> _warehouses = [];

  final List<_DetailItem> _details = [];

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
    _setInitialNoForm();
  }

  Future<void> _fetchDropdownData() async {
    try {
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

      final warehouseSnap = await FirebaseFirestore.instance
          .collection('warehouses')
          .where('store_ref', isEqualTo: storeRef)
          .get();

      setState(() {
        _products = productSnap.docs;
        _warehouses = warehouseSnap.docs;
      });
    } catch (e) {
      debugPrint('Error fetching dropdown data: $e');
    }
  }

  int get itemTotal => _details.fold(0, (sum, item) => sum + item.qty);

  Future<void> _selectPostDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _postDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != _postDate) {
      setState(() {
        _postDate = picked;
      });
    }
  }

  Future<String> generateNoForm() async {
    final now = DateTime.now();
    final startOfDayLocal = DateTime(now.year, now.month, now.day);
    final endOfDayLocal = startOfDayLocal.add(Duration(days: 1));

    final startOfDayUtc = startOfDayLocal.toUtc();
    final endOfDayUtc = endOfDayLocal.toUtc();

    final snapshot = await FirebaseFirestore.instance
        .collection('salesGoodsShipment')
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDayUtc))
        .where('created_at', isLessThan: Timestamp.fromDate(endOfDayUtc))
        .get();
        
    final count = snapshot.docs.length;
    final newNumber = count + 1;
    final formattedNumber = newNumber.toString().padLeft(4, '0');

    final code = 'TPB${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}$formattedNumber';
    return code;
  }

  Future<void> _setInitialNoForm() async {
    final generatedCode = await generateNoForm();
    setState(() {
      _formNumberController.text = generatedCode;
    });
  }

  Future<void> _saveReceipt() async {
    if (!_formKey.currentState!.validate() ||
        _details.isEmpty) {
      return;
    }

    final storeCode = await StoreService.getStoreCode();
    if (storeCode == null) return;

    final storeQuery = await FirebaseFirestore.instance
        .collection('stores')
        .where('code', isEqualTo: storeCode)
        .limit(1)
        .get();

    if (storeQuery.docs.isEmpty) return;
    final storeRef = storeQuery.docs.first.reference;

    final shipment = {
      'no_form': _formNumberController.text.trim(),
      'receiver_name': _formReceiverNameController.text.trim(),
      'item_total': itemTotal,
      'post_date': _formPostDateController.text.trim(),
      'created_at': DateTime.now(),
      'store_ref': storeRef,
    };

    final shipmentDoc = await FirebaseFirestore.instance
        .collection('salesGoodsShipment')
        .add(shipment);

    for (final detail in _details) {
      await shipmentDoc.collection('details').add(detail.toMap());

      if (detail.productRef != null) {
        final productSnapshot = await detail.productRef!.get();
        final productData = productSnapshot.data() as Map<String, dynamic>?;

        if (productData != null) {
          final currentStock = productData['stock'] ?? 0;
          final updatedStock = currentStock - detail.qty;

          await detail.productRef!.update({'stock': updatedStock});
        }

        if (detail.warehouseRef != null) {
          final wsQuery = await FirebaseFirestore.instance
              .collection('warehouseStocks')
              .where('product_ref', isEqualTo: detail.productRef)
              .where('warehouse_ref', isEqualTo: detail.warehouseRef)
              .limit(1)
              .get();

          if (wsQuery.docs.isNotEmpty) {
            final wsDoc = wsQuery.docs.first;
            final wsData = wsDoc.data();
            final currentWarehouseStock = wsData['qty'] ?? 0;
            await wsDoc.reference.update({'qty': currentWarehouseStock - detail.qty});
          }
        }
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
      appBar: AppBar(title: Text('Tambah Pengiriman')),
      body: _products.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          TextFormField(
                            controller: _formNumberController,
                            decoration: InputDecoration(labelText: 'No. Form'),
                            readOnly: true,
                          ),
                          TextFormField(
                            controller: _formReceiverNameController,
                            decoration: InputDecoration(labelText: 'Nama Penerima'),
                            validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                          ),
                          GestureDetector(
                            onTap: _selectPostDate,
                            child: AbsorbPointer(
                              child: TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Tanggal Penerimaan',
                                  hintText: 'Pilih tanggal',
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                validator: (val) => _postDate == null ? 'Wajib dipilih' : null,
                                controller: TextEditingController(
                                  text: _postDate == null
                                      ? ''
                                      : "${_postDate!.day.toString().padLeft(2, '0')}-"
                                        "${_postDate!.month.toString().padLeft(2, '0')}-"
                                        "${_postDate!.year}",
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 32),
                    Expanded(
                      flex: 2,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Text('Detail Produk', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                      onChanged: (value) async {
                                        setState(() {
                                          item.productRef = value;
                                          item.unitName = 'pcs';
                                          item.availableStock = 0;
                                        });
                                        await item.fetchWarehouseStock();
                                        setState(() {});
                                      },
                                      decoration: InputDecoration(labelText: "Produk"),
                                      validator: (value) => value == null ? 'Pilih produk' : null,
                                    ),
                                    DropdownButtonFormField<DocumentReference>(
                                      value: item.warehouseRef,
                                      items: _warehouses.map((doc) {
                                        return DropdownMenuItem(
                                          value: doc.reference,
                                          child: Text(doc['name']),
                                        );
                                      }).toList(),
                                      onChanged: (value) async {
                                        setState(() {
                                          item.warehouseRef = value;
                                          item.availableStock = 0;
                                        });
                                        await item.fetchWarehouseStock();
                                        setState(() {});
                                      },
                                      decoration: InputDecoration(labelText: "Gudang Asal"),
                                      validator: (value) => value == null ? 'Pilih gudang' : null,
                                    ),
                                    TextFormField(
                                      initialValue: item.qty.toString(),
                                      decoration: InputDecoration(labelText: "Jumlah"),
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) => setState(() => item.qty = int.tryParse(val) ?? 1),
                                      validator: (val) {
                                        final qty = int.tryParse(val ?? '');
                                        if (qty == null || qty <= 0) return 'Wajib diisi dan lebih dari 0';
                                        if (qty > item.availableStock) return 'Stok tidak mencukupi';
                                        return null;
                                      },
                                    ),
                                    SizedBox(height: 8),
                                    if (item.productRef != null && item.warehouseRef != null)
                                      Text('Stok tersedia di gudang: ${item.availableStock}'),
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
                            onPressed: _saveReceipt,
                            child: Text("Simpan Shipment"),
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
  DocumentReference? warehouseRef;
  int price = 0;
  int qty = 1;
  int availableStock = 0;
  String unitName = 'unit';
  final List<DocumentSnapshot> products;

  _DetailItem({required this.products});

  int get subtotal => price * qty;

  Future<void> fetchWarehouseStock() async {
    if (productRef == null || warehouseRef == null) {
      availableStock = 0;
      return;
    }

    final wsQuery = await FirebaseFirestore.instance
        .collection('warehouseStocks')
        .where('product_ref', isEqualTo: productRef)
        .where('warehouse_ref', isEqualTo: warehouseRef)
        .limit(1)
        .get();

    if (wsQuery.docs.isNotEmpty) {
      final stock = wsQuery.docs.first['qty'] ?? 0;
      availableStock = stock;
    } else {
      availableStock = 0;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'product_ref': productRef,
      'warehouse_ref': warehouseRef,
      'qty': qty,
      'unit_name': unitName,
    };
  }
}
