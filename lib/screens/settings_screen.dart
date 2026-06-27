import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../db/db_helper.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/drive_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onSaved;
  final Function(Locale)? onLocaleChanged;

  const SettingsScreen({super.key, this.onSaved, this.onLocaleChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dairyNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  // Drive Service Instance
  final DriveService _driveService = DriveService();

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  // --- BACKUP LOGIC ---
  void _backupToDrive() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final data = await DatabaseHelper().getAllDataForBackup();
      bool success = await _driveService.uploadBackup(data);

      Navigator.pop(context); // Close dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? "Backup Success!" : "Backup Failed!")),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- RESTORE LOGIC ---
  void _restoreFromDrive() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final data = await _driveService.downloadBackup();
      Navigator.pop(context); // Close dialog

      if (data != null) {
        await DatabaseHelper().restoreFromBackup(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Restore Success! Please restart the app."),
          ),
        );
        _loadExistingData(); // Refresh UI fields
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No Backup Found on Google Drive!")),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Restore Error: $e")));
    }
  }

  Future<void> _loadExistingData() async {
    final dairyDetails = await DatabaseHelper().getDairyDetails();
    setState(() {
      _dairyNameController.text = dairyDetails['dairyName'] ?? '';
      _ownerNameController.text = dairyDetails['ownerName'] ?? '';
      _mobileController.text = dairyDetails['mobileNumber'] ?? '';
    });
  }

  Future<void> _saveData() async {
    if (_formKey.currentState!.validate()) {
      await DatabaseHelper().saveDairyDetails(
        dairyName: _dairyNameController.text,
        ownerName: _ownerNameController.text,
        mobileNumber: _mobileController.text,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
      widget.onSaved?.call();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.settings),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // --- Cloud Backup Section ---
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text(
                        "Google Drive Backup",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text("Keep your data safe in the cloud"),
                      leading: Icon(
                        Icons.cloud_done,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text("Backup Now"),
                      leading: const Icon(
                        Icons.cloud_upload,
                        color: Colors.green,
                      ),
                      onTap: _backupToDrive,
                    ),
                    ListTile(
                      title: const Text("Restore Data"),
                      leading: const Icon(
                        Icons.cloud_download,
                        color: Colors.orange,
                      ),
                      onTap: _restoreFromDrive,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- Language Card ---
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Language',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => widget.onLocaleChanged?.call(
                                const Locale('en'),
                              ),
                              child: const Text('English'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => widget.onLocaleChanged?.call(
                                const Locale('hi'),
                              ),
                              child: const Text('हिंदी'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- Dairy Details Form ---
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _dairyNameController,
                      decoration: InputDecoration(
                        labelText: localizations.dairyName,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizations.enterDairyName;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ownerNameController,
                      decoration: InputDecoration(
                        labelText: localizations.ownerName,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizations.enterOwnerName;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mobileController,
                      decoration: InputDecoration(
                        labelText: localizations.mobileNumber,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizations.enterMobileNumber;
                        }
                        if (value.length != 10) {
                          return localizations.enterValidMobile;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _saveData,
                      child: Text(localizations.saveSettings),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
