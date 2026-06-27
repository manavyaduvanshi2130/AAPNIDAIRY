import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import '../db/db_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String? phone; // optional, for display

  const OtpScreen({Key? key, required this.verificationId, this.phone})
    : super(key: key);

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final smsCode = _otpController.text.trim();
    if (smsCode.isEmpty) {
      setState(() => _errorMessage = 'Please enter OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: smsCode,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      // OPTIONAL: Run any migration / sync you need here.
      // If you want to migrate local data to Firestore after phone sign-in,
      // call your DatabaseHelper and FirestoreService methods from here.
      try {
        // Example: mark data migrated or sync local DB (if needed)
        // Sync removed for offline mode
      } catch (e) {
        // ignore sync errors — user is still logged in
        print('Sync after OTP sign-in failed: $e');
      }

      // You may want to load dairy details from local DB or SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final dairyName = prefs.getString('dairyName') ?? Constants.dairyName;
      final ownerName = prefs.getString('ownerName') ?? Constants.ownerName;
      final mobileNumber =
          prefs.getString('mobileNumber') ??
          widget.phone ??
          Constants.mobileNumber;

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            dairyName: dairyName,
            ownerName: ownerName,
            mobileNumber: mobileNumber,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Failed to verify OTP';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    // Resending requires calling verifyPhoneNumber again from your login screen
    // If you want resend here, you can call FirebaseAuth.verifyPhoneNumber again,
    // but it's cleaner to navigate back and call _sendOtp() there.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Go back and request a new OTP to resend')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verify ${widget.phone ?? "Phone"}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (widget.phone != null) ...[
              Text('OTP sent to ${widget.phone}'),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Enter OTP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _resendCode,
              child: const Text('Resend code'),
            ),
          ],
        ),
      ),
    );
  }
}
