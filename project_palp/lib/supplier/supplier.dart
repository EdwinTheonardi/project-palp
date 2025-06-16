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
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final storeSnapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('code', isEqualTo: storeCode)
          .limit(1)
          .get();
      if (storeSnapshot.docs.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final storeDoc = storeSnapshot.docs.first;
      final storeRef = storeDoc.reference;
      final suppliersSnapshot = await FirebaseFirestore.instance
          .collection('suppliers')
          .where('store_ref', isEqualTo: storeRef)
          .orderBy('name')
          .get();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSupplierPage()),
          );
          await _loadSuppliersForStore();
        },
        backgroundColor: accentOrange,
        foregroundColor: cleanWhite,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Supplier'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accentOrange))
          : _allSuppliers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_alt_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('Belum Ada Supplier', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 8),
                      const Text('Ketuk tombol + untuk menambah data baru.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSuppliersForStore,
                  color: accentOrange,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                    itemCount: _allSuppliers.length,
                    itemBuilder: (context, index) {
                      final supplier = _allSuppliers[index].data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        elevation: 2,
                        color: cleanWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.people_alt_outlined, color: midnightBlue, size: 28),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${supplier['name'] ?? '-'}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: midnightBlue,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit_outlined, color: Colors.blueGrey[600]),
                                tooltip: "Edit Supplier",
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
                                tooltip: "Hapus Supplier",
                                onPressed: () async {
                                  _showDeleteConfirmationDialog(
                                    context,
                                    _allSuppliers[index].reference,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _showDeleteConfirmationDialog(
      BuildContext context, DocumentReference ref) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Yakin ingin menghapus supplier ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: cleanWhite,
            ),
            onPressed: () => Navigator.pop(context, true),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus supplier: $e')),
          );
        }
      }
    }
  }
}