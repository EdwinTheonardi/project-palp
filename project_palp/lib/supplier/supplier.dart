import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';
import './add_supplier.dart';
import './edit_supplier.dart';

class SupplierPage extends StatefulWidget {
  const SupplierPage({super.key});

  @override
  State<SupplierPage> createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  DocumentReference? _storeRef;
  List<DocumentSnapshot> _allSuppliers = [];
  bool _loading = true;

  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadSuppliersForStore();
  }

  Future<void> _loadSuppliersForStore() async {
    final storeCode = await StoreService.getStoreCode();
    if (storeCode == null || storeCode.isEmpty) {
      print("Store code tidak ditemukan.");
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final storeSnapshot = await FirebaseFirestore.instance.collection('stores').where('code', isEqualTo: storeCode).limit(1).get();
      if (storeSnapshot.docs.isEmpty) {
        print("Store dengan code $storeCode tidak ditemukan.");
        if (mounted) setState(() => _loading = false);
        return;
      }
      final storeDoc = storeSnapshot.docs.first;
      final storeRef = storeDoc.reference;
      print("Store reference ditemukan: ${storeRef.path}");
      final suppliersSnapshot = await FirebaseFirestore.instance.collection('suppliers').where('store_ref', isEqualTo: storeRef).get();
      if (mounted) {
        setState(() {
          _storeRef = storeRef;
          _allSuppliers = suppliersSnapshot.docs;
          _loading = false;
        });
      }
    } catch (e) {
      print("Gagal memuat data: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator(color: accentOrange))
              : _allSuppliers.isEmpty
                  ? Center(
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_alt_outlined, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text('Tidak ada data supplier', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ))
                  : RefreshIndicator(
                      onRefresh: _loadSuppliersForStore,
                      color: accentOrange,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                        itemCount: _allSuppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = _allSuppliers[index].data() as Map<String, dynamic>;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            elevation: 2,
                            color: cleanWhite,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${supplier['name'] ?? '-'}',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: midnightBlue,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined, color: Colors.blueGrey[600]),
                                        tooltip: "Edit Catatan",
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => EditSupplierPage(
                                                supplierRef: _allSuppliers[index].reference,
                                              ),
                                            ),
                                          );
                                          await _loadSuppliersForStore();
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: Colors.redAccent[400]),
                                        tooltip: "Hapus Catatan",
                                        onPressed: () async {
                                          _showDeleteConfirmationDialog(
                                            context,
                                            _allSuppliers[index].reference,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          Positioned(
            bottom: 16,
            right: 16,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Tambah Supplier'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddSupplierPage()),
                );
                await _loadSuppliersForStore();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentOrange,
                foregroundColor: cleanWhite,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, DocumentReference ref) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi'),
        content: const Text('Yakin ingin menghapus supplier ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await ref.delete();
        await _loadSuppliersForStore();
      } catch (e) {
        print("Gagal menghapus supplier: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus supplier: $e')),
          );
        }
      }
    }
  }
}