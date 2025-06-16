import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';
import './add_supplier.dart';
import './edit_supplier.dart';

class SupplierPage extends StatefulWidget {
  const SupplierPage({ super.key });

  @override
  State<SupplierPage> createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  DocumentReference? _storeRef;
  List<DocumentSnapshot> _allSuppliers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSuppliersForStore();
  }

  Future<void> _loadSuppliersForStore() async {
    final storeCode = await StoreService.getStoreCode();

    if (storeCode == null || storeCode.isEmpty) {
      print("Store code tidak ditemukan.");
      setState(() => _loading = false);
      return;
    }

    try {
      final storeSnapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('code', isEqualTo: storeCode)
          .limit(1)
          .get();

      if (storeSnapshot.docs.isEmpty) {
        print("Store dengan code $storeCode tidak ditemukan.");
        setState(() => _loading = false);
        return;
      }

      final storeDoc = storeSnapshot.docs.first;
      final storeRef = storeDoc.reference;

      print("Store reference ditemukan: ${storeRef.path}");

      final suppliersSnapshot = await FirebaseFirestore.instance
          .collection('suppliers')
          .where('store_ref', isEqualTo: storeRef)
          .get();

      setState(() {
        _storeRef = storeRef;
        _allSuppliers = suppliersSnapshot.docs;
        _loading = false;
      });
    } catch (e) {
      print("Gagal memuat data: $e");
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _loading
              ? Center(child: CircularProgressIndicator())
              : _allSuppliers.isEmpty
                  ? Center(child: Text('Tidak ada data supplier'))
                  : RefreshIndicator(
                      onRefresh: _loadSuppliersForStore,
                      child: ListView.builder(
                        itemCount: _allSuppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = _allSuppliers[index].data() as Map<String, dynamic>;

                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${supplier['name'] ?? '-'}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit, color: Colors.lightBlue),
                                        tooltip: "Edit Catatan",
                                        onPressed: () async {
                                          final updated = await Navigator.push(
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
                                        icon: Icon(Icons.delete, color: Colors.lightBlue),
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
            child: SizedBox(
              width: 180,
              height: 45,
              child: ElevatedButton(  
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddSupplierPage()),
                  );
                  await _loadSuppliersForStore(); // Refresh data setelah tambah
                },
                child: Text('Tambah Supplier'),
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
        title: Text('Konfirmasi'),
        content: Text('Yakin ingin menghapus supplier ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Hapus', style: TextStyle(color: Colors.red)),
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
