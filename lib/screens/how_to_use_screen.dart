import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.howToUse),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Center(
                child: Text(
                  localizations.howToUse,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // Introduction
              _buildSection(
                title: 'Getting Started',
                content:
                    'Welcome to AAPNI DAIRY! This guide will help you understand how to use the app effectively for managing your dairy operations.',
              ),

              // Features
              _buildSection(
                title: 'Key Features',
                content: '',
                children: [
                  _buildStep(
                    'Customer Registration',
                    'Register new customers with their details.',
                  ),
                  _buildStep(
                    'Milk Entry',
                    'Record daily milk collections from customers.',
                  ),
                  _buildStep(
                    'Edit/Delete Entries',
                    'Modify or remove existing milk entries.',
                  ),
                  _buildStep('Edit Rate', 'Update milk rates and pricing.'),
                  _buildStep(
                    'Daily Summary',
                    'View daily milk collection summaries.',
                  ),
                  _buildStep(
                    'PDF Exports',
                    'Generate and export various PDF reports.',
                  ),
                  _buildStep(
                    'Settings',
                    'Configure dairy details and preferences.',
                  ),
                ],
              ),

              // Step-by-step guide
              _buildSection(
                title: 'Step-by-Step Guide',
                content: '',
                children: [
                  _buildStep(
                    '1. Setup',
                    'First, go to Settings to enter your dairy name, owner name, and mobile number. This information will appear on all PDF exports.',
                  ),
                  _buildStep(
                    '2. Register Customers',
                    'Use Customer Registration to add new customers. Enter their name, mobile number, and other details.',
                  ),
                  _buildStep(
                    '3. Record Milk Entries',
                    'Daily, use Milk Entry to record milk quantity, FAT, SNF, and other parameters for each customer.',
                  ),
                  _buildStep(
                    '4. Manage Entries',
                    'Use Edit/Delete Entries to modify or remove incorrect entries.',
                  ),
                  _buildStep(
                    '5. Adjust Rates',
                    'Update milk rates in Edit Rate if needed.',
                  ),
                  _buildStep(
                    '6. View Summaries',
                    'Check Daily Summary for daily collections and totals.',
                  ),
                  _buildStep(
                    '7. Export Reports',
                    'Generate PDF reports using Customer Summary PDF, Export Total PDF, Total Summary PDF, or Export Customer PDF.',
                  ),
                ],
              ),

              // Tips
              _buildSection(
                title: 'Tips',
                content: '',
                children: [
                  _buildTip(
                    'Always verify customer details before registration.',
                  ),
                  _buildTip('Double-check milk entry data for accuracy.'),
                  _buildTip('Regularly backup your data (app works offline).'),
                  _buildTip('Use PDF exports for record-keeping and sharing.'),
                ],
              ),

              // Support
              _buildSection(
                title: 'Need Help?',
                content:
                    'If you encounter any issues or have questions, please contact our support team through our social media channels.',
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    List<Widget>? children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 12),
          if (content.isNotEmpty)
            Text(
              content,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.grey.shade800,
              ),
            ),
          if (children != null) ...children,
        ],
      ),
    );
  }

  Widget _buildStep(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '•',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb, color: Colors.orange.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
