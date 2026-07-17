import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/support_actions.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _versionLabel = 'Version unavailable';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _versionLabel = 'v${info.version} (build ${info.buildNumber})';
    });
  }

  Future<void> _openOpenFoodFacts() async {
    final uri = Uri.parse('https://world.openfoodfacts.org/');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open OpenFoodFacts website right now.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        title: const Text(
          'ABOUT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text(
            'BareMacros',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _versionLabel,
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 18),
          _sectionCard(
            title: 'Why BareMacros Exists',
            body:
                'I got tired of macro apps packed with features I never use, cluttered flows, and aggressive data collection. BareMacros is my alternative: fast logging, clear macro tracking, and privacy-first behavior so you can focus on consistency instead of fighting the app.',
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Data Source & Credits',
            body:
                'Food search includes OpenFoodFacts data. Food databases can contain gaps or inaccuracies. Always verify packaging labels for critical decisions.',
            actions: [
              TextButton(
                onPressed: _openOpenFoodFacts,
                child: const Text('Open OpenFoodFacts'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Important Notice',
            body:
                'BareMacros is for general tracking only and is not medical, nutrition, or professional health advice. Do not rely on this app as your sole source for health metrics.',
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Data & Privacy',
            body:
                'Your logs are stored on your device. I built BareMacros to avoid unnecessary data harvesting and keep tracking simple and local. If the app is uninstalled or device data is cleared, records may be lost.',
            actions: [
              TextButton(
                onPressed: () => SupportActions.openPrivacyPolicy(context),
                child: const Text('Privacy Policy'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Support',
            body: 'Questions or feedback are always welcome. I read every message.',
            actions: [
              TextButton(
                onPressed: () => SupportActions.launchSupportEmail(
                  context,
                  'BareMacros - Support',
                ),
                child: const Text('Contact Support'),
              ),
              TextButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'BareMacros',
                ),
                child: const Text('Open Source Licenses'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String body,
    List<Widget> actions = const [],
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}
