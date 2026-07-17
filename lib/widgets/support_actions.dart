import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportActions {
  static const Color mutedColor = Color(0xFFB0B0B0);
  static const Color highlightColor = Color(0xFF2196F3);

  static ButtonStyle appBarActionButtonStyle() {
    return ButtonStyle(
      iconColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return highlightColor;
        }
        return mutedColor;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return highlightColor.withValues(alpha: 0.16);
        }
        return Colors.transparent;
      }),
      splashFactory: InkRipple.splashFactory,
    );
  }

  static List<Widget> appBarActions(BuildContext context) {
    return [
      IconButton(
        style: appBarActionButtonStyle(),
        icon: const Icon(Icons.help_outline_rounded),
        tooltip: 'Help and feedback',
        onPressed: () => showSupportFeedbackSheet(context),
      ),
      IconButton(
        style: appBarActionButtonStyle(),
        icon: const Icon(Icons.share_outlined),
        tooltip: 'Share BareMacros',
        onPressed: shareApp,
      ),
      const SizedBox(width: 4),
    ];
  }

  static Future<void> launchSupportEmail(
    BuildContext context,
    String subject,
  ) async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: 'support@baremacros.com',
      queryParameters: {'subject': subject},
    );

    final launched = await launchUrl(
      emailUri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email app is available to send this message.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  static Future<void> openPrivacyPolicy(BuildContext context) async {
    final privacyUri = Uri.parse(
      'https://revriest.github.io/dimestoremacro/privacy.html',
    );
    final launched = await launchUrl(
      privacyUri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open privacy policy right now.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  static Future<void> showSupportFeedbackSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Need Help? Have a Suggestion?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _supportTile(
                  icon: Icons.bug_report_outlined,
                  title: 'Report Bug',
                  subtitle: 'Tell me what happened and how to reproduce it.',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await launchSupportEmail(
                      context,
                      'BareMacros - Bug Report',
                    );
                  },
                ),
                const SizedBox(height: 8),
                _supportTile(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'Suggest Feature',
                  subtitle: 'Share ideas that would make BareMacros better.',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await launchSupportEmail(
                      context,
                      'BareMacros - Feature Suggestion',
                    );
                  },
                ),
                const SizedBox(height: 8),
                _supportTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Get Help',
                  subtitle: 'Questions about setup or tracking macros?',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await launchSupportEmail(
                      context,
                      'BareMacros - Help Request',
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: mutedColor,
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await openPrivacyPolicy(context);
                  },
                  child: const Text('Privacy Policy'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> shareApp() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Tracking macros with BareMacros. Clean, fast, no bloat.\n\nDownload: https://baremacros.com\n\nShare feedback at support@baremacros.com.',
        subject: 'BareMacros',
      ),
    );
  }

  static Widget _supportTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 2,
          ),
          leading: Icon(icon, color: mutedColor),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white30,
          ),
        ),
      ),
    );
  }
}
