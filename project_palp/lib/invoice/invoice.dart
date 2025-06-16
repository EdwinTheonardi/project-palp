import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import '../services/store_service.dart';
import 'package:intl/intl.dart';

class InvoicePage extends StatefulWidget {
  const InvoicePage({ super.key });

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  DocumentReference? _storeRef;
  List<DocumentSnapshot> _allInvoices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoicesForStore();
  }

  Future<void> _loadInvoicesForStore() async {
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

      final invoicesSnapshot = await FirebaseFirestore.instance
          .collection('purchaseInvoices')
          .where('store_ref', isEqualTo: storeRef)
          .get();

      setState(() {
        _storeRef = storeRef;
        _allInvoices = invoicesSnapshot.docs;
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
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _allInvoices.isEmpty
              ? Center(child: Text('Tidak ada data invoice'))
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadInvoicesForStore,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            child: DataTable2(
                              columnSpacing: 20,
                              horizontalMargin: 16,
                              headingRowColor: WidgetStateProperty.all(Colors.blue[100]),
                              columns: [
                                DataColumn2(
                                  label: Center(child: Text('No Faktur')),
                                  size: ColumnSize.S,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Created At')),
                                  size: ColumnSize.M,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Post Date')),
                                  size: ColumnSize.S,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Payment Type')),
                                  size: ColumnSize.S,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Due Date')),
                                  size: ColumnSize.S,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Shipping Cost')),
                                  size: ColumnSize.S,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Grand Total')),
                                  size: ColumnSize.S,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Invoice Details')),
                                  size: ColumnSize.M,
                                ),
                                DataColumn2(
                                  label: Center(child: Text('Action')),
                                  size: ColumnSize.M,
                                ),
                              ],
                              rows: _allInvoices.map((doc) {
                                final invoice = doc.data() as Map<String, dynamic>;
                                return DataRow(cells: [
                                  DataCell(Text(invoice['invoice_number'] ?? '-')),
                                  DataCell(Text(
                                  invoice['created_at'] != null
                                      ? DateFormat('dd MMMM yyyy, HH:mm:ss').format(invoice['created_at'].toDate())
                                      : '-',
                                  )),
                                  DataCell(Text(
                                    invoice['post_date'] != null 
                                      ? DateFormat('dd/MM/yyyy').format((invoice['post_date'] as Timestamp).toDate()) 
                                      : '-'
                                  )),
                                  DataCell(
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(invoice['payment_type']?.toString() ?? '-'),
                                    ),
                                  ),
                                  DataCell(Text(
                                    invoice['post_date'] != null 
                                      ? DateFormat('dd/MM/yyyy').format((invoice['due_date'] as Timestamp).toDate()) 
                                      : '-'
                                  )),
                                  DataCell(
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        NumberFormat.currency(
                                          locale: 'id_ID',
                                          symbol: 'Rp. ',
                                          decimalDigits: 0,
                                        ).format(invoice['shipping_cost'] ?? 0),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        NumberFormat.currency(
                                          locale: 'id_ID',
                                          symbol: 'Rp. ',
                                          decimalDigits: 0,
                                        ).format(invoice['grandtotal'] ?? 0),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Align(
                                      alignment: Alignment.center,
                                      child: TextButton(
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => InvoiceDetailsPage(invoiceRef: doc.reference),
                                            ),
                                          );
                                          await _loadInvoicesForStore();
                                        },
                                        child: Text("Detail"),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Align(
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.edit, color: Colors.lightBlue),
                                            tooltip: "Edit Receipt",
                                            onPressed: () async {
                                              // await Navigator.push(
                                              //   context,
                                              //   MaterialPageRoute(
                                              //     builder: (context) => EditReceiptPage(receiptRef: doc.reference),
                                              //   ),
                                              // );
                                              // await _loadReceiptsForStore();
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete, color: Colors.redAccent),
                                            tooltip: "Delete Receipt",
                                            onPressed: () async {
                                              // _showDeleteConfirmationDialog(context, doc.reference);
                                              // await _loadReceiptsForStore();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16, right: 16),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: SizedBox(
                          width: 180,
                          height: 45,
                          child: ElevatedButton(
                            onPressed: () async {
                              // await Navigator.push(
                              //   context,
                              //   MaterialPageRoute(builder: (_) => AddReceiptPage()),
                              // );
                              // await _loadInvoicesForStore();
                            },
                            child: Text('Tambah Invoice'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  // void _showDeleteConfirmationDialog(BuildContext context, DocumentReference ref) async {
  //   final shouldDelete = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text('Konfirmasi'),
  //       content: Text('Yakin ingin menghapus receipt ini?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, false),
  //           child: Text('Batal'),
  //         ),
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, true),
  //           child: Text('Hapus', style: TextStyle(color: Colors.red)),
  //         ),
  //       ],
  //     ),
  //   );

  //   if (shouldDelete == true) {
  //     // Hapus detail dan dokumen utama
  //     final details = await ref.collection('details').get();
  //     for (final doc in details.docs) {
  //       await doc.reference.delete();
  //     }
  //     await ref.delete();
  //     await _loadReceiptsForStore();
  //   }
  // }
}

class InvoiceDetailsPage extends StatefulWidget {
  final DocumentReference invoiceRef;

  const InvoiceDetailsPage({super.key, required this.invoiceRef});

  @override
  State<InvoiceDetailsPage> createState() => _InvoiceDetailsPageState();
}

class _InvoiceDetailsPageState extends State<InvoiceDetailsPage> {
  List<DocumentSnapshot> _allDetails = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final detailsSnapshot =
          await widget.invoiceRef.collection('details').get();

      setState(() {
        _allDetails = detailsSnapshot.docs;
        _loading = false;
      });
    } catch (e) {
      print("Gagal memuat detail: $e");
      setState(() => _loading = false);
    }
  }

  Future<String> _getProductName(DocumentReference? productRef) async {
    if (productRef == null) return '-';
    try {
      final doc = await productRef.get();
      final data = doc.data() as Map<String, dynamic>?;
      return data?['name'] ?? '-';
    } catch (e) {
      print("Gagal mendapatkan nama product: $e");
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Details')
        ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _allDetails.isEmpty
              ? const Center(child: Text('Tidak ada detail produk.'))
              : ListView.builder(
                  itemCount: _allDetails.length,
                  itemBuilder: (context, index) {
                    final data =
                        _allDetails[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder<String>(
                              future: _getProductName(data['product_ref']),
                              builder: (context, snapshot) {
                                return Text(snapshot.data ?? '-');
                              },
                            ),
                            Text("Product Name: ${data['product_name'] ?? '-'}"),
                            Text("Qty: ${data['qty'] ?? '-'}"),
                            Text("Price: ${data['price'] ?? '-'}"),
                            Text("Subtotal: ${data['subtotal_price'] ?? '-'}"),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}