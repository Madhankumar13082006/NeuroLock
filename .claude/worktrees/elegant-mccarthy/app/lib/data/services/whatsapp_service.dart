import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static Future<void> sendApprovalRequest({
    required String phone, // international format e.g. +919876543210
    required String userName,
    required String appName,
    required String approvalLink,
  }) async {
    final message = Uri.encodeComponent(
      '🔔 *Nokkon — Unlock Request*\n\n'
      '*$userName* is requesting to open *$appName*.\n\n'
      'Tap the link below to approve or deny:\n'
      '$approvalLink\n\n'
      '_Link expires in 30 minutes._',
    );

    final waUrl = Uri.parse('https://wa.me/$phone?text=$message');

    if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: open WhatsApp without pre-filled number
      final fallback = Uri.parse('whatsapp://send?text=$message');
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> openApprovalLink(String link) async {
    final uri = Uri.parse(link);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
