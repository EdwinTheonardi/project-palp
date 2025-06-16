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

  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;

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
      if (mounted) {
        setState(() {
          _warehouseNameController.text = warehouseData['name'] ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading warehouse data: $e');
      if (mounted) setState(() => _loading = false);
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
      appBar: AppBar(
        title: const Text('Edit Warehouse'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accentOrange))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _warehouseNameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Gudang',
                        prefixIcon: const Icon(Icons.warehouse_outlined, color: midnightBlue),
                        filled: true,
                        fillColor: cleanWhite,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save_alt_outlined),
                        onPressed: _updateWarehouse,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentOrange,
                          foregroundColor: cleanWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        label: const Text(
                          "Update Gudang",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}