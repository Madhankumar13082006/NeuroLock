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

/// YouTube, Instagram, Snapchat — four levers each (shorts, reels, stories, feed).
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
        key: 'videos',
        label: 'Block Full Videos',
        icon: Icons.ondemand_video_rounded,
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
        key: 'stories',
        label: 'Block Stories',
        icon: Icons.circle_outlined,
      ),
      FeatureBlock(
        key: 'messages',
        label: 'Block Messages',
        icon: Icons.forum_rounded,
      ),
    ],
  ),
  SupportedApp(
    packageName: 'com.snapchat.android',
    displayName: 'Snapchat',
    brandColor: Color(0xFFFFFC00),
    features: [
      FeatureBlock(
        key: 'snaps',
        label: 'Block Spotlight',
        icon: Icons.play_circle_outline_rounded,
      ),
      FeatureBlock(
        key: 'stories',
        label: 'Block Stories',
        icon: Icons.bubble_chart_outlined,
      ),
    ],
  ),
];
