import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:aapni_dairy/constants.dart';
import 'package:aapni_dairy/db/db_helper.dart';
import 'package:aapni_dairy/models/milk_entry.dart';

class MilkEntryScreen extends StatefulWidget {
  const MilkEntryScreen({super.key});

  @override
  State<MilkEntryScreen> createState() => _MilkEntryScreenState();
}

class _MilkEntryScreenState extends State<MilkEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _customerIdController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _snfController = TextEditingController();
  final TextEditingController _snfKatotiController = TextEditingController();

  bool _isEntriesLoading = false;
  List<Map<String, dynamic>> _entriesForSelectedDate = [];

  final FocusNode _customerIdFocus = FocusNode();
  final FocusNode _quantityFocus = FocusNode();
  final FocusNode _fatFocus = FocusNode();
  final FocusNode _snfFocus = FocusNode();
  final FocusNode _snfKatotiFocus = FocusNode();

  String? _customerName;
  DateTime _selectedDate = DateTime.now();
  String _selectedShift = 'Morning';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedShift = _getCurrentShift();
    _refreshEntriesForSelectedDate();
  }

  String _getCurrentShift() {
    final now = DateTime.now();
    return now.hour >= 12 ? 'Evening' : 'Morning';
  }

  Future<void> _fetchCustomerName() async {
    final text = _customerIdController.text.trim();
    if (text.isEmpty) {
      setState(() => _customerName = null);
      return;
    }

    final id = int.tryParse(text);
    if (id == null) {
      setState(() => _customerName = null);
      return;
    }

    final name = await DatabaseHelper().getCustomerNameById(id);
    setState(() => _customerName = name);
  }

  Future<void> _refreshEntriesForSelectedDate() async {
    setState(() => _isEntriesLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _entriesForSelectedDate = await DatabaseHelper()
          .getMilkEntriesWithCustomerByDate(dateStr);
    } finally {
      if (mounted) setState(() => _isEntriesLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _refreshEntriesForSelectedDate();
    }
  }

  Future<void> _saveMilkEntry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final customerId = int.parse(_customerIdController.text.trim());
      final quantity = double.parse(_quantityController.text.trim());
      final fat = double.parse(_fatController.text.trim());

      final snf = _snfController.text.trim().isEmpty
          ? 8.5
          : double.parse(_snfController.text.trim());

      final snfKatoti = _snfKatotiController.text.trim().isEmpty
          ? 0.0
          : double.parse(_snfKatotiController.text.trim());

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // New logic: snfKatoti is per-liter ₹ deduction, so it reduces rate directly.
      final rate =
          (Constants.rateConstantA * fat) + Constants.rateConstantB - snfKatoti;
      final amount = rate * quantity;
      final payableAmount = amount;

      final entry = MilkEntry(
        customerId: customerId,
        date: dateStr,
        shift: _selectedShift,
        quantity: quantity,
        fat: fat,
        snf: snf,
        rate: rate,
        amount: amount,
        snfKatoti: snfKatoti,
      );

      await DatabaseHelper().insertMilkEntry(entry);

      await showDialog<void>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Milk Entry Saved'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✅ Milk entry saved successfully!'),
                const SizedBox(height: 12),
                Text('📌 Rate: ₹${rate.toStringAsFixed(2)} per liter'),
                Text('💰 Amount: ₹${amount.toStringAsFixed(2)}'),
                Text('💸 SNF Katoti: ₹${snfKatoti.toStringAsFixed(2)}'),
                Text('💵 Payable Amount: ₹${payableAmount.toStringAsFixed(2)}'),

                Text('🥛 Quantity: ${quantity.toStringAsFixed(2)} L'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      // Clear milk fields
      _quantityController.clear();
      _fatController.clear();
      _snfController.clear();
      _snfKatotiController.clear();

      // Refresh entries for selected date
      await _refreshEntriesForSelectedDate();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _customerIdController.dispose();
    _quantityController.dispose();
    _fatController.dispose();
    _snfController.dispose();
    _snfKatotiController.dispose();

    _customerIdFocus.dispose();
    _quantityFocus.dispose();
    _fatFocus.dispose();
    _snfFocus.dispose();
    _snfKatotiFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Milk Entry')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: FocusTraversalGroup(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      TextFormField(
                        controller: _customerIdController,
                        focusNode: _customerIdFocus,
                        decoration: const InputDecoration(
                          labelText: 'Customer ID',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _fetchCustomerName(),
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_quantityFocus),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Please enter customer ID';
                          if (int.tryParse(v) == null) {
                            return 'Invalid customer ID';
                          }
                          if (_customerName == null) {
                            return 'Customer not found';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _customerName == null
                            ? 'Customer Name: '
                            : 'Customer Name: $_customerName',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),

                      // Date + Shift
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _pickDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedShift,
                              items: const [
                                DropdownMenuItem(
                                  value: 'Morning',
                                  child: Text('Morning'),
                                ),
                                DropdownMenuItem(
                                  value: 'Evening',
                                  child: Text('Evening'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedShift = value);
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'Shift',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Quantity + Fat
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _quantityController,
                              focusNode: _quantityFocus,
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onFieldSubmitted: (_) => FocusScope.of(
                                context,
                              ).requestFocus(_fatFocus),
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Please enter quantity';
                                if (double.tryParse(v) == null) {
                                  return 'Invalid quantity';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _fatController,
                              focusNode: _fatFocus,
                              decoration: const InputDecoration(
                                labelText: 'Fat',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onFieldSubmitted: (_) => FocusScope.of(
                                context,
                              ).requestFocus(_snfFocus),
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Please enter fat';
                                if (double.tryParse(v) == null) {
                                  return 'Invalid fat';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // SNF + SNF Katoti
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _snfController,
                              focusNode: _snfFocus,
                              decoration: const InputDecoration(
                                labelText: 'SNF (default 8.5)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onFieldSubmitted: (_) => FocusScope.of(
                                context,
                              ).requestFocus(_snfKatotiFocus),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _snfKatotiController,
                              focusNode: _snfKatotiFocus,
                              decoration: const InputDecoration(
                                labelText: 'SNF Katoti (default 0.0)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onFieldSubmitted: (_) => _saveMilkEntry(),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _saveMilkEntry,
                        child: const Text('Save'),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
