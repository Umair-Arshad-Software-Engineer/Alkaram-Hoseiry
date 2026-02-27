import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../lanprovider.dart';

class VendorChequesPage extends StatefulWidget {
  const VendorChequesPage({super.key});

  @override
  State<VendorChequesPage> createState() => _VendorChequesPageState();
}

class _VendorChequesPageState extends State<VendorChequesPage> {
  List<Map<String, dynamic>> _cheques = [];
  List<Map<String, dynamic>> _filteredCheques = [];
  bool _isLoading = true;
  String _filterStatus = 'all';
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  String? _expandedChequeId;

  @override
  void initState() {
    super.initState();
    _fetchCheques();
    _searchController.addListener(_filterCheques);
  }

  Future<void> _fetchCheques() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('vendorCheques').get();
      if (snapshot.value == null) {
        setState(() {
          _cheques = [];
          _filteredCheques = [];
          _isLoading = false;
        });
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> cheques = [];

      data.forEach((key, value) {
        cheques.add({
          'id': key.toString(),
          'vendorId': value['vendorId'] ?? '',
          'vendorName': value['vendorName'] ?? 'Unknown Vendor',
          'amount': (value['amount'] ?? 0.0).toDouble(),
          'chequeNumber': value['chequeNumber'] ?? '',
          'chequeDate': value['chequeDate'] ?? '',
          'bankId': value['bankId'] ?? '',
          'bankName': value['bankName'] ?? 'Unknown Bank',
          'status': value['status'] ?? 'pending',
          'dateIssued': value['dateIssued'] ?? DateTime.now().toString(),
          'description': value['description'] ?? '',
          'image': value['image'] ?? '',
          'statusUpdatedAt': value['statusUpdatedAt'] ?? '',
        });
      });

      setState(() {
        _cheques = cheques;
        _filteredCheques = cheques;
        _isLoading = false;
      });
      _filterCheques();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching cheques: $e')),
      );
    }
  }

  void _filterCheques() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCheques = _cheques.where((cheque) {
        final matchesSearch = cheque['vendorName'].toLowerCase().contains(query) ||
            cheque['chequeNumber'].toLowerCase().contains(query);
        final matchesStatus = _filterStatus == 'all' || cheque['status'] == _filterStatus;

        bool matchesDateRange = true;
        if (_selectedDateRange != null) {
          try {
            final chequeDate = DateTime.parse(cheque['chequeDate']);
            matchesDateRange = chequeDate.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                chequeDate.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
          } catch (e) {
            matchesDateRange = false;
          }
        }

        return matchesSearch && matchesStatus && matchesDateRange;
      }).toList();
    });
  }

  Future<void> _selectDateRange() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF8A65),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _filterCheques();
    }
  }

  void _clearDateRange() {
    setState(() {
      _selectedDateRange = null;
    });
    _filterCheques();
  }

  Future<void> _updateChequeStatus(String chequeId, String newStatus) async {
    try {
      final chequeRef = FirebaseDatabase.instance.ref('vendorCheques/$chequeId');
      final chequeSnapshot = await chequeRef.get();
      final cheque = chequeSnapshot.value as Map<dynamic, dynamic>;

      if (newStatus == 'cleared') {
        final vendorRef = FirebaseDatabase.instance.ref('vendors/${cheque['vendorId']}');

        final paymentData = {
          'amount': cheque['amount'],
          'date': DateTime.now().toIso8601String(),
          'method': 'Cheque',
          'description': cheque['description'] ?? 'Cheque Payment',
          'vendorId': cheque['vendorId'],
          'vendorName': cheque['vendorName'],
          'chequeNumber': cheque['chequeNumber'],
          'chequeDate': cheque['chequeDate'],
          'bankId': cheque['bankId'],
          'bankName': cheque['bankName'],
          'status': 'cleared',
          if (cheque['image'] != null) 'image': cheque['image'],
        };

        final paymentRef = vendorRef.child('payments').push();
        await paymentRef.set(paymentData);

        await vendorRef.child('paidAmount')
            .set(ServerValue.increment(cheque['amount']));

        await chequeRef.update({
          'status': 'cleared',
          'statusUpdatedAt': DateTime.now().toIso8601String(),
          'vendorPaymentId': paymentRef.key,
        });

        final bankRef = FirebaseDatabase.instance.ref('banks/${cheque['bankId']}/balance');
        final currentBalance = (await bankRef.get()).value as num? ?? 0.0;
        await bankRef.set(currentBalance - cheque['amount']);
      } else {
        await chequeRef.update({
          'status': newStatus,
          'statusUpdatedAt': DateTime.now().toIso8601String(),
        });

        if (cheque['status'] == 'cleared' && cheque['vendorPaymentId'] != null) {
          final vendorRef = FirebaseDatabase.instance.ref('vendors/${cheque['vendorId']}');
          await vendorRef.child('payments/${cheque['vendorPaymentId']}').remove();
          await vendorRef.child('paidAmount')
              .set(ServerValue.increment(-cheque['amount']));
        }
      }

      await _fetchCheques();

      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(languageProvider.isEnglish
            ? 'Cheque status updated successfully!'
            : 'چیک کی حیثیت کامیابی سے اپ ڈیٹ ہو گئی!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating cheque: $e')),
      );
    }
  }

  Widget _buildDetailRow(String label, String value, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: style ?? const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFullScreenImage(Uint8List imageBytes) async {
    await showDialog(
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'cleared':
        return Colors.green;
      case 'bounced':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.isEnglish ? 'Vendor Cheques' : 'فروش چیکس'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: languageProvider.isEnglish ? 'Search cheques' : 'چیک تلاش کریں',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _filterStatus,
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(languageProvider.isEnglish ? 'All' : 'سب'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text(languageProvider.isEnglish ? 'Pending' : 'زیر التوا'),
                        ),
                        DropdownMenuItem(
                          value: 'cleared',
                          child: Text(languageProvider.isEnglish ? 'Cleared' : 'کلئیر'),
                        ),
                        DropdownMenuItem(
                          value: 'bounced',
                          child: Text(languageProvider.isEnglish ? 'Bounced' : 'باؤنس'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _filterStatus = value!);
                        _filterCheques();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectDateRange,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _selectedDateRange == null
                              ? (languageProvider.isEnglish ? 'Select Date Range' : 'تاریخ کی حد منتخب کریں')
                              : '${_selectedDateRange!.start.toString().split(' ')[0]} - ${_selectedDateRange!.end.toString().split(' ')[0]}',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8A65),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    if (_selectedDateRange != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _clearDateRange,
                        icon: const Icon(Icons.clear),
                        color: Colors.red,
                        tooltip: languageProvider.isEnglish ? 'Clear Date Filter' : 'تاریخ فلٹر صاف کریں',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCheques.isEmpty
                ? Center(
              child: Text(
                languageProvider.isEnglish
                    ? 'No cheques found'
                    : 'کوئی چیک نہیں ملا',
              ),
            )
                : ListView.builder(
              itemCount: _filteredCheques.length,
              itemBuilder: (context, index) {
                final cheque = _filteredCheques[index];
                final isExpanded = _expandedChequeId == cheque['id'];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(cheque['status']),
                          child: Icon(
                            cheque['status'] == 'cleared' ? Icons.check :
                            cheque['status'] == 'bounced' ? Icons.close :
                            Icons.schedule,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          cheque['vendorName'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${languageProvider.isEnglish ? 'Amount' : 'رقم'}: ${cheque['amount']} Rs',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${languageProvider.isEnglish ? 'Cheque No' : 'چیک نمبر'}: ${cheque['chequeNumber']}',
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              onSelected: (value) =>
                                  _updateChequeStatus(cheque['id'], value),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'pending',
                                  child: Text(languageProvider.isEnglish
                                      ? 'Mark as Pending'
                                      : 'زیر التوا کے طور پر نشان زد کریں'),
                                ),
                                PopupMenuItem(
                                  value: 'cleared',
                                  child: Text(languageProvider.isEnglish
                                      ? 'Mark as Cleared'
                                      : 'کلئیر کے طور پر نشان زد کریں'),
                                ),
                                PopupMenuItem(
                                  value: 'bounced',
                                  child: Text(languageProvider.isEnglish
                                      ? 'Mark as Bounced'
                                      : 'باؤنس کے طور پر نشان زد کریں'),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                isExpanded ? Icons.expand_less : Icons.expand_more,
                              ),
                              onPressed: () {
                                setState(() {
                                  _expandedChequeId = isExpanded ? null : cheque['id'];
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      if (isExpanded) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow(
                                languageProvider.isEnglish ? 'Cheque Date' : 'چیک کی تاریخ',
                                cheque['chequeDate'],
                              ),
                              _buildDetailRow(
                                languageProvider.isEnglish ? 'Bank' : 'بینک',
                                cheque['bankName'],
                              ),
                              _buildDetailRow(
                                languageProvider.isEnglish ? 'Status' : 'حالت',
                                cheque['status'],
                                style: TextStyle(
                                  color: _getStatusColor(cheque['status']),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (cheque['statusUpdatedAt'] != null && cheque['statusUpdatedAt'].isNotEmpty)
                                _buildDetailRow(
                                  languageProvider.isEnglish ? 'Status Updated' : 'حالت اپ ڈیٹ',
                                  cheque['statusUpdatedAt'].toString().split('T')[0],
                                ),
                              _buildDetailRow(
                                languageProvider.isEnglish ? 'Issued Date' : 'جاری کرنے کی تاریخ',
                                cheque['dateIssued'].toString().split(' ')[0],
                              ),
                              if (cheque['description'].isNotEmpty)
                                _buildDetailRow(
                                  languageProvider.isEnglish ? 'Description' : 'تفصیل',
                                  cheque['description'],
                                ),
                              if (cheque['image'] != null && cheque['image'].isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: GestureDetector(
                                    onTap: () => _showFullScreenImage(base64Decode(cheque['image'])),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        base64Decode(cheque['image']),
                                        height: 150,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}