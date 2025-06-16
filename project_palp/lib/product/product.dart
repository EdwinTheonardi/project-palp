import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_service.dart';
import 'package:intl/intl.dart';
import './add_product.dart';
import './edit_product.dart'; 

class ProductPage extends StatefulWidget {
  const ProductPage({ super.key });

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  DocumentReference? _storeRef;
  List<DocumentSnapshot> _allProducts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProductsForStore();
  }

  Future<void> _loadProductsForStore() async {
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

      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('store_ref', isEqualTo: storeRef)
          .get();

      setState(() {
        _storeRef = storeRef;
        _allProducts = productsSnapshot.docs;
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
              : _allProducts.isEmpty
                  ? Center(child: Text('Tidak ada data product'))
                  : RefreshIndicator(
                      onRefresh: _loadProductsForStore,
                      child: ListView.builder(
                        itemCount: _allProducts.length,
                        itemBuilder: (context, index) {
                          final product = _allProducts[index].data() as Map<String, dynamic>;

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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${product['name'] ?? '-'}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Harga: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp. ', decimalDigits: 0).format(product['price'] ?? 0)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Stok: ${product['stock'] ?? '-'}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit, color: Colors.lightBlue),
                                        tooltip: "Edit Product",
                                        onPressed: () async {
                                          final updated = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => EditProductPage(
                                                productRef: _allProducts[index].reference,
                                              ),
                                            ),
                                          );
                                          await _loadProductsForStore();
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete, color: Colors.lightBlue),
                                        tooltip: "Hapus Product",
                                        onPressed: () async {
                                          _showDeleteConfirmationDialog(
                                            context,
                                            _allProducts[index].reference,
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
                    MaterialPageRoute(builder: (_) => AddProductPage()),
                  );
                  await _loadProductsForStore(); // Refresh data setelah tambah
                },
                child: Text('Tambah Product'),
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
        content: Text('Yakin ingin menghapus product ini?'),
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
        await _loadProductsForStore();
      } catch (e) {
        print("Gagal menghapus product: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus product: $e')),
          );
        }
      }
    }
  }
}