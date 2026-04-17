import 'package:flutter/material.dart';
import '../../core/theme.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _SectionTitle('1. About NeuroLock'),
              _BodyText(
                'NeuroLock helps users reduce distraction by controlling access '
                'to selected app features and requiring trusted verification '
                'for temporary unlocks.',
              ),
              _SectionTitle('2. Service Scope'),
              _BodyText(
                'NeuroLock is a digital wellbeing utility. It does not provide '
                'medical treatment, emergency services, legal advice, or any '
                'guarantee of behavioral outcomes.',
              ),
              _SectionTitle('3. Account Registration and Access'),
              _BodyText(
                'You must provide accurate account details and maintain control '
                'of your login credentials. Email registration requires inbox '
                'verification before sign-in is enabled.',
              ),
              _SectionTitle('4. Screen and Usage Data'),
              _BodyText(
                'To deliver blocking and unlock workflows, NeuroLock may process '
                'limited app screen-view and app usage context on your device. '
                'This data is used to enforce your settings and improve app '
                'reliability.',
              ),
              _SectionTitle('5. Trusted Contact and PIN Flows'),
              _BodyText(
                'When you generate approval links, your trusted contact can set '
                'a PIN that affects your unlock process. You are responsible for '
                'choosing trusted contacts and sharing links securely.',
              ),
              _SectionTitle('6. User Responsibilities'),
              _BodyText(
                'You agree not to misuse the service, bypass platform security, '
                'or attempt unauthorized access to other accounts or systems.',
              ),
              _SectionTitle('7. Availability and Changes'),
              _BodyText(
                'Features may be updated, suspended, or removed to improve '
                'security, compliance, and product quality. We may modify these '
                'terms as the service evolves.',
              ),
              _SectionTitle('8. Limitation of Liability'),
              _BodyText(
                'To the maximum extent allowed by law, NeuroLock is provided '
                'on an "as is" and "as available" basis without warranties of '
                'uninterrupted service or fitness for a specific purpose.',
              ),
              _SectionTitle('9. Contact'),
              _BodyText(
                'For support or legal requests, contact the app support channel '
                'provided by your NeuroLock deployment team.',
              ),
              SizedBox(height: 18),
              _BodyText(
                'By creating an account, you confirm that you have read and '
                'accepted these Terms & Conditions.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppTheme.textSecondary.withValues(alpha: 0.95),
        fontSize: 14,
        height: 1.5,
      ),
    );
  }
}
