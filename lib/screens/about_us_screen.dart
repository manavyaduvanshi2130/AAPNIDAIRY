import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '•',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.65,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // ignore: avoid_print
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.aboutUs),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 28,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade100,
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.favorite, color: Colors.white, size: 22),
                      const SizedBox(height: 8),
                      Text(
                        'Aapni Dairy',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '(Logo: 2130 FARM - SINCE 2008)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🤝 About Us: Aapni Dairy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        localizations.aboutUsContent1,
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.65,
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        localizations.aboutUsContent2,
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.65,
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Follow Our Journey first (as requested)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.followUs,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _socialIconButton(
                            icon: Icons.camera_alt,
                            label: localizations.instagram,
                            color: Colors.pink.shade600,
                            onTap: () => _openUrl(
                              'https://www.instagram.com/aapni.dairy/',
                            ),
                          ),
                          _socialIconButton(
                            icon: Icons.facebook,
                            label: localizations.facebook,
                            color: Colors.blue.shade700,
                            onTap: () => _openUrl(
                              'https://www.facebook.com/profile.php?id=61583743204391',
                            ),
                          ),
                          _socialIconButton(
                            icon: Icons.chat_bubble_outline,
                            label: localizations.whatsapp,
                            color: Colors.green.shade700,
                            onTap: () => _openUrl(
                              'https://whatsapp.com/channel/0029VbB4m2b5PO0uSvtgbJ43',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '📞 Contact Us',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'For any issues related to the application, please WhatsApp on the given number. Our team will make every effort to resolve your issue within 24 hours.',
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.55,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '📞 +91 63675 80153',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // About Us full content (from your provided text)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🤝 About Us: Aapni Dairy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        localizations.aboutUsContent1,
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.65,
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        localizations.aboutUsContent2,
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.65,
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.justify,
                      ),

                      const SizedBox(height: 16),

                      Text(
                        localizations.expertiseTitle,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations.expertiseContent,
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.65,
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                      const SizedBox(height: 10),
                      _bullet(localizations.bullet1),
                      _bullet(localizations.bullet2),
                      _bullet(localizations.bullet3),

                      const SizedBox(height: 14),

                      Text(
                        localizations.nameExplanation,
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.65,
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.justify,
                      ),

                      const SizedBox(height: 14),

                      Text(
                        '✅ ${localizations.goal}',
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.65,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.justify,
                      ),

                      const SizedBox(height: 16),

                      Text(
                        localizations.teamTitle,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations.teamContent,
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.65,
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
