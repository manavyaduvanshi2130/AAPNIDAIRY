// ================= HOME SCREEN FINAL UPDATED UI =================
// Replace your complete HomeScreen code with this

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:marquee/marquee.dart';

import '../constants.dart';
import '../db/db_helper.dart';
import '../services/drive_service.dart';

enum _BackupAction { backup, restore }

class HomeScreen extends StatefulWidget {
  final String dairyName;
  final String ownerName;
  final String mobileNumber;

  const HomeScreen({
    super.key,
    required this.dairyName,
    required this.ownerName,
    required this.mobileNumber,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DriveService _driveService = DriveService();

  bool _isBackupLoading = false;

  late Future<_HomeStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _refreshStats();

    // App open on Home screen: always show Backup & Restore dialog.
    // Use post-frame to avoid "setState during build" issues.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Avoid re-opening the dialog while a previous one is still active.
      _showBackupRestoreDialog();
    });
  }

  void _refreshStats() {
    setState(() {
      _statsFuture = _loadStats();
    });
  }

  Future<void> _showBackupRestoreDialog() async {
    if (_isBackupLoading) return;

    setState(() => _isBackupLoading = true);

    try {
      final action = await showDialog<_BackupAction>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backup & Restore'),
          content: const Text('Choose an action'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _BackupAction.backup),
              child: const Text('Backup to Drive'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _BackupAction.restore),
              child: const Text('Restore from Drive'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (action == null || !mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      if (action == _BackupAction.backup) {
        final data = await DatabaseHelper().getAllDataForBackup();

        final ok = await _driveService.uploadBackup(data);

        if (mounted) Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Backup Success!' : 'Backup Failed!')),
        );
      } else {
        final data = await _driveService.downloadBackup();

        if (mounted) Navigator.pop(context);

        if (data != null) {
          await DatabaseHelper().restoreFromBackup(data);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restore Success! Restart App')),
          );

          _refreshStats();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No Backup Found!')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isBackupLoading = false);
      }
    }
  }

  Future<_HomeStats> _loadStats() async {
    final db = DatabaseHelper();

    final now = DateTime.now();

    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      final monthStart = DateTime(now.year, now.month, 1);

      final monthEnd = DateTime(now.year, now.month + 1, 0);

      final monthEntries = await db.getMilkEntriesInRange(
        DateFormat('yyyy-MM-dd').format(monthStart),
        DateFormat('yyyy-MM-dd').format(monthEnd),
      );

      final todayEntries = await db.getMilkEntriesByDate(todayStr);

      final todayMilk = todayEntries.fold<double>(
        0,
        (sum, e) => sum + e.quantity,
      );

      final monthlyRevenue = monthEntries.fold<double>(
        0,
        (sum, e) => sum + e.amount,
      );

      final customers = await db.getAllCustomers();

      return _HomeStats(
        todayMilk: todayMilk,
        monthlyRevenue: monthlyRevenue,
        totalCustomers: customers.length,
      );
    } catch (e) {
      return const _HomeStats(
        todayMilk: 0,
        monthlyRevenue: 0,
        totalCustomers: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _refreshStats();
            await _statsFuture;
          },
          child: FutureBuilder<_HomeStats>(
            future: _statsFuture,
            builder: (context, snapshot) {
              final stats = snapshot.data;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // ================= HEADER =================
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xff1565C0), Color(0xff1E88E5)],
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.account_balance,
                                color: Colors.white,
                                size: 30,
                              ),

                              const SizedBox(width: 10),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.dairyName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      widget.ownerName,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // REFRESH BUTTON
                              InkWell(
                                onTap: _refreshStats,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.refresh,
                                    color: Colors.white,
                                  ),
                                ),
                              ),

                              // BACKUP BUTTON
                              InkWell(
                                onTap: _showBackupRestoreDialog,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.backup,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Marquee(
                                text:
                                    'Your data stays only with you. Take regular Google Drive backup for data safety.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                blankSpace: 40,
                                velocity: 30,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ================= STATS =================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _smallStatCard(
                              'Milk',
                              '${stats?.todayMilk.toStringAsFixed(1) ?? "0"}',
                              Icons.local_drink,
                              Colors.blue,
                            ),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: _smallStatCard(
                              'Revenue',
                              '₹${stats?.monthlyRevenue.toStringAsFixed(0) ?? "0"}',
                              Icons.currency_rupee,
                              Colors.green,
                            ),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: _smallStatCard(
                              'Customers',
                              '${stats?.totalCustomers ?? 0}',
                              Icons.people,
                              Colors.purple,
                            ),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: _smallStatCard(
                              'Backup',
                              'Drive',
                              Icons.cloud_done,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ================= QUICK ACTIONS TITLE =================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ================= QUICK ACTIONS =================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: .82,
                        children: [
                          _menuCard(
                            'Customer',
                            Icons.person_add,
                            Colors.green,
                            '/customer_registration',
                          ),

                          _menuCard(
                            'Milk Entry',
                            Icons.local_drink,
                            Colors.blue,
                            '/milk_entry',
                          ),

                          _menuCard(
                            'Edit Entry',
                            Icons.edit_note,
                            Colors.orange,
                            '/edit_delete_entries',
                          ),

                          _menuCard(
                            'Edit Rate',
                            Icons.currency_rupee,
                            Colors.purple,
                            '/edit_rate',
                          ),

                          _menuCard(
                            'KhataBook',
                            Icons.menu_book,
                            Colors.teal,
                            '/khata_ledger',
                          ),

                          _menuCard(
                            'Products',
                            Icons.shopping_bag,
                            Colors.pink,
                            '/products',
                          ),

                          _menuCard(
                            'Settings',
                            Icons.settings,
                            Colors.indigo,
                            '/settings',
                          ),

                          _menuCard(
                            'How to Use',
                            Icons.help_outline,
                            Colors.blueGrey,
                            '/how_to_use',
                          ),

                          _menuCard(
                            'About',
                            Icons.info,
                            Colors.brown,
                            '/about_us',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ================= REPORTS =================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Reports',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _reportCard(
                            'Daily\nSummary',
                            Icons.calendar_month,
                            Colors.blue,
                            '/daily_summary',
                          ),

                          _reportCard(
                            'Customer\nSummary',
                            Icons.people_alt,
                            Colors.green,
                            '/customer_summary_pdf',
                          ),

                          _reportCard(
                            'Total\nSummary',
                            Icons.summarize,
                            Colors.purple,
                            '/total_summary_pdf',
                          ),

                          _reportCard(
                            'Export\nTotal PDF',
                            Icons.picture_as_pdf,
                            Colors.red,
                            '/export_total_pdf',
                          ),

                          _reportCard(
                            'Customer\nPDF',
                            Icons.file_download,
                            Colors.orange,
                            '/export_customer_pdf',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    if (Constants.madeBy.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          Constants.madeBy,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ================= SMALL STAT CARD =================

  Widget _smallStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      height: 95,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),

          const SizedBox(height: 8),

          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            value,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ================= MENU CARD =================

  Widget _menuCard(String title, IconData icon, Color color, String route) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= REPORT CARD =================

  Widget _reportCard(String title, IconData icon, Color color, String route) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 34),

            const SizedBox(height: 12),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= MODEL =================

class _HomeStats {
  final double todayMilk;
  final double monthlyRevenue;
  final int totalCustomers;

  const _HomeStats({
    required this.todayMilk,
    required this.monthlyRevenue,
    required this.totalCustomers,
  });
}
