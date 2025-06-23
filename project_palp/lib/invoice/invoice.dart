import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import '../services/store_service.dart';
import 'package:intl/intl.dart';
import 'add_invoice.dart';
import 'edit_invoice.dart';

class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  DocumentReference? _storeRef;
  List<DocumentSnapshot> _allInvoices = [];
  bool _loading = true;

  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadInvoicesForStore();
  }

  Future<void> _loadInvoicesForStore() async {
    final storeCode = await StoreService.getStoreCode();

    if (storeCode == null || storeCode.isEmpty) {
      print("Store code tidak ditemukan.");
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
        print("Store dengan code $storeCode tidak ditemukan.");
        if (mounted) setState(() => _loading = false);
        return;
      }

      final storeDoc = storeSnapshot.docs.first;
      final storeRef = storeDoc.reference;

      print("Store reference ditemukan: ${storeRef.path}");

      final invoicesSnapshot = await FirebaseFirestore.instance
          .collection('purchaseInvoices')
          .where('store_ref', isEqualTo: storeRef)
          .get();

      if (mounted) {
        setState(() {
          _storeRef = storeRef;
          _allInvoices = invoicesSnapshot.docs;
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accentOrange))
          : _allInvoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('Tidak ada data invoice', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      height: 50,
                      color: Colors.transparent,
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadInvoicesForStore,
                        color: accentOrange,
                        child: DataTable2(
                          headingTextStyle: const TextStyle(color: midnightBlue, fontWeight: FontWeight.bold, fontSize: 12),
                          dataTextStyle: const TextStyle(fontSize: 11.5, color: Colors.black87),
                          columnSpacing: 12,
                          horizontalMargin: 12,
                          headingRowColor: WidgetStateProperty.all(midnightBlue.withOpacity(0.05)),
                          columns: const [
                            DataColumn2(label: Center(child: Text('No Faktur')), size: ColumnSize.M),
                            DataColumn2(label: Center(child: Text('Created At')), size: ColumnSize.L),
                            DataColumn2(label: Center(child: Text('Post Date')), size: ColumnSize.M),
                            DataColumn2(label: Center(child: Text('Payment')), size: ColumnSize.S),
                            DataColumn2(label: Center(child: Text('Due Date')), size: ColumnSize.M),
                            DataColumn2(label: Center(child: Text('Grand Total')), size: ColumnSize.L, numeric: true),
                            DataColumn2(label: Center(child: Text('Details')), fixedWidth: 100),
                            DataColumn2(label: Center(child: Text('Actions')), fixedWidth: 120),
                          ],
                          rows: _allInvoices.map((doc) {
                            final invoice = doc.data() as Map<String, dynamic>;
                            return DataRow(cells: [
                              DataCell(Text(invoice['no_invoice'] ?? '-')),
                              DataCell(Text(invoice['created_at'] != null ? DateFormat('dd MMM yy, HH:mm').format(invoice['created_at'].toDate()) : '-')),
                              DataCell(Text(invoice['post_date'] != null ? DateFormat('dd/MM/yyyy').format((invoice['post_date'] as Timestamp).toDate()) : '-')),
                              DataCell(Center(child: Text(invoice['payment_type'] ?? '-'))),
                              DataCell(Text(invoice['due_date'] != null ? DateFormat('dd/MM/yyyy').format((invoice['due_date'] as Timestamp).toDate()) : '-')),
                              DataCell(Align(
                                alignment: Alignment.centerRight,
                                child: Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(invoice['grandtotal'] ?? 0)),
                              )),
                              DataCell(
                                Center(
                                  child: TextButton(
                                    style: TextButton.styleFrom(foregroundColor: accentOrange),
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => InvoiceDetailsPage(invoiceRef: doc.reference)),
                                      );
                                    },
                                    child: const Text("Detail"),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined, color: Colors.blueGrey[600], size: 20),
                                      tooltip: "Edit Invoice",
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => EditInvoicePage(invoiceRef: doc.reference)),
                                        );
                                        await _loadInvoicesForStore();
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: Colors.redAccent[400], size: 20),
                                      tooltip: "Delete Invoice",
                                      onPressed: () {
                                        _showDeleteConfirmationDialog(context, doc.reference);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddInvoicePage()),
                            );
                            await _loadInvoicesForStore();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentOrange,
                            foregroundColor: cleanWhite,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          label: const Text('Tambah Invoice'),
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
        content: const Text('Yakin ingin menghapus invoice ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final details = await ref.collection('details').get();
      for (final doc in details.docs) {
        await doc.reference.delete();
      }
      await ref.delete();
      await _loadInvoicesForStore();
    }
  }
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

  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;
  static const Color lightGray = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final detailsSnapshot = await widget.invoiceRef.collection('details').get();
      if (mounted) {
        setState(() {
          _allDetails = detailsSnapshot.docs;
          _loading = false;
        });
      }
    } catch (e) {
      print("Gagal memuat detail: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      appBar: AppBar(
        title: const Text('Detail Invoice'),
        centerTitle: true,
        backgroundColor: midnightBlue,
        foregroundColor: cleanWhite,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accentOrange))
          : _allDetails.isEmpty
              ? Center(
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('Tidak ada detail produk.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ))
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _allDetails.length,
                  itemBuilder: (context, index) {
                    final data = _allDetails[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      elevation: 2,
                      color: cleanWhite,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['product_name'] ?? 'Nama Produk Tidak Ada',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: midnightBlue)),
                            const Divider(height: 20, color: lightGray),
                            _buildDetailRow("Jumlah", (data['qty'] ?? 0).toString()),
                            const SizedBox(height: 8),
                            _buildDetailRow("Harga", NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(data['price'] ?? 0)),
                            const SizedBox(height: 8),
                            const Divider(height: 10, thickness: 0.5),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(data['subtotal'] ?? 0),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: accentOrange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}