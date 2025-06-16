import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';

class EditWarehousePage extends StatefulWidget {
  final DocumentReference warehouseRef;

  const EditWarehousePage({super.key, required this.warehouseRef});

  @override
  State<EditWarehousePage> createState() => _EditWarehousePageState();
}

class _EditWarehousePageState extends State<EditWarehousePage> {
  final _formKey = GlobalKey<FormState>();
  final _warehouseNameController = TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _warehouseNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final warehouseSnap = await widget.warehouseRef.get();
      if (!warehouseSnap.exists) return;

      final warehouseData = warehouseSnap.data() as Map<String, dynamic>;

      setState(() {
        _warehouseNameController.text = warehouseData['name'] ?? '';

        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading warehouse data: $e');
    }
  }

  Future<void> _updateWarehouse() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final updatedData = {
      'name': _warehouseNameController.text.trim(),
    };

    await widget.warehouseRef.update(updatedData);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Warehouse')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
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
                      onPressed: _updateWarehouse,
                      child: Text("Simpan Warehouse"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}