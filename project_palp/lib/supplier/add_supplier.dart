import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';

class AddSupplierPage extends StatefulWidget {
  const AddSupplierPage({super.key});

  @override
  State<AddSupplierPage> createState() => _AddSupplierPageState();
}

class _AddSupplierPageState extends State<AddSupplierPage> {
  final _formKey = GlobalKey<FormState>();
  final _supplierNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final storeCode = await StoreService.getStoreCode();
    if (storeCode == null) return;

    final storeQuery =
        await FirebaseFirestore.instance
            .collection('stores')
            .where('code', isEqualTo: storeCode)
            .limit(1)
            .get();

    if (storeQuery.docs.isEmpty) return;
    final storeRef = storeQuery.docs.first.reference;

    final supplier = {
      'name': _supplierNameController.text.trim(),
      'store_ref': storeRef,
    };

    final supplierDoc = await FirebaseFirestore.instance
        .collection('suppliers')
        .add(supplier);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tambah Supplier')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _supplierNameController,
                decoration: InputDecoration(labelText: 'Nama Supplier'),
                validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveSupplier,
                child: Text("Simpan Supplier"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
