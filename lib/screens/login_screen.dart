import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/db_helper.dart';
import '../constants.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dairyNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _mobileController = TextEditingController();

  bool _acceptedDisclaimer = false;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Login screen pe fields blank rakhne ke liye prefilled data load nahi kiya ja raha.
  }

  // NOTE: Intentionally removed login prefill to force user input.
  // Previously this screen loaded saved values from SharedPreferences.

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedDisclaimer) {
      setState(() {
        _errorMessage = 'Please accept the disclaimer to continue.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dairyName = _dairyNameController.text.trim();
      final ownerName = _ownerNameController.text.trim();
      final mobileNumber = _mobileController.text.trim();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dairyName', dairyName);
      await prefs.setString('ownerName', ownerName);
      await prefs.setString('mobileNumber', mobileNumber);

      await DatabaseHelper().saveDairyDetails(
        dairyName: dairyName,
        ownerName: ownerName,
        mobileNumber: mobileNumber,
      );

      Constants.dairyName = dairyName;
      Constants.ownerName = ownerName;
      Constants.mobileNumber = mobileNumber;

      // Mark initial login completed so next app start can go directly to Home
      await prefs.setBool('hasCompletedInitialLogin', true);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            dairyName: dairyName,
            ownerName: ownerName,
            mobileNumber: mobileNumber,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      height: 100,
                      width: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Welcome to 2130 GROUP',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter Dairy Details to Continue',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  TextFormField(
                    controller: _dairyNameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Dairy Name',
                      hintText: 'e.g. HRB Dairy Kheda',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Please enter dairy name';
                      if (v.length < 2) return 'Dairy name too short';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _ownerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Owner Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter owner name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _mobileController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      hintText: '10 digit mobile number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_android_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [],
                    validator: (value) {
                      final v = (value ?? '').trim();
                      if (v.isEmpty) return 'Please enter mobile number';
                      if (!RegExp(r'^[0-9]{10}$').hasMatch(v)) {
                        return 'Enter valid 10-digit mobile number';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _continue(),
                  ),

                  const SizedBox(height: 24),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade800),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_errorMessage != null) const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _continue,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),

                  const SizedBox(height: 12),
                  // Disclaimer checkbox ABOVE login button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _acceptedDisclaimer,
                        onChanged: (v) {
                          setState(() {
                            _acceptedDisclaimer = v ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          'If app get uninstalled, complete data will be lost. The company will not be responsible for this. Please backup data regularly.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dairyNameController.dispose();
    _ownerNameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }
}
