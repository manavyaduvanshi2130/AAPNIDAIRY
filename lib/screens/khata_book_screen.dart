import 'package:flutter/material.dart';

import '../db/db_helper.dart';
import 'customer_ledger_detail_screen.dart';

class KhataBookScreen extends StatefulWidget {
  const KhataBookScreen({super.key});

  @override
  State<KhataBookScreen> createState() => _KhataBookScreenState();
}

class _KhataBookScreenState extends State<KhataBookScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));

  DateTime _endDate = DateTime.now();

  List<Map<String, dynamic>> _allCustomers = [];

  List<Map<String, dynamic>> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_filterCustomers);

    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCustomers() {
    final q = _searchController.text.trim().toLowerCase();

    setState(() {
      if (q.isEmpty) {
        _filteredCustomers = _allCustomers;
      } else {
        _filteredCustomers = _allCustomers.where((c) {
          final name = (c['name'] ?? '').toString().toLowerCase();

          final id = c['id']?.toString() ?? '';

          return name.contains(q) || id.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);

    try {
      final db = DatabaseHelper();

      final customers = await db.getCustomersForKhataBook();

      _allCustomers = customers;

      _filterCustomers();
    } catch (e) {
      debugPrint(e.toString());
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    await _loadCustomers();
  }

  Future<void> _pickDateRange() async {
    final start = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (start == null) return;

    final end = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: start,
      lastDate: DateTime.now(),
    );

    if (end == null) return;

    setState(() {
      _startDate = start;
      _endDate = end;
    });

    await _loadCustomers();
  }

  // FINAL SUMMARY
  // Negative = Customer Se Lena Hai
  // Positive = Customer Ko Dena Hai

  Future<Map<String, double>> _loadSummary() async {
    final db = DatabaseHelper();

    double totalYouWillGet = 0;
    double totalYouWillGive = 0;
    double totalProductSale = 0;

    for (final customer in _filteredCustomers) {
      final cid = customer['id'] as int;

      final balance = await db.getFinalBalance(cid);

      if (balance < 0) {
        totalYouWillGet += balance.abs();
      } else if (balance > 0) {
        totalYouWillGive += balance;
      }

      totalProductSale += await db.getProductSaleTotal(cid);
    }

    return {
      'youWillGet': totalYouWillGet,
      'youWillGive': totalYouWillGive,
      'totalProductSale': totalProductSale,
    };
  }

  Color _balanceColor(double value) {
    if (value < 0) {
      return Colors.green;
    } else if (value > 0) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  String _balanceTitle(double value) {
    if (value < 0) {
      return 'YOU WILL GET';
    } else if (value > 0) {
      return 'YOU WILL GIVE';
    } else {
      return 'BALANCED';
    }
  }

  String _balanceSubTitle(double value) {
    if (value < 0) {
      return 'Customer Se Lena Hai';
    } else if (value > 0) {
      return 'Customer Ko Dena Hai';
    } else {
      return 'Balance Clear';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),

      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('KHATA BOOK'),
        centerTitle: true,

        actions: [
          IconButton(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _refresh,

        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // SEARCH BOX
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                    ),
                  ],
                ),

                child: TextField(
                  controller: _searchController,

                  decoration: InputDecoration(
                    hintText: 'Search customer...',
                    prefixIcon: const Icon(Icons.search),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),

                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // DATE RANGE
              Row(
                children: [
                  Expanded(
                    child: _dateCard(
                      title: 'FROM',
                      value:
                          '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _dateCard(
                      title: 'TO',
                      value:
                          '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // SUMMARY
              FutureBuilder<Map<String, double>>(
                future: _loadSummary(),

                builder: (context, snap) {
                  final youWillGive = snap.data?['youWillGive'] ?? 0;

                  final youWillGet = snap.data?['youWillGet'] ?? 0;
                  final totalProductSale = snap.data?['totalProductSale'] ?? 0;

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _summaryCard(
                              title: 'YOU WILL GIVE',
                              value: '₹${youWillGive.toStringAsFixed(0)}',
                              color: Colors.red,
                              icon: Icons.arrow_upward,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: _summaryCard(
                              title: 'YOU WILL GET',
                              value: '₹${youWillGet.toStringAsFixed(0)}',
                              color: Colors.green,
                              icon: Icons.arrow_downward,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      _summaryCard(
                        title: 'TOTAL PRODUCT SALE',
                        value: '₹${totalProductSale.toStringAsFixed(0)}',
                        color: Colors.orange,
                        icon: Icons.shopping_bag,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              const Text(
                'CUSTOMERS',

                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),

              const SizedBox(height: 14),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_filteredCustomers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),

                  child: const Center(child: Text('No Customers Found')),
                )
              else
                ListView.separated(
                  shrinkWrap: true,

                  physics: const NeverScrollableScrollPhysics(),

                  itemCount: _filteredCustomers.length,

                  separatorBuilder: (_, __) => const SizedBox(height: 12),

                  itemBuilder: (context, index) {
                    final customer = _filteredCustomers[index];

                    final cid = customer['id'] as int;

                    final name = customer['name'].toString();

                    return FutureBuilder<double>(
                      future: DatabaseHelper().getFinalBalance(cid),

                      builder: (context, snap) {
                        final balance = snap.data ?? 0;

                        final title = _balanceTitle(balance);

                        final color = _balanceColor(balance);

                        return InkWell(
                          borderRadius: BorderRadius.circular(18),

                          onTap: () async {
                            await Navigator.push(
                              context,

                              MaterialPageRoute(
                                builder: (_) => CustomerLedgerDetailScreen(
                                  customerId: cid,

                                  customerName: name,
                                ),
                              ),
                            );

                            _refresh();
                          },

                          child: Container(
                            padding: const EdgeInsets.all(16),

                            decoration: BoxDecoration(
                              color: Colors.white,

                              borderRadius: BorderRadius.circular(18),

                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),

                                  blurRadius: 10,
                                ),
                              ],
                            ),

                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,

                                  backgroundColor: Colors.blue.shade50,

                                  child: const Icon(
                                    Icons.person,

                                    color: Colors.blue,
                                  ),
                                ),

                                const SizedBox(width: 14),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                    children: [
                                      Text(
                                        name,

                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,

                                          fontSize: 15,
                                        ),
                                      ),

                                      const SizedBox(height: 5),

                                      Text(
                                        'Customer ID : $cid',

                                        style: const TextStyle(
                                          color: Colors.grey,

                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,

                                  children: [
                                    Text(
                                      title,

                                      style: TextStyle(
                                        color: color,

                                        fontWeight: FontWeight.bold,

                                        fontSize: 12,
                                      ),
                                    ),

                                    const SizedBox(height: 5),

                                    Text(
                                      '₹${balance.abs().toStringAsFixed(0)}',

                                      style: TextStyle(
                                        color: color,

                                        fontWeight: FontWeight.w900,

                                        fontSize: 20,
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      _balanceSubTitle(balance),

                                      style: TextStyle(
                                        color: Colors.grey.shade600,

                                        fontSize: 11,

                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Icon(icon, color: color),

              const Spacer(),

              Text(
                title,

                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            value,

            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateCard({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,

            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 6),

          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
