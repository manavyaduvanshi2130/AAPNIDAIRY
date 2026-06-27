import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDatePicker extends StatelessWidget {
  final DateTime selectedDate;

  // Optional range (used by some screens)
  final DateTime? firstDate;
  final DateTime? lastDate;

  // Optional label (used by some screens)
  final String? label;

  // Support both callback names: onPicked (older) + onDateSelected (current usage)
  final void Function(DateTime picked)? onPicked;
  final void Function(DateTime date)? onDateSelected;

  const CustomDatePicker({
    Key? key,
    required this.selectedDate,
    this.firstDate,
    this.lastDate,
    this.label,
    this.onPicked,
    this.onDateSelected,
  }) : super(key: key);

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime.now(),
    );

    if (picked == null) return;

    if (onDateSelected != null) {
      onDateSelected!(picked);
    } else if (onPicked != null) {
      onPicked!(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$label: ${DateFormat('yyyy-MM-dd').format(selectedDate)}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
