import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/store_service.dart';
import 'package:dropdown_search/dropdown_search.dart';

class EditInvoicePage extends StatefulWidget {
  final DocumentReference invoiceRef;

  const EditInvoicePage({super.key, required this.invoiceRef});

  @override
  State<EditInvoicePage> createState() => _EditInvoicePageState();
}

class _EditInvoicePageState extends State<EditInvoicePage> {
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

  bool _loading = true;
  
  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;
  static const Color lightGray = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final invoiceSnap = await widget.invoiceRef.get();
      if (!invoiceSnap.exists) {
         if (mounted) setState(() => _loading = false);
        return;
      }
      final invoiceData = invoiceSnap.data() as Map<String, dynamic>;

      final storeCode = await StoreService.getStoreCode();
      if (storeCode == null) {
         if (mounted) setState(() => _loading = false);
        return;
      }

      final storeQuery = await FirebaseFirestore.instance
          .collection('stores')
          .where('code', isEqualTo: storeCode)
          .limit(1)
          .get();
      if (storeQuery.docs.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final storeRef = storeQuery.docs.first.reference;

      final productSnap = await FirebaseFirestore.instance
          .collection('products')
          .where('store_ref', isEqualTo: storeRef)
          .get();

      final detailsSnap = await widget.invoiceRef.collection('details').get();

      if(mounted) {
        setState(() {
          _formNumberController.text = invoiceData['invoice_number'] ?? '';
          _shippingCostController.text = (invoiceData['shipping_cost'] ?? 0).toString();
          _selectedPaymentType = invoiceData['payment_type'];
          _postDate = (invoiceData['post_date'] as Timestamp).toDate();
          _postDateController.text = DateFormat('dd-MM-yyyy').format(_postDate!);
          
          if(invoiceData['due_date'] != null) {
            _dueDate = (invoiceData['due_date'] as Timestamp).toDate();
            _dueDateController.text = DateFormat('dd-MM-yyyy').format(_dueDate!);
          }

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
      debugPrint('Error loading invoice: $e');
      if(mounted) setState(() => _loading = false);
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
        _updateDueDate();
      });
    }
  }

  int get itemTotal => _details.fold(0, (sum, item) => sum + item.qty);
  int get grandTotal => _details.fold(0, (sum, item) => sum + item.subtotal) + (int.tryParse(_shippingCostController.text) ?? 0);

  Future<void> _updateInvoice() async {
    if (!_formKey.currentState!.validate() || _details.isEmpty || _postDate == null) return;

    final detailCollection = widget.invoiceRef.collection('details');

    final oldDetails = await detailCollection.get();
    for (var doc in oldDetails.docs) {
      await doc.reference.delete();
    }

    final updatedData = {
      'invoice_number': _formNumberController.text.trim(),
      'grandtotal': grandTotal,
      'item_total': itemTotal,
      'payment_type': _selectedPaymentType,
      'post_date': Timestamp.fromDate(_postDate!),
      'due_date': _dueDate != null ? Timestamp.fromDate(_dueDate!) : null,
      'shipping_cost': int.tryParse(_shippingCostController.text) ?? 0,
      'updated_at': DateTime.now(),
    };

    await widget.invoiceRef.update(updatedData);

    for (final detail in _details) {
      await detailCollection.add(detail.toMap());
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
    _postDateController.dispose();
    _dueDateController.dispose();
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
        title: const Text('Edit Invoice'),
        centerTitle: true,
        backgroundColor: midnightBlue,
        foregroundColor: cleanWhite,
        elevation: 0,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.save_as_outlined),
          label: const Text("Update Invoice", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          onPressed: _updateInvoice,
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
                      validator: (val) => val == null ? 'Wajib dipilih' : null,
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

  void updatePriceFromProduct() {
    if (productRef == null) return;
    final productDoc = products.firstWhere((doc) => doc.reference == productRef);
    final data = productDoc.data() as Map<String, dynamic>;
    price = data['price'] ?? 0;
    priceController.text = price.toString();
  }

  void dispose() {
    priceController.dispose();
    qtyController.dispose();
  }
}