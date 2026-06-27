import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db/db_helper.dart';
import 'screens/customer_registration_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/milk_entry_screen.dart';
import 'screens/edit_delete_entries_screen.dart';
import 'screens/edit_rate_screen.dart';
import 'screens/daily_summary_screen.dart';
import 'screens/customer_summary_pdf_screen.dart';
import 'screens/export_total_pdf_screen.dart';
import 'screens/export_customer_pdf_screen.dart';
import 'screens/total_summary_pdf_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/products_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/how_to_use_screen.dart';
import 'screens/about_us_screen.dart';
import 'l10n/app_localizations.dart';
import 'constants.dart';
import 'screens/khata_book_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error handler
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // ignore: avoid_print
    print('Caught Flutter Error: ${details.exception}');
    // ignore: avoid_print
    print('Stack trace: ${details.stack}');
  };

  bool firebaseInitialized = false;
  String? initError;

  // Initialize Firebase and other constants with error handling
  try {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        firebaseInitialized = true;
        // ignore: avoid_print
        print('Firebase initialized successfully');
      } else {
        // ignore: avoid_print
        print('Firebase already initialized, skipping re-initialization');
        firebaseInitialized = true;
      }
    } catch (e) {
      if (e.toString().contains('duplicate-app')) {
        // ignore: avoid_print
        print('Firebase already initialized (caught duplicate-app error)');
        firebaseInitialized = true;
      } else {
        initError = 'Error initializing Firebase: $e';
        // ignore: avoid_print
        print(initError);
      }
    }
  } catch (e) {
    initError = 'Error initializing Firebase: $e';
    // ignore: avoid_print
    print(initError);
  }

  try {
    if (!kIsWeb) {
      await Constants.loadRates();
    }
    await Constants.loadDairyDetails();
    // ignore: avoid_print
    print('Constants loaded successfully');
  } catch (e) {
    final err = 'Error during initialization: $e';
    // ignore: avoid_print
    print(err);
    if (initError == null) {
      initError = err;
    } else {
      initError += '\n$err';
    }
  }

  runApp(
    MyAppWrapper(
      firebaseInitialized: firebaseInitialized,
      initError: initError,
    ),
  );
}

class MyAppWrapper extends StatelessWidget {
  final bool firebaseInitialized;
  final String? initError;

  const MyAppWrapper({
    super.key,
    required this.firebaseInitialized,
    this.initError,
  });

  @override
  Widget build(BuildContext context) {
    if (!firebaseInitialized) {
      return MaterialApp(
        title: 'AAPNI DAIRY - Initialization Failed',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: InitializationErrorScreen(
          errorMessage: initError ?? 'Unknown error during initialization.',
        ),
      );
    }
    return const MyApp();
  }
}

class InitializationErrorScreen extends StatelessWidget {
  final String errorMessage;

  const InitializationErrorScreen({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Initialization Error')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to initialize the app:',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                errorMessage,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  // Flutter main restart API nahi hoti.
                },
                child: const Text('Close App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitialized = false;
  bool _isLoggedIn = false;

  String _dairyName = Constants.dairyName;
  String _ownerName = Constants.ownerName;
  String _mobileNumber = Constants.mobileNumber;

  Locale _locale = const Locale('en', '');

  @override
  void initState() {
    super.initState();
    _loadLocale();
    _initializeApp();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('languageCode') ?? 'en';
    if (!mounted) return;
    setState(() {
      _locale = Locale(languageCode, '');
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Force-login logic after reinstall:
      // If user has not completed the initial login, show LoginScreen even if
      // previous dairy details exist.
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedInitialLogin =
          prefs.getBool('hasCompletedInitialLogin') ?? false;

      await _loadDairyDetails();

      final normalizedMobile = _mobileNumber.trim();
      final hasDetails =
          _dairyName.trim().length >= 2 &&
          _ownerName.trim().length >= 2 &&
          normalizedMobile.length == 10 &&
          RegExp(r'^[0-9]{10}$').hasMatch(normalizedMobile);

      if (!mounted) return;
      setState(() {
        _isLoggedIn = hasDetails && hasCompletedInitialLogin;
        _isInitialized = true;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error during app initialization: $e');
      if (!mounted) return;
      setState(() {
        _isLoggedIn = false;
        _isInitialized = true;
      });
    }
  }

  Future<void> _loadDairyDetails() async {
    try {
      final dairyDetails = await DatabaseHelper().getDairyDetails();

      if (!mounted) return;
      setState(() {
        _dairyName = (dairyDetails['dairyName'] ?? Constants.dairyName)
            .toString();
        _ownerName = (dairyDetails['ownerName'] ?? Constants.ownerName)
            .toString();
        _mobileNumber = (dairyDetails['mobileNumber'] ?? Constants.mobileNumber)
            .toString();
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dairyName', _dairyName);
      await prefs.setString('ownerName', _ownerName);
      await prefs.setString('mobileNumber', _mobileNumber);

      Constants.dairyName = _dairyName;
      Constants.ownerName = _ownerName;
      Constants.mobileNumber = _mobileNumber;
    } catch (e) {
      // ignore: avoid_print
      print('Error loading dairy details: $e');

      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _dairyName = (prefs.getString('dairyName') ?? Constants.dairyName)
            .toString();
        _ownerName = (prefs.getString('ownerName') ?? Constants.ownerName)
            .toString();
        _mobileNumber =
            (prefs.getString('mobileNumber') ?? Constants.mobileNumber)
                .toString();
      });

      Constants.dairyName = _dairyName;
      Constants.ownerName = _ownerName;
      Constants.mobileNumber = _mobileNumber;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        title: 'AAPNI DAIRY',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Initializing AAPNI DAIRY...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'AAPNI DAIRY',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      locale: _locale,
      localizationsDelegates: [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('hi', ''),
        Locale('pa', ''),
      ],
      home: _isLoggedIn
          ? HomeScreen(
              dairyName: _dairyName,
              ownerName: _ownerName,
              mobileNumber: _mobileNumber,
            )
          : const LoginScreen(),
      routes: {
        '/customer_registration': (context) =>
            const CustomerRegistrationScreen(),
        '/milk_entry': (context) => const MilkEntryScreen(),
        '/edit_delete_entries': (context) => const EditDeleteEntriesScreen(),
        '/edit_rate': (context) => const EditRateScreen(),
        '/daily_summary': (context) => const DailySummaryScreen(),
        '/customer_summary_pdf': (context) => const CustomerSummaryPdfScreen(),
        '/export_total_pdf': (context) => ExportTotalPdfScreen(),
        '/export_customer_pdf': (context) => ExportCustomerPdfScreen(),
        '/total_summary_pdf': (context) => TotalSummaryPdfScreen(),
        '/products': (context) => const ProductsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/how_to_use': (context) => const HowToUseScreen(),
        '/about_us': (context) => const AboutUsScreen(),
        '/khata_ledger': (context) => const KhataBookScreen(),
      },
    );
  }
}
