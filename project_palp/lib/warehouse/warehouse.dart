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
      final warehousesSnapshot = await FirebaseFirestore.instance
          .collection('warehouses')
          .where('store_ref', isEqualTo: storeRef)
          .orderBy('name')
          .get();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddWarehousePage()),
          );
          await _loadWarehousesForStore();
        },
        backgroundColor: accentOrange,
        foregroundColor: cleanWhite,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Gudang'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accentOrange))
          : _allWarehouses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warehouse_outlined,
                          size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('Belum Ada Gudang',
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 8),
                      const Text('Ketuk tombol + untuk menambah data baru.',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWarehousesForStore,
                  color: accentOrange,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(8, 8, 8, 80), // Padding bawah
                    itemCount: _allWarehouses.length,
                    itemBuilder: (context, index) {
                      final warehouse =
                          _allWarehouses[index].data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 8),
                        elevation: 2,
                        color: cleanWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          child: Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.warehouse_outlined,
                                    color: midnightBlue, size: 28),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${warehouse['name'] ?? '-'}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: midnightBlue,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit_outlined,
                                    color: Colors.blueGrey[600]),
                                tooltip: "Edit Warehouse",
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditWarehousePage(
                                        warehouseRef:
                                            _allWarehouses[index].reference,
                                      ),
                                    ),
                                  );
                                  await _loadWarehousesForStore();
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color: Colors.redAccent[400]),
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
        content: const Text('Yakin ingin menghapus gudang ini?'),
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
        await _loadWarehousesForStore();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus gudang: $e')),
          );
        }
      }
    }
  }
}