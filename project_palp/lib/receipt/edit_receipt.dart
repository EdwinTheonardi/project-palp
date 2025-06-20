import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';
import 'package:intl/intl.dart';

class EditReceiptPage extends StatefulWidget {
  final DocumentReference receiptRef;
  const EditReceiptPage({super.key, required this.receiptRef});
  @override
  State<EditReceiptPage> createState() => _EditReceiptPageState();
}

class _EditReceiptPageState extends State<EditReceiptPage> {
  final _formKey = GlobalKey<FormState>();
  final _formNumberController = TextEditingController();
  DocumentReference? _selectedSupplier;
  DocumentReference? _selectedWarehouse;
  List<DocumentSnapshot> _suppliers = [];
  List<DocumentSnapshot> _warehouses = [];
  List<DocumentSnapshot> _products = [];
  final List<_DetailItem> _details = [];
  bool _loading = true;

  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final receiptSnap = await widget.receiptRef.get();
      if (!receiptSnap.exists) return;
      final receiptData = receiptSnap.data() as Map<String, dynamic>;
      final storeCode = await StoreService.getStoreCode();
      if (storeCode == null) return;
      final storeQuery = await FirebaseFirestore.instance.collection('stores').where('code', isEqualTo: storeCode).limit(1).get();
      if (storeQuery.docs.isEmpty) return;
      final storeRef = storeQuery.docs.first.reference;
      final supplierSnap = await FirebaseFirestore.instance.collection('suppliers').where('store_ref', isEqualTo: storeRef).get();
      final warehouseSnap = await FirebaseFirestore.instance.collection('warehouses').where('store_ref', isEqualTo: storeRef).get();
      final productSnap = await FirebaseFirestore.instance.collection('products').where('store_ref', isEqualTo: storeRef).get();
      final detailsSnap = await widget.receiptRef.collection('details').get();
      if (mounted) {
        setState(() {
          _formNumberController.text = receiptData['no_form'] ?? '';
          _selectedSupplier = receiptData['supplier_ref'];
          _selectedWarehouse = receiptData['warehouse_ref'];
          _suppliers = supplierSnap.docs;
          _warehouses = warehouseSnap.docs;
          _products = productSnap.docs;
          _details.clear();
          for (var doc in detailsSnap.docs) {
            final data = doc.data();
            _details.add(_DetailItem(products: _products, productRef: data['product_ref'], price: data['price'], qty: data['qty'], unitName: data['unit_name'], docId: doc.id));
          }
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading receipt data: $e');
    }
  }

  int get itemTotal => _details.fold(0, (sum, item) => sum + item.qty);
  int get grandTotal => _details.fold(0, (sum, item) => sum + item.subtotal);

  Future<void> _updateReceipt() async {
    if (!_formKey.currentState!.validate() || _selectedSupplier == null || _selectedWarehouse == null || _details.isEmpty) {
      return;
    }
    final detailCollection = widget.receiptRef.collection('details');
    final oldDetails = await detailCollection.get();
    for (var doc in oldDetails.docs) {
      final data = doc.data();
      final productRef = data['product_ref'] as DocumentReference;
      final qty = data['qty'] as int;
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final productSnap = await transaction.get(productRef);
        if (!productSnap.exists) return;
        final currentStock = productSnap.get('stock') ?? 0;
        transaction.update(productRef, {'stock': currentStock - qty});
      });
      await doc.reference.delete();
    }
    final updatedData = {
      'no_form': _formNumberController.text.trim(),
      'grandtotal': grandTotal,
      'item_total': itemTotal,
      'supplier_ref': _selectedSupplier,
      'warehouse_ref': _selectedWarehouse,
      'updated_at': DateTime.now(),
    };
    await widget.receiptRef.update(updatedData);
    for (final detail in _details) {
      await detailCollection.add(detail.toMap());
      if (detail.productRef != null) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final productSnap = await transaction.get(detail.productRef!);
          if (!productSnap.exists) return;
          final currentStock = productSnap.get('stock') ?? 0;
          transaction.update(detail.productRef!, {'stock': currentStock + detail.qty});
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

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.black.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Penerimaan'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accentOrange))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                              controller: _formNumberController,
                              decoration: _buildInputDecoration('No. Form'),
                              validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<DocumentReference>(
                              decoration: _buildInputDecoration('Supplier'),
                              value: _selectedSupplier,
                              items: _suppliers.map((doc) => DropdownMenuItem(value: doc.reference, child: Text(doc['name']))).toList(),
                              onChanged: (val) => setState(() => _selectedSupplier = val),
                              validator: (val) => val == null ? 'Wajib dipilih' : null),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<DocumentReference>(
                              decoration: _buildInputDecoration('Warehouse'),
                              value: _selectedWarehouse,
                              items: _warehouses.map((doc) => DropdownMenuItem(value: doc.reference, child: Text(doc['name']))).toList(),
                              onChanged: (val) => setState(() => _selectedWarehouse = val),
                              validator: (val) => val == null ? 'Wajib dipilih' : null),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Detail Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          ..._details.asMap().entries.map((entry) {
                            final i = entry.key;
                            final item = entry.value;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    DropdownButtonFormField<DocumentReference>(
                                        value: item.productRef,
                                        items: _products.map((doc) => DropdownMenuItem(value: doc.reference, child: Text(doc['name']))).toList(),
                                        onChanged: (value) => setState(() {
                                              item.productRef = value;
                                              item.unitName = 'pcs';
                                            }),
                                        decoration: _buildInputDecoration("Produk"),
                                        validator: (value) => value == null ? 'Pilih produk' : null),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                        initialValue: item.price.toString(),
                                        decoration: _buildInputDecoration("Harga"),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) => setState(() => item.price = int.tryParse(val) ?? 0),
                                        validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                        initialValue: item.qty.toString(),
                                        decoration: _buildInputDecoration("Jumlah"),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) => setState(() => item.qty = int.tryParse(val) ?? 1),
                                        validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 12.0),
                                        child: Text("Subtotal: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(item.subtotal)}", style: const TextStyle(fontWeight: FontWeight.w500)),
                                      ),
                                    ),
                                    TextButton.icon(
                                        onPressed: () => _removeDetail(i),
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        label: const Text("Hapus", style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          ElevatedButton.icon(
                              onPressed: _addDetail,
                              icon: const Icon(Icons.add),
                              label: const Text('Tambah Produk'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black, elevation: 0)),
                          const SizedBox(height: 16),
                          Text("Item Total: $itemTotal", style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text("Grand Total: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(grandTotal)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: midnightBlue)),
                          const SizedBox(height: 24),
                          ElevatedButton(
                              onPressed: _updateReceipt,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: accentOrange,
                                  foregroundColor: cleanWhite,
                                  padding: const EdgeInsets.symmetric(vertical: 16)),
                              child: const Text("Update Receipt")),
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
  int price;
  int qty;
  String unitName;
  String? docId;
  final List<DocumentSnapshot> products;

  _DetailItem({
    required this.products,
    this.productRef,
    this.price = 0,
    this.qty = 1,
    this.unitName = 'unit',
    this.docId,
  });

  int get subtotal => price * qty;

  Map<String, dynamic> toMap() {
    return {
      'product_ref': productRef,
      'price': price,
      'qty': qty,
      'unit_name': unitName,
      'subtotal': subtotal,
    };
  }
}