import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../lanprovider.dart';

class VendorBillsPage extends StatefulWidget {
  final String vendorId;
  final String vendorName;

  const VendorBillsPage({
    super.key,
    required this.vendorId,
    required this.vendorName,
  });

  @override
  State<VendorBillsPage> createState() => _VendorBillsPageState();
}

class _VendorBillsPageState extends State<VendorBillsPage> {
  List<Map<String, dynamic>> _bills = [];
  bool _isLoading = true;
  double _totalBills = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchBills();
  }

  Future<void> _fetchBills() async {
    try {
      final billsRef = FirebaseDatabase.instance
          .ref('vendors/${widget.vendorId}/bills');
      final snapshot = await billsRef.get();

      if (snapshot.value == null) {
        setState(() {
          _bills = [];
          _totalBills = 0.0;
          _isLoading = false;
        });
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> bills = [];
      double total = 0.0;

      data.forEach((key, value) {
        double amount = (value['amount'] ?? 0.0).toDouble();
        total += amount;
        bills.add({
          'id': key.toString(),
          'amount': amount,
          'date': value['date'] ?? 'Unknown Date',
          'description': value['description'] ?? '',
          'billReference': value['billReference'] ?? '',
          'image': value['image'] ?? '',
        });
      });

      // Sort by date (newest first)
      bills.sort((a, b) {
        final dateA = DateTime.tryParse(a['date']) ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['date']) ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });

      setState(() {
        _bills = bills;
        _totalBills = total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading bills: $e')),
      );
    }
  }

  Future<void> _deleteBill(String billId, double amount) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.isEnglish ? 'Confirm Delete' : 'حذف کی تصدیق کریں'),
        content: Text(languageProvider.isEnglish
            ? 'Are you sure you want to delete this bill?'
            : 'کیا آپ واقعی اس بل کو حذف کرنا چاہتے ہیں؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(languageProvider.isEnglish ? 'Cancel' : 'منسوخ کریں'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              languageProvider.isEnglish ? 'Delete' : 'حذف کریں',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseDatabase.instance
            .ref('vendors/${widget.vendorId}/bills/$billId')
            .remove();

        await FirebaseDatabase.instance
            .ref('vendors/${widget.vendorId}/totalBills')
            .set(ServerValue.increment(-amount));

        await _fetchBills();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              languageProvider.isEnglish ? 'Bill deleted successfully!' : 'بل کامیابی سے حذف ہو گیا!'
          )),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting bill: $e')),
        );
      }
    }
  }

  void _showFullScreenImage(Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(imageBytes),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.vendorName} - ${languageProvider.isEnglish ? 'Bills' : 'بلز'}'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.all(8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${languageProvider.isEnglish ? 'Total' : 'کل'}: Rs ${_totalBills.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.purple))
          : _bills.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              languageProvider.isEnglish
                  ? 'No bills found for this vendor'
                  : 'اس وینڈر کے لیے کوئی بل نہیں ملا',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _bills.length,
        itemBuilder: (context, index) {
          final bill = _bills[index];
          final hasImage = bill['image'] != null && bill['image'].isNotEmpty;
          final billDate = DateTime.tryParse(bill['date']);

          return Card(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Colors.purple.shade100,
                child: Icon(Icons.receipt, color: Colors.purple),
              ),
              title: Text(
                'Rs ${bill['amount'].toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[800],
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (billDate != null)
                    Text(DateFormat('dd MMM yyyy').format(billDate)),
                  Text('Ref: ${bill['billReference']}'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteBill(bill['id'], bill['amount']),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        'Description',
                        bill['description'],
                      ),
                      if (hasImage) ...[
                        SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => _showFullScreenImage(
                            base64Decode(bill['image']),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.purple.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(bill['image']),
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }
}