import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/store_service.dart';
import 'package:dropdown_search/dropdown_search.dart';

class AddShipmentPage extends StatefulWidget {
  const AddShipmentPage({super.key});

  @override
  State<AddShipmentPage> createState() => _AddShipmentPageState();
}

class _AddShipmentPageState extends State<AddShipmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _formNumberController = TextEditingController();
  final _formReceiverNameController = TextEditingController();
  final _postDateController = TextEditingController();
  DateTime? _postDate;
  List<DocumentSnapshot> _products = [];
  List<DocumentSnapshot> _warehouses = [];
  final List<_DetailItem> _details = [];
  bool _isLoading = true;

  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await _fetchDropdownData();
    await _setInitialNoForm();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _postDate = DateTime.now();
        _updatePostDateController();
        if (_products.isNotEmpty) {
          _addDetail();
        }
      });
    }
  }

  Future<void> _fetchDropdownData() async {
    try {
      final storeCode = await StoreService.getStoreCode();
      if (storeCode == null) return;
      final storeQuery = await FirebaseFirestore.instance.collection('stores').where('code', isEqualTo: storeCode).limit(1).get();
      if (storeQuery.docs.isEmpty) return;
      final storeRef = storeQuery.docs.first.reference;
      final productSnap = await FirebaseFirestore.instance.collection('products').where('store_ref', isEqualTo: storeRef).get();
      final warehouseSnap = await FirebaseFirestore.instance.collection('warehouses').where('store_ref', isEqualTo: storeRef).get();
      if (mounted) {
        setState(() {
          _products = productSnap.docs;
          _warehouses = warehouseSnap.docs;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dropdown data: $e');
    }
  }

  int get itemTotal => _details.fold(0, (sum, item) => sum + item.qty);

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
            colorScheme: const ColorScheme.light(primary: midnightBlue, onPrimary: cleanWhite, onSurface: midnightBlue),
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
    final snapshot = await FirebaseFirestore.instance.collection('salesGoodsShipment').where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDayUtc)).where('created_at', isLessThan: Timestamp.fromDate(endOfDayUtc)).get();
    final count = snapshot.docs.length;
    final newNumber = count + 1;
    final formattedNumber = newNumber.toString().padLeft(4, '0');
    final code = 'TKB${now.year % 100}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}$formattedNumber';
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
    if (!_formKey.currentState!.validate() || _details.isEmpty) return;
    final storeCode = await StoreService.getStoreCode();
    if (storeCode == null) return;
    final storeQuery = await FirebaseFirestore.instance.collection('stores').where('code', isEqualTo: storeCode).limit(1).get();
    if (storeQuery.docs.isEmpty) return;
    final storeRef = storeQuery.docs.first.reference;
    final shipment = {
      'no_form': _formNumberController.text.trim(),
      'receiver_name': _formReceiverNameController.text.trim(),
      'item_total': itemTotal,
      'post_date': Timestamp.fromDate(_postDate!),
      'created_at': Timestamp.now(),
      'store_ref': storeRef,
    };
    final shipmentDoc = await FirebaseFirestore.instance.collection('salesGoodsShipment').add(shipment);
    for (final detail in _details) {
      await shipmentDoc.collection('details').add(detail.toMap());
      if (detail.productRef != null) {
        final productSnapshot = await detail.productRef!.get();
        final productData = productSnapshot.data() as Map<String, dynamic>?;
        if (productData != null) {
          final currentStock = productData['stock'] ?? 0;
          await detail.productRef!.update({'stock': currentStock - detail.qty});
        }
        if (detail.warehouseRef != null) {
          final wsQuery = await FirebaseFirestore.instance.collection('warehouseStocks').where('product_ref', isEqualTo: detail.productRef).where('warehouse_ref', isEqualTo: detail.warehouseRef).limit(1).get();
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
      appBar: AppBar(title: const Text('Tambah Pengiriman'), centerTitle: true),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.save_alt_outlined),
          label: const Text("Simpan Pengiriman", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                            decoration: _buildInputDecoration('No. Form'),
                            readOnly: true,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                              controller: _formReceiverNameController,
                              decoration: _buildInputDecoration('Nama Penerima'),
                              validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _selectPostDate,
                            child: AbsorbPointer(
                              child: TextFormField(
                                controller: _postDateController,
                                decoration: InputDecoration(
                                  labelText: 'Tanggal Pengiriman',
                                  suffixIcon: const Icon(Icons.calendar_today),
                                  filled: true,
                                  fillColor: Colors.black.withOpacity(0.05),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                validator: (val) => _postDate == null ? 'Wajib dipilih' : null,
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
                              color: cleanWhite,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
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
                                          item.unitName = 'pcs';
                                        });
                                      },
                                      validator: (val) => val == null ? 'Pilih produk' : null,
                                      popupProps: PopupProps.menu(
                                        showSearchBox: true,
                                        searchFieldProps: TextFieldProps(decoration: _buildInputDecoration('Cari produk...')),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<DocumentReference>(
                                      value: item.warehouseRef,
                                      items: _warehouses.map((doc) => DropdownMenuItem(value: doc.reference, child: Text(doc['name']))).toList(),
                                      onChanged: (value) async {
                                        setState(() => item.warehouseRef = value);
                                        await item.fetchWarehouseStock();
                                        setState(() {});
                                      },
                                      decoration: _buildInputDecoration("Gudang Asal"),
                                      validator: (value) => value == null ? 'Pilih gudang' : null,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                        initialValue: item.qty.toString(),
                                        decoration: _buildInputDecoration("Jumlah"),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) => setState(() => item.qty = int.tryParse(val) ?? 1),
                                        validator: (val) {
                                          final qty = int.tryParse(val ?? '');
                                          if (qty == null || qty <= 0) return 'Wajib > 0';
                                          if (qty > item.availableStock) return 'Stok tidak cukup';
                                          return null;
                                        }),
                                    if (item.productRef != null && item.warehouseRef != null)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                                          child: Text('Stok tersedia: ${item.availableStock}', style: const TextStyle(color: Colors.grey)),
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
    final wsQuery = await FirebaseFirestore.instance.collection('warehouseStocks').where('product_ref', isEqualTo: productRef).where('warehouse_ref', isEqualTo: warehouseRef).limit(1).get();
    if (wsQuery.docs.isNotEmpty) {
      final stock = wsQuery.docs.first['qty'] ?? 0;
      availableStock = stock;
    } else {
      availableStock = 0;
    }
  }

  Map<String, dynamic> toMap() {
    return {'product_ref': productRef, 'warehouse_ref': warehouseRef, 'qty': qty, 'unit_name': unitName};
  }
}