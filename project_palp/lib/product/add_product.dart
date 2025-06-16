import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _productPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _saveProduct() async {
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

    final product = {
      'name': _productNameController.text.trim(),
      'price': int.tryParse(_productPriceController.text.trim()) ?? 0,
      'stock': 0,
      'store_ref': storeRef,
    };

    final productDoc = await FirebaseFirestore.instance
        .collection('products')
        .add(product);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tambah Product')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _productNameController,
                decoration: InputDecoration(labelText: 'Nama Product'),
                validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
              ),
              TextFormField(
                controller: _productPriceController,
                decoration: InputDecoration(labelText: 'Harga Product'),
                validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveProduct,
                child: Text("Simpan Product"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}