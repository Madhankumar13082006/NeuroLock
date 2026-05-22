import 'package:flutter/material.dart';

class FeatureBlock {
  final String key;
  final String label;
  final IconData icon;
  final bool earlyAccess;

  const FeatureBlock({
    required this.key,
    required this.label,
    required this.icon,
    this.earlyAccess = false,
  });
}

class SupportedApp {
  final String packageName;
  final String displayName;
  final Color brandColor;
  final List<FeatureBlock> features;

  const SupportedApp({
    required this.packageName,
    required this.displayName,
    required this.brandColor,
    required this.features,
  });
}

const List<SupportedApp> kSupportedApps = [
  SupportedApp(
    packageName: 'com.google.android.youtube',
    displayName: 'YouTube',
    brandColor: Color(0xFFFF0000),
    features: [
      FeatureBlock(
        key: 'shorts',
        label: 'Block Shorts',
        icon: Icons.video_library_rounded,
      ),
      FeatureBlock(
        key: 'web_shorts',
        label: 'Block Shorts in browsers (optional)',
        icon: Icons.language_rounded,
        earlyAccess: true,
      ),
    ],
  ),
  SupportedApp(
    packageName: 'com.instagram.android',
    displayName: 'Instagram',
    brandColor: Color(0xFFE1306C),
    features: [
      FeatureBlock(
        key: 'reels',
        label: 'Block Reels',
        icon: Icons.view_week_rounded,
        earlyAccess: true,
      ),
      FeatureBlock(
        key: 'web_reels',
        label: 'Block Instagram in browsers (optional)',
        icon: Icons.language_rounded,
        earlyAccess: true,
      ),
      FeatureBlock(
        key: 'explore',
        label: 'Block Explore Tab',
        icon: Icons.explore_rounded,
        earlyAccess: true,
      ),
    ],
  ),
  SupportedApp(
    packageName: 'com.impulsecontrol.web_guard',
    displayName: 'Web Protection',
    brandColor: Color(0xFF7C4DFF),
    features: [
      FeatureBlock(
        key: 'adult_sites',
        label: 'Block adult websites',
        icon: Icons.shield_outlined,
      ),
    ],
  ),
];
