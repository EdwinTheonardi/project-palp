import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';
import './add_warehouse.dart';
import './edit_warehouse.dart'; 

class WarehousePage extends StatefulWidget {
  const WarehousePage({ super.key });

  @override
  State<WarehousePage> createState() => _WarehousePageState();
}

class _WarehousePageState extends State<WarehousePage> {
  DocumentReference? _storeRef;
  List<DocumentSnapshot> _allWarehouses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWarehousesForStore();
  }

  Future<void> _loadWarehousesForStore() async {
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

      final warehousesSnapshot = await FirebaseFirestore.instance
          .collection('warehouses')
          .where('store_ref', isEqualTo: storeRef)
          .get();

      setState(() {
        _storeRef = storeRef;
        _allWarehouses = warehousesSnapshot.docs;
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
              : _allWarehouses.isEmpty
                  ? Center(child: Text('Tidak ada data warehouse'))
                  : RefreshIndicator(
                      onRefresh: _loadWarehousesForStore,
                      child: ListView.builder(
                        itemCount: _allWarehouses.length,
                        itemBuilder: (context, index) {
                          final warehouse = _allWarehouses[index].data() as Map<String, dynamic>;

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
                                        '${warehouse['name'] ?? '-'}',
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
                                        tooltip: "Edit Warehouse",
                                        onPressed: () async {
                                          final updated = await Navigator.push(
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
                                        icon: Icon(Icons.delete, color: Colors.lightBlue),
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
            child: SizedBox(
              width: 180,
              height: 45,
              child: ElevatedButton(  
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddWarehousePage()),
                  );
                  await _loadWarehousesForStore(); // Refresh data setelah tambah
                },
                child: Text('Tambah Warehouse'),
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
        content: Text('Yakin ingin menghapus warehouse ini?'),
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