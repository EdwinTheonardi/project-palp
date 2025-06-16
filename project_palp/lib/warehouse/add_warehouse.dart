import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';

class AddWarehousePage extends StatefulWidget {
  const AddWarehousePage({super.key});

  @override
  State<AddWarehousePage> createState() => _AddWarehousePageState();
}

class _AddWarehousePageState extends State<AddWarehousePage> {
  final _formKey = GlobalKey<FormState>();
  final _warehouseNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _saveWarehouse() async {
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

    final warehouse = {
      'name': _warehouseNameController.text.trim(),
      'store_ref': storeRef,
    };

    final warehouseDoc = await FirebaseFirestore.instance
        .collection('warehouses')
        .add(warehouse);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tambah Warehouse')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _warehouseNameController,
                decoration: InputDecoration(labelText: 'Nama Warehouse'),
                validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveWarehouse,
                child: Text("Simpan Warehouse"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
