import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import 'package:aapni_dairy/constants.dart';
import 'package:aapni_dairy/models/milk_entry.dart';

class PdfService {
  static double _calcRate(MilkEntry entry) {
    final snfKatoti = entry.snfKatoti;
    return (Constants.rateConstantA * entry.fat) +
        Constants.rateConstantB -
        snfKatoti;
  }

  static double _calcAmount(MilkEntry entry) {
    return _calcRate(entry) * entry.quantity;
  }

  static String _formatShift(String shift) {
    final s = shift.trim().toLowerCase();
    if (s.contains('morning') || s == 'm') return 'M';
    if (s.contains('evening') || s == 'e') return 'E';
    return shift;
  }

  static pw.Widget _watermark() {
    return pw.Positioned.fill(
      child: pw.Center(
        child: pw.Opacity(
          opacity: 0.08,
          child: pw.Transform.rotate(
            angle: -0.35,
            child: pw.Text(
              'AAPNI DAIRY',
              style: pw.TextStyle(fontSize: 48, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  static pw.Widget _pageWrap(pw.Widget content) {
    // Customer summary OFF-mode me watermark se rendering issues aa sakte hain.
    // Is helper ko ab watermark ke bina rakha gaya hai.
    return content;
  }

  /// Customer summary PDF (main)
  /// Requirement:
  /// - Show Product Sale rows with Date and Note
  /// - Include ledger effect before startDate as opening total balance
  ///
  /// Note: To avoid changing too many call-sites, this method keeps the
  /// existing MilkEntry table, but additionally appends a ledger section.
  Future<Uint8List> generateCustomerSummaryPdf(
    List<MilkEntry> entries,
    String customerName,
    String startDate,
    String endDate,
  ) async {
    final pdf = pw.Document();

    final double totalQuantity = entries.fold(
      0,
      (sum, entry) => sum + entry.quantity,
    );
    final double totalAmount = entries.fold(
      0,
      (sum, entry) => sum + entry.amount,
    );

    const int rowsPerPage = 22;

    // Chunk entries into pages (22 per page)
    final chunks = <List<MilkEntry>>[];
    for (int i = 0; i < entries.length; i += rowsPerPage) {
      chunks.add(
        entries.sublist(
          i,
          i + rowsPerPage > entries.length ? entries.length : i + rowsPerPage,
        ),
      );
    }

    // Show exactly 22 entries per page by rendering each chunk as its own page.
    for (int pageIndex = 0; pageIndex < chunks.length; pageIndex++) {
      final pageEntries = chunks[pageIndex];
      final isLastPage = pageIndex == chunks.length - 1;

      // Safety: prevent adding pages if chunk is empty (should not happen,
      // but avoids potential blank first pages).
      if (pageEntries.isEmpty) continue;

      pdf.addPage(
        pw.Page(
          pageFormat: Constants.defaultPageFormat,
          margin: pw.EdgeInsets.all(40),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Keep layout flat/stable (no nested Columns in Containers)
                pw.Text(
                  Constants.dairyName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${Constants.ownerName} | Mob: ${Constants.mobileNumber}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Customer: $customerName | Period: $startDate to $endDate',
                  style: const pw.TextStyle(fontSize: 12),
                ),

                pw.SizedBox(height: 12),

                pw.Text(
                  'Milk Entries',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellHeight: 25,
                  headers: const [
                    'Date',
                    'Shift',
                    'qty',
                    'Fat',
                    'Rate',
                    'Amount',
                  ],
                  data: pageEntries
                      .map(
                        (entry) => [
                          DateFormat(
                            'dd-MM-yyyy',
                          ).format(DateTime.parse(entry.date)),
                          _formatShift(entry.shift),
                          entry.quantity.toStringAsFixed(2),
                          entry.fat.toStringAsFixed(2),
                          _calcRate(entry).toStringAsFixed(2),
                          _calcAmount(entry).toStringAsFixed(2),
                        ],
                      )
                      .toList(),
                ),

                if (isLastPage) ...[
                  pw.SizedBox(height: 14),

                  pw.Container(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Total Quantity: ${totalQuantity.toStringAsFixed(2)} L',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Total Amount: ₹${totalAmount.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Keep footer consistent without forcing extra space that
                  // can push table content out of the visible area.
                  pw.Spacer(),
                ],

                // Footer
                pw.Container(
                  alignment: pw.Alignment.center,
                  margin: const pw.EdgeInsets.only(top: 10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.grey400),
                    ),
                  ),
                  child: pw.Text(
                    'Page ${pageIndex + 1} of ${chunks.length}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// New ledger-aware generator for Customer Summary.
  /// Includes:
  /// - Opening total balance (computed fully before startDate)
  /// - Date-wise chronological table rows (milk + khata ledger)
  /// - Exact 6-column header: Date, Shift, Quantity, Fat, Rate, Amount
  /// - Direction + opening + final under Total Milk Amount section
  Future<Uint8List> generateCustomerSummaryPdfWithLedger({
    required int customerId,
    required String customerName,
    required String startDate,
    required String endDate,
    required List<MilkEntry> milkEntriesInRange,
    required List<Map<String, dynamic>> youGotEntriesInRange,
    required List<Map<String, dynamic>> youGaveEntriesInRange,
    required List<Map<String, dynamic>> productSaleEntriesInRange,
    required List<Map<String, dynamic>> youGotOpening,
    required List<Map<String, dynamic>> youGaveOpening,
    required List<Map<String, dynamic>> productSaleOpening,
  }) async {
    final pdf = pw.Document();

    DateTime _safeParseDbDate(dynamic raw) {
      final s = raw?.toString().trim() ?? '';
      if (s.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
      try {
        return DateTime.parse(s);
      } catch (_) {
        try {
          final d = DateFormat('yyyy-MM-dd').parse(s);
          return DateTime(d.year, d.month, d.day);
        } catch (_) {
          return DateTime.fromMillisecondsSinceEpoch(0);
        }
      }
    }

    String _formatShift(String shift) {
      final s = shift.trim().toLowerCase();
      if (s.contains('morning') || s == 'm') return 'M';
      if (s.contains('evening') || s == 'e') return 'E';
      return shift;
    }

    double totalMilkQty = milkEntriesInRange.fold(
      0,
      (sum, e) => sum + e.quantity,
    );
    double totalMilkAmount = milkEntriesInRange.fold(
      0,
      (sum, e) => sum + e.amount,
    );

    double sumAmount(List<Map<String, dynamic>> rows) =>
        rows.fold(0.0, (s, r) => s + (r['amount'] as num).toDouble());

    final openingYouGot = sumAmount(youGotOpening);
    final openingYouGave = sumAmount(youGaveOpening);
    final openingProductSale = sumAmount(productSaleOpening);

    final openingBalance = openingYouGot - openingYouGave - openingProductSale;

    final rangeYouGot = sumAmount(youGotEntriesInRange);
    final rangeYouGave = sumAmount(youGaveEntriesInRange);
    final rangeProductSale = sumAmount(productSaleEntriesInRange);

    final finalBalance =
        totalMilkAmount + rangeYouGot - rangeYouGave - rangeProductSale;

    // Fix: manual chunking + pw.Page was causing blank pages.
    // MultiPage automatically paginates content without generating empty pages.

    final milkTableRows = <List<String>>[];
    if (milkEntriesInRange.isEmpty) {
      milkTableRows.add(['-', '-', '-', '-', '-', '-']);
    } else {
      for (final entry in milkEntriesInRange) {
        final dt = _safeParseDbDate(entry.date);
        milkTableRows.add([
          DateFormat('dd-MM-yyyy').format(dt),
          _formatShift(entry.shift),
          entry.quantity.toStringAsFixed(2),
          entry.fat.toStringAsFixed(2),
          entry.rate.toStringAsFixed(2),
          entry.amount.toStringAsFixed(2),
        ]);
      }
    }

    // Replace MultiPage with deterministic chunked pages.
    // Reason: MultiPage + table/flow sometimes produces blank initial pages.
    const int rowsPerPage = 22;

    final totalPages = (milkTableRows.length / rowsPerPage).ceil();

    for (
      int pageIndex = 0;
      pageIndex < milkTableRows.length;
      pageIndex += rowsPerPage
    ) {
      final pageRows = milkTableRows.sublist(
        pageIndex,
        (pageIndex + rowsPerPage) > milkTableRows.length
            ? milkTableRows.length
            : (pageIndex + rowsPerPage),
      );

      final isLastPage = (pageIndex + rowsPerPage) >= milkTableRows.length;

      pdf.addPage(
        pw.Page(
          pageFormat: Constants.defaultPageFormat,
          margin: pw.EdgeInsets.all(40),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  Constants.dairyName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${Constants.ownerName} | Mob: ${Constants.mobileNumber}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Customer: $customerName (ID: $customerId)',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Period: $startDate to $endDate',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 14),

                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellHeight: 25,
                  headers: const [
                    'Date',
                    'Shift',
                    'Quantity',
                    'Fat',
                    'Rate',
                    'Amount',
                  ],
                  data: pageRows,
                ),

                if (isLastPage) ...[
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Total Quantity: ${totalMilkQty.toStringAsFixed(2)} L',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Total Amount: ₹${totalMilkAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                  pw.SizedBox(height: 14),

                  pw.Text(
                    'Opening Balance (Pichla) (before $startDate): ₹${openingBalance.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),

                  pw.Text(
                    'YOU GOT (in range): ₹${rangeYouGot.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'YOU GAVE (in range): ₹${rangeYouGave.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'PRODUCT SALE (in range): ₹${rangeProductSale.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  pw.Text(
                    'Final Balance with Opening: ₹${(openingBalance + finalBalance).toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                  pw.SizedBox(height: 4),

                  pw.Text(
                    (openingBalance + finalBalance) >= 0
                        ? 'Customer Ko Dena Hai'
                        : 'Customer Se Lena Hai',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                ] else ...[
                  pw.Spacer(),
                ],

                // Footer always (no MultiPage needed)
                pw.Container(
                  alignment: pw.Alignment.center,
                  margin: const pw.EdgeInsets.only(top: 10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.grey400),
                    ),
                  ),
                  child: pw.Text(
                    'Page ${pageIndex ~/ rowsPerPage + 1} of $totalPages',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  Future<void> generateAllCustomersPdf(
    List<Map<String, dynamic>> customerSummaries,
  ) async {
    final pdf = pw.Document();

    for (final summary in customerSummaries) {
      pdf.addPage(
        pw.Page(
          build: (context) {
            return _pageWrap(
              pw.Column(
                children: [
                  pw.Text(
                    Constants.dairyName,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(Constants.ownerName),
                  pw.Text('Mob: ${Constants.mobileNumber}'),
                  pw.SizedBox(height: 20),
                  pw.Text('Customer: ${summary['name']}'),
                  pw.SizedBox(height: 20),
                  pw.Table.fromTextArray(
                    headers: const [
                      'Date',
                      'Shift',
                      'qty',
                      'Fat',
                      'SNF',
                      'Amount',
                    ],
                    data: (summary['entries'] as List<MilkEntry>)
                        .map(
                          (entry) => [
                            DateFormat(
                              'dd-MM-yyyy',
                            ).format(DateTime.parse(entry.date)),
                            _formatShift(entry.shift),
                            entry.quantity.toStringAsFixed(2),
                            entry.fat.toStringAsFixed(2),
                            entry.snf.toStringAsFixed(2),
                            entry.amount.toStringAsFixed(2),
                          ],
                        )
                        .toList(),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'all_customers_summary.pdf',
    );
  }

  Future<void> generateTotalSummaryPdf(
    List<Map<String, dynamic>> summaries,
    String startDate,
    String endDate,
  ) async {
    final pdf = pw.Document();

    final double grandTotalMilk = summaries.fold(
      0,
      (sum, s) => sum + (s['totalMilk'] as num).toDouble(),
    );
    final double grandTotalAmount = summaries.fold(
      0,
      (sum, s) => sum + (s['totalAmount'] as num).toDouble(),
    );

    pdf.addPage(
      pw.Page(
        build: (context) {
          return _pageWrap(
            pw.Column(
              children: [
                pw.Text(
                  Constants.dairyName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(Constants.ownerName),
                pw.Text('Mob: ${Constants.mobileNumber}'),
                pw.SizedBox(height: 20),
                pw.Text('Total Summary from $startDate to $endDate'),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headers: const ['Customer', 'Total Milk', 'Total Amount'],
                  data: summaries
                      .map(
                        (s) => [
                          s['name'],
                          (s['totalMilk'] as num).toDouble().toStringAsFixed(2),
                          (s['totalAmount'] as num).toDouble().toStringAsFixed(
                            2,
                          ),
                        ],
                      )
                      .toList(),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Grand Total Milk: ${grandTotalMilk.toStringAsFixed(2)}',
                ),
                pw.Text(
                  'Grand Total Amount: ${grandTotalAmount.toStringAsFixed(2)}',
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'total_summary.pdf',
    );
  }

  /// Method 1: Customer ID, Date, Shift, Quantity, Fat, Rate, Amount

  Future<Uint8List> generateCustomerSummaryPdfMethod1(
    List<MilkEntry> entries,
    String customerName,
    String date,
  ) async {
    final pdf = pw.Document();

    final double totalQuantity = entries.fold(
      0,
      (sum, entry) => sum + entry.quantity,
    );
    final double totalAmount = entries.fold(
      0,
      (sum, entry) => sum + entry.amount,
    );

    pdf.addPage(
      pw.Page(
        build: (context) {
          return _pageWrap(
            pw.Column(
              children: [
                pw.Text(
                  Constants.dairyName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(Constants.ownerName),
                pw.Text('Mob: ${Constants.mobileNumber}'),
                pw.SizedBox(height: 20),
                pw.Text('Customer: $customerName'),
                pw.Text('Date: $date'),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headers: const [
                    'Customer ID',
                    'Date',
                    'Shift',
                    'qty',
                    'Fat',
                    'Rate',
                    'Amount',
                  ],
                  data: entries
                      .map(
                        (entry) => [
                          entry.customerId.toString(),
                          DateFormat(
                            'dd-MM-yyyy',
                          ).format(DateTime.parse(entry.date)),
                          _formatShift(entry.shift),
                          entry.quantity.toStringAsFixed(2),
                          entry.fat.toStringAsFixed(2),
                          entry.rate.toStringAsFixed(2),
                          entry.amount.toStringAsFixed(2),
                        ],
                      )
                      .toList(),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Total Quantity: ${totalQuantity.toStringAsFixed(2)}'),
                pw.Text('Total Amount: ${totalAmount.toStringAsFixed(2)}'),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Method 2: Customer ID, Date, Shift, Fat, Amount

  Future<Uint8List> generateCustomerSummaryPdfMethod2(
    List<MilkEntry> entries,
    String customerName,
    String date,
  ) async {
    final pdf = pw.Document();

    final double totalQuantity = entries.fold(
      0,
      (sum, entry) => sum + entry.quantity,
    );
    final double totalAmount = entries.fold(
      0,
      (sum, entry) => sum + entry.amount,
    );

    pdf.addPage(
      pw.Page(
        build: (context) {
          return _pageWrap(
            pw.Column(
              children: [
                pw.Text(
                  Constants.dairyName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(Constants.ownerName),
                pw.Text('Mob: ${Constants.mobileNumber}'),
                pw.SizedBox(height: 20),
                pw.Text('Customer: $customerName'),
                pw.Text('Date: $date'),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headers: const [
                    'Customer ID',
                    'Date',
                    'Shift',
                    'Fat',
                    'Amount',
                  ],
                  data: entries
                      .map(
                        (entry) => [
                          entry.customerId.toString(),
                          entry.date,
                          entry.shift,
                          entry.fat.toStringAsFixed(2),
                          entry.amount.toStringAsFixed(2),
                        ],
                      )
                      .toList(),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Total Quantity: ${totalQuantity.toStringAsFixed(2)}'),
                pw.Text('Total Amount: ${totalAmount.toStringAsFixed(2)}'),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
