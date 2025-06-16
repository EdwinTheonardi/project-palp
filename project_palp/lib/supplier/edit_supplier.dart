import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';

class EditSupplierPage extends StatefulWidget {
  final DocumentReference supplierRef;

  const EditSupplierPage({super.key, required this.supplierRef});

  @override
  State<EditSupplierPage> createState() => _EditSupplierPageState();
}

class _EditSupplierPageState extends State<EditSupplierPage> {
  final _formKey = GlobalKey<FormState>();
  final _supplierNameController = TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final supplierSnap = await widget.supplierRef.get();
      if (!supplierSnap.exists) return;

      final supplierData = supplierSnap.data() as Map<String, dynamic>;

      setState(() {
        _supplierNameController.text = supplierData['name'] ?? '';

        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading supplier data: $e');
    }
  }

  Future<void> _updateSupplier() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final updatedData = {
      'name': _supplierNameController.text.trim(),
    };

    await widget.supplierRef.update(updatedData);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Supplier')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
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
                      onPressed: _updateSupplier,
                      child: Text("Simpan Supplier"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}