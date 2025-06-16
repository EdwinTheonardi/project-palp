import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';
import 'package:intl/intl.dart';

class AddReceiptPage extends StatefulWidget {
  const AddReceiptPage({super.key});

  @override
  State<AddReceiptPage> createState() => _AddReceiptPageState();
}

class _AddReceiptPageState extends State<AddReceiptPage> {
  final _formKey = GlobalKey<FormState>();
  final _formNumberController = TextEditingController();
  DateTime? _postDate;
  DocumentReference? _selectedSupplier;
  DocumentReference? _selectedWarehouse;
  List<DocumentSnapshot> _suppliers = [];
  List<DocumentSnapshot> _warehouses = [];
  List<DocumentSnapshot> _products = [];
  final List<_DetailItem> _details = [];

  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;

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
      final storeQuery = await FirebaseFirestore.instance.collection('stores').where('code', isEqualTo: storeCode).limit(1).get();
      if (storeQuery.docs.isEmpty) return;
      final storeRef = storeQuery.docs.first.reference;
      final supplierSnap = await FirebaseFirestore.instance.collection('suppliers').where('store_ref', isEqualTo: storeRef).get();
      final warehouseSnap = await FirebaseFirestore.instance.collection('warehouses').where('store_ref', isEqualTo: storeRef).get();
      final productSnap = await FirebaseFirestore.instance.collection('products').where('store_ref', isEqualTo: storeRef).get();
      if (mounted) {
        setState(() {
          _suppliers = supplierSnap.docs;
          _warehouses = warehouseSnap.docs;
          _products = productSnap.docs;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dropdown data: $e');
    }
  }

  int get itemTotal => _details.fold(0, (sum, item) => sum + item.qty);
  int get grandTotal => _details.fold(0, (sum, item) => sum + item.subtotal);

  Future<void> _selectPostDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _postDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: midnightBlue, onPrimary: cleanWhite, onSurface: midnightBlue),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
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
    final endOfDayLocal = startOfDayLocal.add(const Duration(days: 1));
    final startOfDayUtc = startOfDayLocal.toUtc();
    final endOfDayUtc = endOfDayLocal.toUtc();
    final snapshot = await FirebaseFirestore.instance.collection('purchaseGoodsReceipts').where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDayUtc)).where('created_at', isLessThan: Timestamp.fromDate(endOfDayUtc)).get();
    final count = snapshot.docs.length;
    final newNumber = count + 1;
    final formattedNumber = newNumber.toString().padLeft(4, '0');
    final code = 'TTB${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}$formattedNumber';
    return code;
  }

  Future<void> _setInitialNoForm() async {
    final generatedCode = await generateNoForm();
    setState(() {
      _formNumberController.text = generatedCode;
    });
  }

  Future<void> _saveReceipt() async {
    if (!_formKey.currentState!.validate() || _selectedSupplier == null || _selectedWarehouse == null || _details.isEmpty || _postDate == null) {
      return;
    }
    final storeCode = await StoreService.getStoreCode();
    if (storeCode == null) return;
    final storeQuery = await FirebaseFirestore.instance.collection('stores').where('code', isEqualTo: storeCode).limit(1).get();
    if (storeQuery.docs.isEmpty) return;
    final storeRef = storeQuery.docs.first.reference;
    final receipt = {
      'no_form': _formNumberController.text.trim(),
      'grandtotal': grandTotal,
      'item_total': itemTotal,
      'post_date': Timestamp.fromDate(_postDate!),
      'created_at': Timestamp.now(),
      'store_ref': storeRef,
      'supplier_ref': _selectedSupplier,
      'warehouse_ref': _selectedWarehouse,
      'synced': true,
    };
    final receiptDoc = await FirebaseFirestore.instance.collection('purchaseGoodsReceipts').add(receipt);
    for (final detail in _details) {
      await receiptDoc.collection('details').add(detail.toMap());
      if (detail.productRef != null) {
        final productSnapshot = await detail.productRef!.get();
        final productData = productSnapshot.data() as Map<String, dynamic>?;
        if (productData != null) {
          final currentStock = productData['stock'] ?? 0;
          final updatedStock = currentStock + detail.qty;
          await detail.productRef!.update({'stock': updatedStock});
        }
        final warehouseStockQuery = await FirebaseFirestore.instance.collection('warehouseStocks').where('product_ref', isEqualTo: detail.productRef).where('warehouse_ref', isEqualTo: _selectedWarehouse).where('store_ref', isEqualTo: storeRef).limit(1).get();
        if (warehouseStockQuery.docs.isEmpty) {
          await FirebaseFirestore.instance.collection('warehouseStocks').add({
            'product_ref': detail.productRef,
            'warehouse_ref': _selectedWarehouse,
            'store_ref': storeRef,
            'qty': detail.qty,
            'last_updated_at': Timestamp.now(),
          });
        } else {
          final doc = warehouseStockQuery.docs.first;
          final currentQty = (doc.data()['qty'] ?? 0) as int;
          await doc.reference.update({
            'qty': currentQty + detail.qty,
            'last_updated_at': Timestamp.now(),
          });
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
      appBar: AppBar(title: const Text('Tambah Penerimaan'), centerTitle: true),
      body: _products.isEmpty
          ? const Center(child: CircularProgressIndicator(color: accentOrange))
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
                          TextFormField(controller: _formNumberController, decoration: _buildInputDecoration('No. Form'), readOnly: true),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<DocumentReference>(
                              decoration: _buildInputDecoration('Supplier'),
                              items: _suppliers.map((doc) => DropdownMenuItem(value: doc.reference, child: Text(doc['name']))).toList(),
                              onChanged: (val) => setState(() => _selectedSupplier = val),
                              validator: (val) => val == null ? 'Wajib dipilih' : null),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<DocumentReference>(
                              decoration: _buildInputDecoration('Warehouse'),
                              items: _warehouses.map((doc) => DropdownMenuItem(value: doc.reference, child: Text(doc['name']))).toList(),
                              onChanged: (val) => setState(() => _selectedWarehouse = val),
                              validator: (val) => val == null ? 'Wajib dipilih' : null),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _selectPostDate,
                            child: AbsorbPointer(
                              child: TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Tanggal Penerimaan',
                                  filled: true,
                                  fillColor: Colors.black.withOpacity(0.05),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  suffixIcon: const Icon(Icons.calendar_today),
                                ),
                                validator: (val) => _postDate == null ? 'Wajib dipilih' : null,
                                controller: TextEditingController(text: _postDate == null ? '' : DateFormat('dd MMMM yyyy').format(_postDate!)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 2,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          const Text('Detail Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                                              item.updatePriceFromProduct();
                                              item.unitName = 'pcs';
                                            }),
                                        decoration: _buildInputDecoration("Produk"),
                                        validator: (value) => value == null ? 'Pilih produk' : null),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                        controller: item.priceController,
                                        decoration: _buildInputDecoration("Harga"),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) => setState(() => item.price = int.tryParse(val) ?? 0),
                                        validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                        controller: item.qtyController,
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
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      label: const Text("Hapus", style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _addDetail,
                            icon: const Icon(Icons.add),
                            label: const Text('Tambah Produk'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text("Item Total: $itemTotal", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("Grand Total: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(grandTotal)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: midnightBlue)),
                          const SizedBox(height: 24),
                          ElevatedButton(
                              onPressed: _saveReceipt,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: accentOrange,
                                  foregroundColor: cleanWhite,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: const Text("Simpan Receipt")),
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
  int price = 0;
  int qty = 1;
  String unitName = 'unit';
  final List<DocumentSnapshot> products;
  final TextEditingController priceController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');

  _DetailItem({required this.products});

  void updatePriceFromProduct() {
    if (productRef == null) return;
    final productDoc = products.firstWhere((doc) => doc.reference == productRef);
    final data = productDoc.data() as Map<String, dynamic>;
    price = data['price'] ?? 0;
    priceController.text = price.toString();
  }

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