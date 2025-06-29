import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/store_service.dart';
import 'package:dropdown_search/dropdown_search.dart';

class AddInvoicePage extends StatefulWidget {
  const AddInvoicePage({super.key});

  @override
  State<AddInvoicePage> createState() => _AddInvoicePageState();
}

class _AddInvoicePageState extends State<AddInvoicePage> {
  final _formKey = GlobalKey<FormState>();
  final _formNumberController = TextEditingController();
  final _shippingCostController = TextEditingController();
  final _postDateController = TextEditingController();
  final _dueDateController = TextEditingController();

  DateTime? _postDate;
  DateTime? _dueDate;
  String? _selectedPaymentType;

  List<DocumentSnapshot> _products = [];

  final List<String> _paymentType = ['Cash', 'N/15', 'N/30', 'N/60', 'N/90'];
  final List<_DetailItem> _details = [];

  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;
  static const Color lightGray = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _setInitialNoForm();
    _fetchProducts();
    _postDate = DateTime.now();
    _updatePostDateController();
  }

  Future<void> _fetchProducts() async {
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

      if(mounted) {
        setState(() {
          _products = productSnap.docs;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dropdown data: $e');
    }
  }

  void _updatePostDateController() {
    _postDateController.text = _postDate == null
        ? ''
        : DateFormat('dd-MM-yyyy').format(_postDate!);
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
        _updateDueDate(); 
      });
    }
  }

  Future<String> generateNoForm() async {
    final now = DateTime.now();
    final startOfDayLocal = DateTime(now.year, now.month, now.day);
    final endOfDayLocal = startOfDayLocal.add(const Duration(days: 1));
    final startOfDayUtc = startOfDayLocal.toUtc();
    final endOfDayUtc = endOfDayLocal.toUtc();

    final snapshot = await FirebaseFirestore.instance
        .collection('purchaseInvoices')
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDayUtc))
        .where('created_at', isLessThan: Timestamp.fromDate(endOfDayUtc))
        .get();

    final count = snapshot.docs.length + 1;
    final code = 'FB${now.year % 100}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${count.toString().padLeft(4, '0')}';
    return code;
  }

  Future<void> _setInitialNoForm() async {
    final generatedCode = await generateNoForm();
    if(mounted) {
      setState(() {
        _formNumberController.text = generatedCode;
      });
    }
  }

  void _updateDueDate() {
    if (_postDate == null || _selectedPaymentType == null) {
      _dueDateController.clear();
      return;
    };
    int days = 0;
    switch (_selectedPaymentType) {
      case 'N/15': days = 15; break;
      case 'N/30': days = 30; break;
      case 'N/60': days = 60; break;
      case 'N/90': days = 90; break;
      default: days = 0;
    }
    _dueDate = _postDate!.add(Duration(days: days));
    _dueDateController.text = DateFormat('dd-MM-yyyy').format(_dueDate!);
  }

  int get itemTotal => _details.fold(0, (sum, item) => sum + item.qty);
  int get grandTotal => _details.fold(0, (sum, item) => sum + item.subtotal) + (int.tryParse(_shippingCostController.text) ?? 0);

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate() || _details.isEmpty || _postDate == null) return;

    final storeCode = await StoreService.getStoreCode();
    if (storeCode == null) return;

    final storeQuery = await FirebaseFirestore.instance
        .collection('stores')
        .where('code', isEqualTo: storeCode)
        .limit(1)
        .get();

    if (storeQuery.docs.isEmpty) return;
    final storeRef = storeQuery.docs.first.reference;

    final invoice = {
      'created_at': Timestamp.now(),
      'due_date': _dueDate != null ? Timestamp.fromDate(_dueDate!) : null,
      'grandtotal': grandTotal,
      'no_invoice': _formNumberController.text.trim(),
      'payment_type': _selectedPaymentType,
      'post_date': Timestamp.fromDate(_postDate!),
      'shipping_cost': int.tryParse(_shippingCostController.text) ?? 0,
      'store_ref': storeRef
    };

    final invoiceDoc = await FirebaseFirestore.instance
        .collection('purchaseInvoices')
        .add(invoice);

    for (final detail in _details) {
      await invoiceDoc.collection('details').add(detail.toMap());
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
      _details[index].dispose();
      _details.removeAt(index);
    });
  }

  @override
  void dispose() {
    _formNumberController.dispose();
    _shippingCostController.dispose();
    _dueDateController.dispose();
    _postDateController.dispose();
    for (var detail in _details) {
      detail.dispose();
    }
    super.dispose();
  }

  InputDecoration _buildInputDecoration(String label, {IconData? icon, Widget? suffixIcon}) {
    return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: midnightBlue.withOpacity(0.8)),
        prefixIcon: icon != null ? Icon(icon, color: midnightBlue.withOpacity(0.7), size: 20) : null,
        suffixIcon: suffixIcon,
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
        title: const Text('Tambah Invoice'),
        centerTitle: true,
        backgroundColor: midnightBlue,
        foregroundColor: cleanWhite,
        elevation: 0,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.save_alt_outlined),
          label: const Text("Simpan Invoice", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          onPressed: _saveInvoice,
          style: ElevatedButton.styleFrom(
            backgroundColor: accentOrange,
            foregroundColor: cleanWhite,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      body: _products.isEmpty
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
                  children: [
                    TextFormField(
                      controller: _formNumberController,
                      readOnly: true,
                      decoration: _buildInputDecoration('No. Faktur', icon: Icons.numbers_outlined),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _selectPostDate,
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _postDateController,
                          decoration: _buildInputDecoration('Tanggal Faktur', icon: Icons.calendar_today_outlined),
                          validator: (_) => _postDate == null ? 'Wajib dipilih' : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: _buildInputDecoration('Tipe Pembayaran', icon: Icons.payment_outlined),
                      value: _selectedPaymentType,
                      items: _paymentType.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPaymentType = val;
                          _updateDueDate();
                        });
                      },
                      validator: (val) => val == null ? 'Pilih salah satu' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dueDateController,
                      readOnly: true,
                      decoration: _buildInputDecoration('Jatuh Tempo', icon: Icons.event_busy_outlined),
                    ),
                     const SizedBox(height: 16),
                    TextFormField(
                      controller: _shippingCostController,
                      decoration: _buildInputDecoration('Biaya Pengiriman', icon: Icons.local_shipping_outlined),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState((){}), 
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
                           containerBuilder: (ctx, popupWidget) => Material(elevation: 8, borderRadius: BorderRadius.circular(12), color: cleanWhite, child: popupWidget),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: item.priceController,
                        decoration: _buildInputDecoration("Harga"),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => setState(() => item.price = int.tryParse(val) ?? 0),
                        validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: item.qtyController,
                        decoration: _buildInputDecoration("Jumlah"),
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

  void dispose() {
    priceController.dispose();
    qtyController.dispose();
  }
}