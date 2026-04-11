import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';

class LinkGeneratedScreen extends StatelessWidget {
  final String link;

  const LinkGeneratedScreen({super.key, required this.link});

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Link copied'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.primary.withValues(alpha: 0.92),
        ),
      );
    }
  }

  Future<void> _shareText(String subject) async {
    await Share.share(link, subject: subject);
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A0F2E),
              Color(0xFF121212),
              Color(0xFF0D1528),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: AppTheme.primary, size: 28),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'NOKKON',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(Icons.check_rounded,
                      size: 48, color: Colors.white.withValues(alpha: 0.95)),
                ),
                const SizedBox(height: 24),
                Text(
                  'Link generated!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Send this link by any app. Whoever opens it first can set the '
                  '4-digit PIN once—after that, the link stops working. Prefer someone you trust.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    height: 1.45,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.link_rounded,
                              color: AppTheme.primary.withValues(alpha: 0.9)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SelectableText(
                              link,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _copy(context),
                            icon: const Icon(Icons.copy_rounded,
                                size: 18, color: AppTheme.primary),
                            label: const Text(
                              'Copy',
                              style: TextStyle(color: AppTheme.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Expires in 24 hours',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Single-use: one PIN setup per link. Do not open it yourself on this phone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ShareOrb(
                      color: const Color(0xFF25D366),
                      icon: Icons.chat_rounded,
                      label: 'WhatsApp',
                      onTap: () => _openExternal(
                          'https://wa.me/?text=${Uri.encodeComponent('Set my NOKKON PIN: $link')}'),
                    ),
                    _ShareOrb(
                      color: const Color(0xFF229ED9),
                      icon: Icons.send_rounded,
                      label: 'Telegram',
                      onTap: () => _shareText('NOKKON PIN setup'),
                    ),
                    _ShareOrb(
                      color: const Color(0xFFEA4335),
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      onTap: () => _shareText('NOKKON PIN setup'),
                    ),
                    _ShareOrb(
                      color: AppTheme.primary,
                      icon: Icons.ios_share_rounded,
                      label: 'More',
                      onTap: () => _shareText('NOKKON PIN setup'),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.7),
                    ),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareOrb extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareOrb({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
