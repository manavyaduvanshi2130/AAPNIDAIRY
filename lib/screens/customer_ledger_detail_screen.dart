// REPLACE COMPLETE FILE WITH THIS UPDATED CODE

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aapni_dairy/db/db_helper.dart';
import 'package:aapni_dairy/models/product.dart';
import 'package:aapni_dairy/widgets/custom_date_picker.dart';

class CustomerLedgerDetailScreen extends StatefulWidget {
  final int customerId;
  final String customerName;

  const CustomerLedgerDetailScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CustomerLedgerDetailScreen> createState() =>
      _CustomerLedgerDetailScreenState();
}

enum _TxnType { milk, productSale, youGave, youGot }

class _TxnItem {
  final _TxnType type;
  final int? id;
  final DateTime dateTime;
  final String title;
  final String note;
  final double amount;

  final String? productName;
  final double? productRate;
  final double? quantity;

  _TxnItem({
    required this.type,
    required this.id,
    required this.dateTime,
    required this.title,
    required this.note,
    required this.amount,
    this.productName,
    this.productRate,
    this.quantity,
  });
}

class _CustomerLedgerDetailScreenState
    extends State<CustomerLedgerDetailScreen> {
  DateTime _ledgerSelectedDate = DateTime.now();
  bool _useDateFilter = false;
  final _db = DatabaseHelper();

  bool _isLoading = false;

  List<_TxnItem> _items = [];

  final _youGaveAmountCtl = TextEditingController();
  final _youGotAmountCtl = TextEditingController();
  final _noteCtl = TextEditingController();

  final _productSaleQtyCtl = TextEditingController();

  Product? _selectedProduct;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _youGaveAmountCtl.dispose();
    _youGotAmountCtl.dispose();
    _noteCtl.dispose();
    _productSaleQtyCtl.dispose();
    super.dispose();
  }

  DateTime _parseDbDate(String s) {
    try {
      return DateTime.parse(s);
    } catch (_) {
      try {
        final d = DateFormat('yyyy-MM-dd').parse(s);
        return DateTime(d.year, d.month, d.day);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);

    final cid = widget.customerId;

    try {
      final endDateStr = DateFormat('yyyy-MM-dd').format(_ledgerSelectedDate);
      final startDateStr =
          '2000-01-01'; // upper date tak, usse pehle sab show karne ke liye

      // MILK
      final milkEntries = _useDateFilter
          ? await _db.getMilkEntriesByCustomerAndRange(
              cid,
              startDateStr,
              endDateStr,
            )
          : await _db.getMilkEntriesByCustomer(cid);

      final milkItems = milkEntries.map<_TxnItem>((e) {
        final payable = e.amount;
        return _TxnItem(
          type: _TxnType.milk,
          id: e.id,
          dateTime: _parseDbDate(e.date),
          title: 'Milk Entry',
          note: '${e.shift} • ${e.quantity.toStringAsFixed(2)} L',
          amount: payable,
        );
      }).toList();

      // YOU GOT
      final youGotRows = _useDateFilter
          ? await _db.getYouGotEntriesByCustomerAndRange(
              cid,
              startDateStr,
              endDateStr,
            )
          : await _db.getYouGotEntriesByCustomer(cid);

      final youGotItems = youGotRows.map<_TxnItem>((row) {
        return _TxnItem(
          type: _TxnType.youGot,
          id: row['id'],
          dateTime: _parseDbDate(row['date'].toString()),
          title: 'You Got',
          note: row['note']?.toString() ?? '',
          amount: (row['amount'] as num).toDouble(),
        );
      }).toList();

      // YOU GAVE
      final youGaveRows = _useDateFilter
          ? await _db.getYouGaveEntriesByCustomerAndRange(
              cid,
              startDateStr,
              endDateStr,
            )
          : await _db.getYouGaveEntriesByCustomer(cid);

      final youGaveItems = youGaveRows.map<_TxnItem>((row) {
        return _TxnItem(
          type: _TxnType.youGave,
          id: row['id'],
          dateTime: _parseDbDate(row['date'].toString()),
          title: 'You Gave',
          note: row['note']?.toString() ?? '',
          amount: (row['amount'] as num).toDouble(),
        );
      }).toList();

      // PRODUCT SALES
      final productRows = _useDateFilter
          ? await _db.getProductSaleEntriesByCustomerAndRange(
              cid,
              startDateStr,
              endDateStr,
            )
          : await _db.getProductSaleEntriesByCustomer(cid);

      final productItems = productRows.map<_TxnItem>((row) {
        return _TxnItem(
          type: _TxnType.productSale,
          id: row['id'],
          dateTime: _parseDbDate(row['date'].toString()),
          title: 'Product Sale',
          note: row['note']?.toString() ?? '',
          amount: (row['amount'] as num).toDouble(),
          productName: row['product_name']?.toString(),
          productRate: (row['product_rate'] as num?)?.toDouble(),
          quantity: (row['quantity'] as num?)?.toDouble(),
        );
      }).toList();

      _items = [...milkItems, ...youGotItems, ...youGaveItems, ...productItems];

      // NEWEST FIRST
      _items.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => _isLoading = false);
  }

  double _finalBalance() {
    double milk = 0;
    double youGot = 0;
    double youGave = 0;
    double productSale = 0;

    for (final item in _items) {
      switch (item.type) {
        case _TxnType.milk:
          milk += item.amount;
          break;

        case _TxnType.youGot:
          youGot += item.amount;
          break;

        case _TxnType.youGave:
          youGave += item.amount;
          break;

        case _TxnType.productSale:
          productSale += item.amount;
          break;
      }
    }

    return milk + youGot - youGave - productSale;
  }

  String _formatMoney(double v) {
    return '₹${v.toStringAsFixed(0)}';
  }

  Color _balanceColor(double v) {
    if (v > 0) return Colors.red;
    if (v < 0) return Colors.green;
    return Colors.grey;
  }

  Color _txnColor(_TxnType type) {
    switch (type) {
      case _TxnType.milk:
        return Colors.blue;

      case _TxnType.youGot:
        return Colors.green;

      case _TxnType.youGave:
        return Colors.red;

      case _TxnType.productSale:
        return Colors.orange;
    }
  }

  IconData _txnIcon(_TxnType type) {
    switch (type) {
      case _TxnType.milk:
        return Icons.water_drop;

      case _TxnType.youGot:
        return Icons.arrow_downward;

      case _TxnType.youGave:
        return Icons.arrow_upward;

      case _TxnType.productSale:
        return Icons.shopping_bag;
    }
  }

  // ================= YOU GAVE =================

  Future<void> _addYouGave() async {
    _youGaveAmountCtl.clear();
    _noteCtl.clear();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('You Gave'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _youGaveAmountCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtl,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final amount = double.tryParse(_youGaveAmountCtl.text.trim()) ?? 0;

    if (amount <= 0) return;

    await _db.insertYouGave(
      customerId: widget.customerId,
      date: DateFormat('yyyy-MM-dd').format(_ledgerSelectedDate),
      note: _noteCtl.text.trim(),
      amount: amount,
    );

    await _refresh();
  }

  // ================= YOU GOT =================

  Future<void> _addYouGot() async {
    _youGotAmountCtl.clear();
    _noteCtl.clear();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('You Got'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _youGotAmountCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteCtl,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final amount = double.tryParse(_youGotAmountCtl.text.trim()) ?? 0;

    if (amount <= 0) return;

    await _db.insertYouGot(
      customerId: widget.customerId,
      date: DateFormat('yyyy-MM-dd').format(_ledgerSelectedDate),
      note: _noteCtl.text.trim(),
      amount: amount,
    );

    await _refresh();
  }

  // ================= PRODUCT SALE =================

  Future<void> _addProductSale() async {
    _selectedProduct = null;
    _productSaleQtyCtl.clear();

    final products = await _db.getAllProducts();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final qty = double.tryParse(_productSaleQtyCtl.text.trim()) ?? 0;

            final total = (_selectedProduct?.rate ?? 0) * qty;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Product>(
                      value: _selectedProduct,
                      items: products.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(
                            '${p.name} - ₹${p.rate.toStringAsFixed(0)}',
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setModal(() {
                          _selectedProduct = v;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Select Product',
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: _productSaleQtyCtl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      onChanged: (_) => setModal(() {}),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Total : ₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final qtyVal =
                              double.tryParse(_productSaleQtyCtl.text.trim()) ??
                              0;

                          if (_selectedProduct == null || qtyVal <= 0) {
                            return;
                          }

                          Navigator.pop(ctx, true);
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (ok != true) return;

    final qty = double.tryParse(_productSaleQtyCtl.text.trim()) ?? 0;

    final total = (_selectedProduct?.rate ?? 0) * qty;

    await _db.insertProductSaleDetailed(
      customerId: widget.customerId,
      date: DateFormat('yyyy-MM-dd').format(_ledgerSelectedDate),
      note: '',
      productId: _selectedProduct!.id ?? 0,
      productName: _selectedProduct!.name,
      productRate: _selectedProduct!.rate,
      quantity: qty,
      amount: total,
    );

    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final balance = _finalBalance();

    double running = balance;

    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),

      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Text(widget.customerName),
        centerTitle: true,
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'gave',
            backgroundColor: Colors.red,
            onPressed: _addYouGave,
            icon: const Icon(Icons.arrow_upward, color: Colors.white),
            label: const Text(
              'YOU GAVE',
              style: TextStyle(color: Colors.white),
            ),
          ),

          const SizedBox(height: 10),

          FloatingActionButton.extended(
            heroTag: 'product',
            backgroundColor: Colors.orange,
            onPressed: _addProductSale,
            icon: const Icon(Icons.shopping_bag, color: Colors.white),
            label: const Text('PRODUCT', style: TextStyle(color: Colors.white)),
          ),

          const SizedBox(height: 10),

          FloatingActionButton.extended(
            heroTag: 'got',
            backgroundColor: Colors.green,
            onPressed: _addYouGot,
            icon: const Icon(Icons.arrow_downward, color: Colors.white),
            label: const Text('YOU GOT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // DATE FILTER
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  child: CustomDatePicker(
                    selectedDate: _ledgerSelectedDate,
                    label: 'Ledger Date',
                    onDateSelected: (d) {
                      setState(() {
                        _ledgerSelectedDate = d;
                        _useDateFilter = true;
                      });
                      _refresh();
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // BALANCE CARD
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'FINAL BALANCE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        _formatMoney(balance),
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: _balanceColor(balance),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        balance > 0
                            ? 'Customer Ko Dena Hai'
                            : balance < 0
                            ? 'Customer Se Lena Hai'
                            : 'Balance Clear',
                        style: TextStyle(
                          color: _balanceColor(balance),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('No Ledger Found'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];

                            final currentRunning = running;

                            switch (item.type) {
                              case _TxnType.milk:
                                running -= item.amount;
                                break;

                              case _TxnType.youGot:
                                running -= item.amount;
                                break;

                              case _TxnType.youGave:
                                running += item.amount;
                                break;

                              case _TxnType.productSale:
                                running += item.amount;
                                break;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _txnColor(
                                      item.type,
                                    ).withOpacity(0.12),
                                    child: Icon(
                                      _txnIcon(item.type),
                                      color: _txnColor(item.type),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        const SizedBox(height: 4),

                                        if (item.type == _TxnType.productSale)
                                          Text(
                                            '${item.productName} × ${item.quantity}',
                                          ),

                                        if (item.note.isNotEmpty)
                                          Text(
                                            item.note,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),

                                        const SizedBox(height: 4),

                                        Text(
                                          DateFormat(
                                            'dd MMM yyyy',
                                          ).format(item.dateTime),
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
                                        _formatMoney(item.amount),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _txnColor(item.type),
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      Text(
                                        'Bal : ${_formatMoney(currentRunning)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
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
