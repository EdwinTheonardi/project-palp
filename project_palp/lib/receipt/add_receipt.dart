import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';

class AddReceiptPage extends StatefulWidget {
  const AddReceiptPage({super.key});

  @override
  State<AddReceiptPage> createState() => _AddReceiptPageState();
}

class _AddReceiptPageState extends State<AddReceiptPage> {
  final _formKey = GlobalKey<FormState>();
  final _formNumberController = TextEditingController();
  final _postDateController = TextEditingController();
  DateTime? _postDate;
  DocumentReference? _selectedSupplier;
  DocumentReference? _selectedWarehouse;
  DocumentReference? _selectedInvoice;
  DocumentSnapshot? _selectedInvoiceDoc;
  List<DocumentSnapshot> _suppliers = [];
  List<DocumentSnapshot> _warehouses = [];
  List<DocumentSnapshot> _invoices = [];
  List<DocumentSnapshot> _products = [];
  final List<_DetailItem> _details = [];
  bool _isLoading = true;

  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;
  static const Color lightGray = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
    _setInitialNoForm();
    _postDate = DateTime.now();
    _updatePostDateController();
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
      final invoiceSnap = await FirebaseFirestore.instance.collection('purchaseInvoices').where('store_ref', isEqualTo: storeRef).get();
      final productSnap = await FirebaseFirestore.instance.collection('products').where('store_ref', isEqualTo: storeRef).get();
      if (mounted) {
        setState(() {
          _suppliers = supplierSnap.docs;
          _warehouses = warehouseSnap.docs;
          _invoices = invoiceSnap.docs;
          _products = productSnap.docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dropdown data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int get itemTotal => _details.fold(0, (sum, item) => sum + item.qty);
  int get grandTotal => _details.fold(0, (sum, item) => sum + item.subtotal);

  void _updatePostDateController() {
    _postDateController.text = _postDate == null ? '' : DateFormat('dd-MM-yyyy').format(_postDate!);
  }

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
        _updatePostDateController();
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
    final code = 'TTB${now.year % 100}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}$formattedNumber';
    return code;
  }

  Future<void> _setInitialNoForm() async {
    final generatedCode = await generateNoForm();
    if (mounted) {
      setState(() {
        _formNumberController.text = generatedCode;
      });
    }
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
      'invoice_ref': _selectedInvoice,
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

  InputDecoration _buildInputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: midnightBlue.withOpacity(0.8)),
        prefixIcon: icon != null ? Icon(icon, color: midnightBlue.withOpacity(0.7)) : null,
        filled: true,
        fillColor: Colors.black.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentOrange))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        title: const Text('Tambah Penerimaan'),
        centerTitle: true,
        backgroundColor: midnightBlue,
        foregroundColor: cleanWhite,
        elevation: 0,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.save_alt_outlined),
          label: const Text("Simpan Penerimaan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          onPressed: _saveReceipt,
          style: ElevatedButton.styleFrom(
            backgroundColor: accentOrange,
            foregroundColor: cleanWhite,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      body: _isLoading
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
                    TextFormField(controller: _formNumberController, decoration: _buildInputDecoration('No. Form', icon: Icons.article_outlined), readOnly: true),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _selectPostDate,
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _postDateController,
                          decoration: _buildInputDecoration('Tanggal Penerimaan').copyWith(suffixIcon: const Icon(Icons.calendar_today, color: midnightBlue)),
                          validator: (val) => _postDate == null ? 'Wajib dipilih' : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownSearch<DocumentSnapshot>(
                      items: _suppliers,
                      itemAsString: (doc) => doc['name'],
                      selectedItem: _suppliers.any((doc) => doc.reference == _selectedSupplier) ? _suppliers.firstWhere((doc) => doc.reference == _selectedSupplier) : null,
                      dropdownDecoratorProps: DropDownDecoratorProps(dropdownSearchDecoration: _buildInputDecoration('Supplier', icon: Icons.people_alt_outlined)),
                      onChanged: (doc) => setState(() => _selectedSupplier = doc?.reference),
                      validator: (val) => val == null ? 'Wajib dipilih' : null,
                      popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(decoration: _buildInputDecoration('Cari supplier...')),
                          containerBuilder: (ctx, popupWidget) => Material(elevation: 8, borderRadius: BorderRadius.circular(12), color: cleanWhite, child: popupWidget)),
                    ),
                    const SizedBox(height: 16),
                    DropdownSearch<DocumentSnapshot>(
                        items: _warehouses,
                        itemAsString: (doc) => doc['name'],
                        selectedItem: _warehouses.any((doc) => doc.reference == _selectedWarehouse) ? _warehouses.firstWhere((doc) => doc.reference == _selectedWarehouse) : null,
                        dropdownDecoratorProps: DropDownDecoratorProps(dropdownSearchDecoration: _buildInputDecoration('Warehouse', icon: Icons.warehouse_outlined)),
                        onChanged: (doc) => setState(() => _selectedWarehouse = doc?.reference),
                        validator: (val) => val == null ? 'Wajib dipilih' : null,
                        popupProps: PopupProps.menu(
                            showSearchBox: true,
                            searchFieldProps: TextFieldProps(decoration: _buildInputDecoration('Cari warehouse...')),
                            containerBuilder: (ctx, popupWidget) => Material(elevation: 8, borderRadius: BorderRadius.circular(12), color: cleanWhite, child: popupWidget))
                    ),
                    const SizedBox(height: 16),
                    DropdownSearch<DocumentSnapshot>(
                      items: _invoices,
                      itemAsString: (doc) => doc['no_invoice'],
                      selectedItem: _selectedInvoiceDoc,
                      dropdownDecoratorProps: DropDownDecoratorProps(dropdownSearchDecoration: _buildInputDecoration('No. Invoice (Opsional)', icon: Icons.receipt_long_outlined)),
                      onChanged: (doc) async {
                        if (doc == null) return;
                        setState(() {
                          _selectedInvoiceDoc = doc;
                          _selectedInvoice = doc.reference;
                          _details.clear();
                        });
                        final invoiceDetailsSnap = await doc.reference.collection('details').get();
                        final newDetails = invoiceDetailsSnap.docs.map((detailDoc) {
                          final data = detailDoc.data();
                          final detailItem = _DetailItem(products: _products)
                            ..productRef = data['product_ref'] as DocumentReference?
                            ..price = data['price'] ?? 0
                            ..qty = data['qty'] ?? 1
                            ..unitName = data['unit_name'] ?? 'unit'
                            ..priceController.text = (data['price'] ?? 0).toString()
                            ..qtyController.text = (data['qty'] ?? 1).toString();
                          return detailItem;
                        }).toList();
                        setState(() => _details.addAll(newDetails));
                      },
                      popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(decoration: _buildInputDecoration('Cari invoice...')),
                          containerBuilder: (ctx, popupWidget) => Material(elevation: 8, borderRadius: BorderRadius.circular(12), color: cleanWhite, child: popupWidget)),
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
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      DropdownSearch<DocumentReference>(
                        items: _products.map((doc) => doc.reference).toList(),
                        selectedItem: item.productRef,
                        itemAsString: (ref) {
                          final found = _products.where((doc) => doc.reference == ref);
                          return found.isNotEmpty ? found.first['name'] : '';
                        },
                        dropdownDecoratorProps: DropDownDecoratorProps(dropdownSearchDecoration: _buildInputDecoration("Produk")),
                        onChanged: (ref) {
                          setState(() {
                            item.productRef = ref;
                            item.updatePriceFromProduct();
                            item.unitName = 'pcs';
                          });
                        },
                        validator: (val) => val == null ? 'Pilih produk' : null,
                        popupProps: PopupProps.menu(
                            showSearchBox: true,
                            searchFieldProps: TextFieldProps(decoration: _buildInputDecoration('Cari produk...')),
                            containerBuilder: (ctx, popupWidget) => Material(elevation: 8, borderRadius: BorderRadius.circular(12), color: cleanWhite, child: popupWidget)),
                      ),
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
  int price = 0;
  int qty = 1;
  String unitName = 'unit';
  final List<DocumentSnapshot> products;
  final TextEditingController priceController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');

  _DetailItem({required this.products});

  void updatePriceFromProduct() {
    if (productRef == null) return;
    final productDoc = products.firstWhere((doc) => doc.reference == productRef, orElse: () => products.first);
    final data = productDoc.data() as Map<String, dynamic>;
    price = data['price'] ?? 0;
    priceController.text = price.toString();
  }

  int get subtotal => price * qty;

  Map<String, dynamic> toMap() {
    return {'product_ref': productRef, 'price': price, 'qty': qty, 'unit_name': unitName, 'subtotal': subtotal};
  }
}