import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
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
  final _postDateController = TextEditingController();

  DocumentReference? _selectedSupplier;
  DocumentReference? _selectedWarehouse;
  List<DocumentSnapshot> _suppliers = [];
  List<DocumentSnapshot> _warehouses = [];
  List<DocumentSnapshot> _products = [];

  final List<_DetailItem> _details = [];

  bool _loading = true;
  DateTime? _postDate;

  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;
  static const Color lightGray = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _formNumberController.dispose();
    _postDateController.dispose();
    for (var detail in _details) {
      detail.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final receiptSnap = await widget.receiptRef.get();
      if (!receiptSnap.exists) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final receiptData = receiptSnap.data() as Map<String, dynamic>;
      final storeCode = await StoreService.getStoreCode();
      if (storeCode == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final storeQuery = await FirebaseFirestore.instance.collection('stores').where('code', isEqualTo: storeCode).limit(1).get();
      if (storeQuery.docs.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
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
          _postDate = (receiptData['post_date'] as Timestamp).toDate();
          _postDateController.text = DateFormat('dd-MM-yyyy').format(_postDate!);
          _suppliers = supplierSnap.docs;
          _warehouses = warehouseSnap.docs;
          _products = productSnap.docs;
          _details.clear();
          for (var doc in detailsSnap.docs) {
            final data = doc.data();
            _details.add(_DetailItem(
              products: _products,
              productRef: data['product_ref'],
              price: data['price'],
              qty: data['qty'],
              unitName: data['unit_name'],
              docId: doc.id,
            ));
          }
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading receipt data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
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
            colorScheme: const ColorScheme.light(primary: accentOrange, onPrimary: cleanWhite, onSurface: midnightBlue),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _postDate = picked;
        _postDateController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  Future<void> _updateReceipt() async {
    if (!_formKey.currentState!.validate() || _selectedSupplier == null || _selectedWarehouse == null || _details.isEmpty || _postDate == null) {
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
      'post_date': Timestamp.fromDate(_postDate!),
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: midnightBlue.withOpacity(0.8)),
        filled: true,
        fillColor: Colors.black.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentOrange))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        title: const Text('Edit Penerimaan'),
        centerTitle: true,
        backgroundColor: midnightBlue,
        foregroundColor: cleanWhite,
        elevation: 0,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.save_as_outlined),
          label: const Text("Update Penerimaan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          onPressed: _updateReceipt,
          style: ElevatedButton.styleFrom(
            backgroundColor: accentOrange,
            foregroundColor: cleanWhite,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accentOrange))
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              color: cleanWhite,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _formNumberController,
                      decoration: _inputDecoration('No. Form'),
                      validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _selectPostDate,
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _postDateController,
                          decoration: _inputDecoration('Tanggal Penerimaan').copyWith(suffixIcon: const Icon(Icons.calendar_today, color: midnightBlue)),
                          validator: (val) => val == null || val.isEmpty ? 'Wajib dipilih' : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownSearch<DocumentSnapshot>(
                      items: _suppliers,
                      itemAsString: (doc) => doc['name'],
                      selectedItem: _suppliers.any((doc) => doc.reference == _selectedSupplier) ? _suppliers.firstWhere((doc) => doc.reference == _selectedSupplier) : null,
                      dropdownDecoratorProps: DropDownDecoratorProps(
                        dropdownSearchDecoration: _inputDecoration('Supplier'),
                      ),
                      onChanged: (doc) => setState(() => _selectedSupplier = doc?.reference),
                      validator: (val) => val == null ? 'Wajib dipilih' : null,
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(decoration: _inputDecoration('Cari supplier...')),
                        containerBuilder: (ctx, popupWidget) => Material(elevation: 8, borderRadius: BorderRadius.circular(12), color: cleanWhite, child: popupWidget),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownSearch<DocumentSnapshot>(
                      items: _warehouses,
                      itemAsString: (doc) => doc['name'],
                      selectedItem: _warehouses.any((doc) => doc.reference == _selectedWarehouse) ? _warehouses.firstWhere((doc) => doc.reference == _selectedWarehouse) : null,
                      dropdownDecoratorProps: DropDownDecoratorProps(
                        dropdownSearchDecoration: _inputDecoration('Warehouse'),
                      ),
                      onChanged: (doc) => setState(() => _selectedWarehouse = doc?.reference),
                      validator: (val) => val == null ? 'Wajib dipilih' : null,
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(decoration: _inputDecoration('Cari warehouse...')),
                        containerBuilder: (ctx, popupWidget) => Material(elevation: 8, borderRadius: BorderRadius.circular(12), color: cleanWhite, child: popupWidget),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text('Detail Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: midnightBlue)),
            const SizedBox(height: 4),

            ..._details.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Card(
                color: cleanWhite,
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      DropdownSearch<DocumentReference>(
                        items: _products.map((doc) => doc.reference).toList(),
                        selectedItem: item.productRef,
                        itemAsString: (ref) {
                          final product = _products.where((doc) => doc.reference == ref);
                          return product.isNotEmpty ? product.first['name'] : '';
                        },
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration: _inputDecoration('Produk'),
                        ),
                        onChanged: (ref) {
                          setState(() {
                            item.productRef = ref;
                            item.unitName = 'pcs';
                          });
                        },
                        validator: (val) => val == null ? 'Pilih produk' : null,
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(decoration: _inputDecoration('Cari produk...')),
                          containerBuilder: (ctx, popupWidget) => Material(elevation: 8, borderRadius: BorderRadius.circular(12), color: cleanWhite, child: popupWidget),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: item.priceController,
                        decoration: _inputDecoration("Harga"),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => setState(() => item.price = int.tryParse(val) ?? 0),
                        validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: item.qtyController,
                        decoration: _inputDecoration("Jumlah"),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => setState(() => item.qty = int.tryParse(val) ?? 1),
                        validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 12.0),
                            child: Text("Subtotal: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(item.subtotal)}",
                                style: const TextStyle(fontWeight: FontWeight.w600, color: midnightBlue)),
                          ),
                          TextButton.icon(
                            onPressed: () => _removeDetail(i),
                            icon: Icon(Icons.delete_outline, color: Colors.redAccent.shade400, size: 20),
                            label: Text("Hapus", style: TextStyle(color: Colors.redAccent.shade400)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addDetail,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Produk'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accentOrange,
                side: const BorderSide(color: accentOrange),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
             const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: Text("Grand Total: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(grandTotal)}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: midnightBlue)),
            ),
          ],
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
  final TextEditingController priceController;
  final TextEditingController qtyController;

  _DetailItem({
    required this.products,
    this.productRef,
    this.price = 0,
    this.qty = 1,
    this.unitName = 'unit',
    this.docId,
  })  : priceController = TextEditingController(text: price.toString()),
        qtyController = TextEditingController(text: qty.toString());

  void dispose() {
    priceController.dispose();
    qtyController.dispose();
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