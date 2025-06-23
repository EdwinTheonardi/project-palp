import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';
import './add_warehouse.dart';
import './edit_warehouse.dart';

class WarehousePage extends StatefulWidget {
  const WarehousePage({super.key});

  @override
  State<WarehousePage> createState() => _WarehousePageState();
}

class _WarehousePageState extends State<WarehousePage> {
  DocumentReference? _storeRef;
  List<DocumentSnapshot> _allWarehouses = [];
  bool _loading = true;

  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadWarehousesForStore();
  }

  Future<void> _loadWarehousesForStore() async {
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
      final warehousesSnapshot = await FirebaseFirestore.instance.collection('warehouses').where('store_ref', isEqualTo: storeRef).get();
      if (mounted) {
        setState(() {
          _storeRef = storeRef;
          _allWarehouses = warehousesSnapshot.docs;
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
              : _allWarehouses.isEmpty
                  ? Center(
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warehouse_outlined, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text('Tidak ada data gudang', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ))
                  : RefreshIndicator(
                      onRefresh: _loadWarehousesForStore,
                      color: accentOrange,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                        itemCount: _allWarehouses.length,
                        itemBuilder: (context, index) {
                          final warehouse = _allWarehouses[index].data() as Map<String, dynamic>;
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
                                        '${warehouse['name'] ?? '-'}',
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
                                        tooltip: "Edit Warehouse",
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => EditWarehousePage(
                                                warehouseRef: _allWarehouses[index].reference,
                                              ),
                                            ),
                                          );
                                          await _loadWarehousesForStore();
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: Colors.redAccent[400]),
                                        tooltip: "Hapus Catatan",
                                        onPressed: () async {
                                          _showDeleteConfirmationDialog(
                                            context,
                                            _allWarehouses[index].reference,
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
              label: const Text('Tambah Gudang'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddWarehousePage()),
                );
                await _loadWarehousesForStore();
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
        content: const Text('Yakin ingin menghapus warehouse ini?'),
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
        await _loadWarehousesForStore();
      } catch (e) {
        print("Gagal menghapus warehouse: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus warehouse: $e')),
          );
        }
      }
    }
  }
}