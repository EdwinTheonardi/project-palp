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
    _supplierNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final supplierSnap = await widget.supplierRef.get();
      if (!supplierSnap.exists) return;
      final supplierData = supplierSnap.data() as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _supplierNameController.text = supplierData['name'] ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading supplier data: $e');
      if (mounted) setState(() => _loading = false);
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
      appBar: AppBar(
        title: const Text('Edit Supplier'),
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
                      controller: _supplierNameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Supplier',
                        prefixIcon: const Icon(Icons.people_alt_outlined, color: midnightBlue),
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
                        onPressed: _updateSupplier,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentOrange,
                          foregroundColor: cleanWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        label: const Text(
                          "Update Supplier",
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
