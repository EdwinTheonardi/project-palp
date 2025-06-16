import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart';
import '../services/store_service.dart';
import 'package:intl/intl.dart';

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
      final storeSnapshot = await FirebaseFirestore.instance.collection('stores').where('code', isEqualTo: storeCode).limit(1).get();
      if (storeSnapshot.docs.isEmpty) {
        print("Store dengan code $storeCode tidak ditemukan.");
        if (mounted) setState(() => _loading = false);
        return;
      }
      final storeDoc = storeSnapshot.docs.first;
      final storeRef = storeDoc.reference;
      print("Store reference ditemukan: ${storeRef.path}");
      final invoicesSnapshot = await FirebaseFirestore.instance.collection('purchaseInvoices').where('store_ref', isEqualTo: storeRef).get();
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
                    Icon(Icons.request_quote_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('Tidak ada data invoice', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ))
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadInvoicesForStore,
                        color: accentOrange,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 2.5,
                            child: DataTable2(
                              columnSpacing: 20,
                              horizontalMargin: 16,
                              headingRowColor: WidgetStateProperty.all(midnightBlue.withOpacity(0.05)),
                              headingTextStyle: const TextStyle(color: midnightBlue, fontWeight: FontWeight.bold),
                              columns: const [
                                DataColumn2(label: Center(child: Text('No Faktur')), size: ColumnSize.M),
                                DataColumn2(label: Center(child: Text('Created At')), size: ColumnSize.L),
                                DataColumn2(label: Center(child: Text('Post Date')), size: ColumnSize.M),
                                DataColumn2(label: Center(child: Text('Payment Type')), size: ColumnSize.S),
                                DataColumn2(label: Center(child: Text('Due Date')), size: ColumnSize.M),
                                DataColumn2(label: Center(child: Text('Shipping Cost')), size: ColumnSize.L),
                                DataColumn2(label: Center(child: Text('Grand Total')), size: ColumnSize.L),
                                DataColumn2(label: Center(child: Text('Invoice Details')), size: ColumnSize.M),
                                DataColumn2(label: Center(child: Text('Action')), size: ColumnSize.L),
                              ],
                              rows: _allInvoices.map((doc) {
                                final invoice = doc.data() as Map<String, dynamic>;
                                return DataRow(cells: [
                                  DataCell(Text(invoice['invoice_number'] ?? '-')),
                                  DataCell(Text(invoice['created_at'] != null ? DateFormat('dd MMM yy, HH:mm').format(invoice['created_at'].toDate()) : '-')),
                                  DataCell(Text(invoice['post_date'] != null ? DateFormat('dd/MM/yyyy').format((invoice['post_date'] as Timestamp).toDate()) : '-')),
                                  DataCell(Center(child: Text(invoice['payment_type']?.toString() ?? '-'))),
                                  DataCell(Text(invoice['due_date'] != null ? DateFormat('dd/MM/yyyy').format((invoice['due_date'] as Timestamp).toDate()) : '-')),
                                  DataCell(Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(invoice['shipping_cost'] ?? 0)),
                                  )),
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
                                            MaterialPageRoute(
                                              builder: (context) => InvoiceDetailsPage(invoiceRef: doc.reference),
                                            ),
                                          );
                                          await _loadInvoicesForStore();
                                        },
                                        child: const Text("Detail"),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.edit_outlined, color: Colors.blueGrey[600]),
                                            tooltip: "Edit Invoice",
                                            onPressed: () async {},
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline, color: Colors.redAccent[400]),
                                            tooltip: "Delete Invoice",
                                            onPressed: () async {},
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
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah Invoice'),
                          onPressed: () async {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentOrange,
                            foregroundColor: cleanWhite,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
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
      appBar: AppBar(title: const Text('Detail Invoice'), centerTitle: true),
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
                      child: ListTile(
                        leading: const Icon(Icons.inventory_2_outlined, color: midnightBlue),
                        title: Text(data['product_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: midnightBlue)),
                        subtitle: Text("Qty: ${data['qty'] ?? '-'}  •  Harga: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(data['price'] ?? 0)}"),
                        trailing: Text(
                          NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(data['subtotal_price'] ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}