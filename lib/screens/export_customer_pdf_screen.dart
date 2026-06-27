import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:aapni_dairy/db/db_helper.dart';
import 'package:aapni_dairy/models/milk_entry.dart';
import 'package:aapni_dairy/constants.dart';

class ExportCustomerPdfScreen extends StatefulWidget {
  @override
  _ExportCustomerPdfScreenState createState() =>
      _ExportCustomerPdfScreenState();
}

class _ExportCustomerPdfScreenState extends State<ExportCustomerPdfScreen> {
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  String _selectedMethod = 'Method 1';

  // OFF => without khatabook (milk table only + totals)
  // ON  => current detailed/khata format
  bool _showKhataBookFormat = false;

  String _selectedPageFormat = 'A4';
  double _titleFontSize = Constants.defaultTitleFontSize;
  double _tableFontSize = Constants.defaultTableFontSize;
  bool _autoFitText = true;

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

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
          if (_start.isAfter(_end)) _end = _start;
        } else {
          _end = picked;
          if (_end.isBefore(_start)) _start = _end;
        }
      });
    }
  }

  // NOTE: Customer summary PDF me dono method ke liye new rate formula apply karna hai.
  // Existing code me rate calculation A*fat + B - snfKatoti thi.
  // Yahi update karke display me mismatch nahi aayega.
  double _calcRate(MilkEntry entry) {
    final snfKatoti = entry.snfKatoti;
    return (Constants.rateConstantA * entry.fat) +
        Constants.rateConstantB -
        snfKatoti;
  }

  double _calcAmount(MilkEntry entry) {
    // Always recalc amount from new rate so Method 2 me bhi consistent rahe.
    return _calcRate(entry) * entry.quantity;
  }

  Map<String, double> _calculateFontSizes(int entryCount) {
    if (!_autoFitText) {
      return {'title': _titleFontSize, 'table': _tableFontSize};
    }

    const double baseTitleSize = 20.0;
    const double baseTableSize = 10.0;
    const int baseEntryCount = 10;

    double scaleFactor = baseEntryCount / entryCount.clamp(1, 50);

    return {
      'title': (baseTitleSize * scaleFactor).clamp(
        Constants.minFontSize,
        Constants.maxFontSize,
      ),
      'table': (baseTableSize * scaleFactor).clamp(
        Constants.minFontSize,
        Constants.maxFontSize,
      ),
    };
  }

  Future<Uint8List> _buildPdfBytes() async {
    try {
      final db = DatabaseHelper();
      final entries = await db.getMilkEntriesInRange(
        DateFormat('yyyy-MM-dd').format(_start),
        DateFormat('yyyy-MM-dd').format(_end),
      );

      if (entries.isEmpty) {
        final pdf = pw.Document();
        pdf.addPage(
          pw.Page(
            build: (context) => pw.Center(
              child: pw.Text('No milk entries found for selected date range.'),
            ),
          ),
        );
        return pdf.save();
      }

      final Map<int, List<MilkEntry>> customerEntries = {};
      final Map<int, String> customerNames = {};

      for (var entry in entries) {
        final custId = entry.customerId;
        if (!customerEntries.containsKey(custId)) {
          customerEntries[custId] = [];
          customerNames[custId] =
              await db.getCustomerNameById(custId) ?? 'Unknown';
        }
        customerEntries[custId]!.add(entry);
      }

      // Sort customer IDs in ascending order
      final sortedCustomerIds = customerEntries.keys.toList()..sort();

      final pdfDoc = pw.Document();

      for (var custId in sortedCustomerIds) {
        final customerName = customerNames[custId]!;
        final custEntries = customerEntries[custId]!;

        // MILK totals
        double totalQuantity = custEntries.fold(
          0,
          (sum, entry) => sum + entry.quantity,
        );
        double totalMilkAmount = custEntries.fold(
          0,
          (sum, entry) => sum + entry.amount,
        );
        // amount is already calculated as payable.
        // SNF katoti / payable deduction ko customer PDF summary me show nahi karna.
        final double totalMilkPayable = totalMilkAmount;

        // Khata totals within selected range

        final startStr = DateFormat('yyyy-MM-dd').format(_start);

        final endStr = DateFormat('yyyy-MM-dd').format(_end);

        // Opening totals (ledger effect) BEFORE startDate
        final openingMilk = await db.getMilkTotalBeforeCustomerDate(
          custId,
          startStr,
        );
        final openingYouGot = await db.getYouGotTotalBeforeCustomerDate(
          custId,
          startStr,
        );
        final openingYouGave = await db.getYouGaveTotalBeforeCustomerDate(
          custId,
          startStr,
        );
        final openingProductSale = await db
            .getProductSaleTotalBeforeCustomerDate(custId, startStr);

        final openingBalance =
            openingMilk + openingYouGot - openingYouGave - openingProductSale;

        final youGotRows = await db.getYouGotEntriesByCustomerAndRange(
          custId,
          startStr,
          endStr,
        );
        final youGaveRows = await db.getYouGaveEntriesByCustomerAndRange(
          custId,
          startStr,
          endStr,
        );
        final productRows = await db.getProductSaleEntriesByCustomerAndRange(
          custId,
          startStr,
          endStr,
        );

        final totalYouGot = youGotRows.fold(
          0.0,
          (sum, r) => sum + (r['amount'] as num).toDouble(),
        );
        final totalYouGave = youGaveRows.fold(
          0.0,
          (sum, r) => sum + (r['amount'] as num).toDouble(),
        );
        final totalProductSale = productRows.fold(
          0.0,
          (sum, r) => sum + (r['amount'] as num).toDouble(),
        );

        // FINAL FORMULA (CustomerLedgerDetailScreen): milk + youGot - youGave - productSale
        final finalBalance =
            totalMilkPayable + totalYouGot - totalYouGave - totalProductSale;

        // Split milk entries into chunks of 30
        final chunks = <List<MilkEntry>>[];
        for (int i = 0; i < custEntries.length; i += 30) {
          chunks.add(
            custEntries.sublist(
              i,
              i + 30 > custEntries.length ? custEntries.length : i + 30,
            ),
          );
        }

        for (int pageIndex = 0; pageIndex < chunks.length; pageIndex++) {
          final chunk = chunks[pageIndex];
          final fontSizes = _calculateFontSizes(chunk.length);

          pdfDoc.addPage(
            pw.Page(
              pageFormat: Constants.pageFormats[_selectedPageFormat]!,
              build: (pw.Context context) {
                final pageWidth =
                    Constants.pageFormats[_selectedPageFormat]!.width;

                final pw.Widget table = _selectedMethod == 'Method 1'
                    ? pw.Table.fromTextArray(
                        headerStyle: pw.TextStyle(
                          fontSize: fontSizes['table'],
                          fontWeight: pw.FontWeight.bold,
                        ),
                        cellStyle: pw.TextStyle(fontSize: fontSizes['table']),
                        headers: const [
                          'Date',
                          'Shift',
                          'Quantity',
                          'Fat',
                          'Rate',
                          'Amount',
                        ],
                        data: chunk
                            .map(
                              (entry) => [
                                DateFormat(
                                  'dd-MM-yyyy',
                                ).format(DateTime.parse(entry.date)),
                                (entry.shift
                                            .toString()
                                            .trim()
                                            .toLowerCase()
                                            .contains('morning') ||
                                        entry.shift
                                                .toString()
                                                .trim()
                                                .toLowerCase() ==
                                            'm')
                                    ? 'M'
                                    : (entry.shift
                                              .toString()
                                              .trim()
                                              .toLowerCase()
                                              .contains('evening') ||
                                          entry.shift
                                                  .toString()
                                                  .trim()
                                                  .toLowerCase() ==
                                              'e')
                                    ? 'E'
                                    : entry.shift.toString(),
                                entry.quantity.toStringAsFixed(2),
                                entry.fat.toStringAsFixed(2),
                                _calcRate(entry).toStringAsFixed(2),
                                _calcAmount(entry).toStringAsFixed(2),
                              ],
                            )
                            .toList(),
                      )
                    : pw.Table.fromTextArray(
                        headerStyle: pw.TextStyle(
                          fontSize: fontSizes['table'],
                          fontWeight: pw.FontWeight.bold,
                        ),
                        cellStyle: pw.TextStyle(fontSize: fontSizes['table']),
                        headers: const [
                          'Date',
                          'Shift',
                          'Quantity',
                          'Fat',
                          'SNF',
                          'Amount',
                        ],
                        data: chunk
                            .map(
                              (entry) => [
                                DateFormat(
                                  'dd-MM-yyyy',
                                ).format(DateTime.parse(entry.date)),
                                (entry.shift
                                            .toString()
                                            .trim()
                                            .toLowerCase()
                                            .contains('morning') ||
                                        entry.shift
                                                .toString()
                                                .trim()
                                                .toLowerCase() ==
                                            'm')
                                    ? 'M'
                                    : (entry.shift
                                              .toString()
                                              .trim()
                                              .toLowerCase()
                                              .contains('evening') ||
                                          entry.shift
                                                  .toString()
                                                  .trim()
                                                  .toLowerCase() ==
                                              'e')
                                    ? 'E'
                                    : entry.shift.toString(),
                                entry.quantity.toStringAsFixed(2),
                                entry.fat.toStringAsFixed(2),
                                entry.snf.toStringAsFixed(2),
                                _calcAmount(entry).toStringAsFixed(2),
                              ],
                            )
                            .toList(),
                      );

                return pw.Container(
                  width: pageWidth * 3 / 4,
                  margin: pw.EdgeInsets.only(right: pageWidth / 4),
                  child: pw.Stack(
                    children: [
                      // Watermark behind content (middle)
                      pw.Positioned.fill(
                        child: pw.Center(
                          child: pw.Opacity(
                            opacity: 0.08,
                            child: pw.Transform.rotate(
                              angle: -0.35,
                              child: pw.Text(
                                'AAPNI DAIRY',
                                style: pw.TextStyle(
                                  fontSize: 48,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Foreground content
                      pw.Column(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.only(top: 40),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  Constants.dairyName,
                                  style: pw.TextStyle(
                                    fontSize: fontSizes['title'],
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  '${Constants.ownerName} Mob:${Constants.mobileNumber}',
                                  style: pw.TextStyle(
                                    fontSize: fontSizes['table'],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          pw.SizedBox(height: 10),

                          pw.Text(
                            'Customer: $customerName (ID: $custId)',
                            style: pw.TextStyle(fontSize: fontSizes['table']),
                          ),
                          pw.Text(
                            'Date Range: ' +
                                DateFormat('dd-MM-yyyy').format(_start) +
                                ' to ' +
                                DateFormat('dd-MM-yyyy').format(_end),
                            style: pw.TextStyle(fontSize: fontSizes['table']),
                          ),
                          pw.SizedBox(height: 10),

                          table,

                          if (pageIndex == chunks.length - 1) ...[
                            pw.SizedBox(height: 20),

                            // Always show totals
                            pw.Text(
                              'Total Quantity: ${totalQuantity.toStringAsFixed(2)}',
                              style: pw.TextStyle(fontSize: fontSizes['table']),
                            ),
                            pw.Text(
                              'Total Amount: ${totalMilkAmount.toStringAsFixed(2)}',
                              style: pw.TextStyle(fontSize: fontSizes['table']),
                            ),

                            if (_showKhataBookFormat) ...[
                              pw.SizedBox(height: 10),
                              pw.Text(
                                'WE GOT: ${totalYouGot.toStringAsFixed(2)} aap se liye',
                                style: pw.TextStyle(
                                  fontSize: fontSizes['table'],
                                ),
                              ),
                              pw.Text(
                                'WE GAVE: ${totalYouGave.toStringAsFixed(2)} aap ko diye',
                                style: pw.TextStyle(
                                  fontSize: fontSizes['table'],
                                ),
                              ),
                              pw.Text(
                                'PRODUCT SALE: ${totalProductSale.toStringAsFixed(2)} ',
                                style: pw.TextStyle(
                                  fontSize: fontSizes['table'],
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                'Opening Balance (Pichla) (before ${DateFormat('dd-MM-yyyy').format(_start)}): ${openingBalance >= 0 ? '+' : '-'}${openingBalance.abs().toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: fontSizes['table'],
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'Final Balance with Opening: ${(openingBalance + finalBalance).toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: fontSizes['table'],
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                (openingBalance + finalBalance) >= 0
                                    ? 'Customer Ko Dena Hai'
                                    : 'Customer Se Lena Hai',
                                style: pw.TextStyle(
                                  fontSize: fontSizes['table'],
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }
      }

      return pdfDoc.save();
    } catch (e, stack) {
      // ignore: avoid_print
      print('Error generating customer PDF: $e\n$stack');
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (context) =>
              pw.Center(child: pw.Text('Error generating PDF.')),
        ),
      );
      return pdf.save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd-MM-yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Customer PDF'),
        backgroundColor: Colors.blue.shade700,
        elevation: 4,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Date Range',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Start Date',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    df.format(_start),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => _pickDate(true),
                                    child: Icon(
                                      Icons.calendar_today,
                                      color: Colors.blue.shade700,
                                      size: 28,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'End Date',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    df.format(_end),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => _pickDate(false),
                                    child: Icon(
                                      Icons.calendar_today,
                                      color: Colors.blue.shade700,
                                      size: 28,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    value: _selectedMethod,
                    items: const [
                      DropdownMenuItem(
                        value: 'Method 1',
                        child: Text('Method 1'),
                      ),
                      DropdownMenuItem(
                        value: 'Method 2',
                        child: Text('Method 2'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedMethod = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Page Format',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: _selectedPageFormat,
                    isExpanded: true,
                    items: Constants.pageFormats.keys
                        .map(
                          (format) => DropdownMenuItem(
                            value: format,
                            child: Text(format),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPageFormat = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Khata Book format',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _showKhataBookFormat,
                        onChanged: (value) =>
                            setState(() => _showKhataBookFormat = value),
                        activeColor: Colors.blue.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Auto-fit Text',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _autoFitText,
                        onChanged: (value) =>
                            setState(() => _autoFitText = value),
                        activeColor: Colors.blue.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (!_autoFitText) ...[
                    Text(
                      'Title Font Size: ${_titleFontSize.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                    Slider(
                      value: _titleFontSize,
                      min: Constants.minFontSize,
                      max: Constants.maxFontSize,
                      divisions: 20,
                      onChanged: (value) =>
                          setState(() => _titleFontSize = value),
                      activeColor: Colors.blue.shade700,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Table Font Size: ${_tableFontSize.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                    Slider(
                      value: _tableFontSize,
                      min: Constants.minFontSize,
                      max: Constants.maxFontSize,
                      divisions: 20,
                      onChanged: (value) =>
                          setState(() => _tableFontSize = value),
                      activeColor: Colors.blue.shade700,
                    ),
                  ],
                ],
              ),
            ),

            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: PdfPreview(
                    build: (format) => _buildPdfBytes(),
                    canChangePageFormat: false,
                    allowPrinting: true,
                    allowSharing: true,
                    loadingWidget: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Generating PDF...',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onError: (context, error) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error generating PDF',
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
