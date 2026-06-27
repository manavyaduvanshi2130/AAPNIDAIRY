import 'package:flutter/material.dart';

/// Keeps header actions UI in a separate widget if needed.
/// Currently not wired by default.
class HomeTopActions extends StatelessWidget {
  final VoidCallback onBackup;
  final void Function(int) onMenuSelected;

  const HomeTopActions({
    super.key,
    required this.onBackup,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBackup,
          icon: const Icon(Icons.backup_outlined, color: Colors.white),
          tooltip: 'Backup / Restore',
        ),
        PopupMenuButton<int>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: onMenuSelected,
          itemBuilder: (context) => const [
            PopupMenuItem(value: 0, child: Text('How to Use')),
            PopupMenuItem(value: 1, child: Text('About Us')),
            PopupMenuItem(value: 2, child: Text('Settings')),
          ],
        ),
      ],
    );
  }
}
