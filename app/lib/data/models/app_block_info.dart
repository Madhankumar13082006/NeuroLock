import 'package:flutter/material.dart';

class FeatureBlock {
  final String key;
  final String label;
  final IconData icon;

  const FeatureBlock({
    required this.key,
    required this.label,
    required this.icon,
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
          icon: Icons.video_library_rounded),
      FeatureBlock(
          key: 'search',
          label: 'Block Video Search',
          icon: Icons.search_rounded),
      FeatureBlock(
          key: 'pip',
          label: 'Block Picture-in-Picture',
          icon: Icons.picture_in_picture_rounded),
      FeatureBlock(
          key: 'comments',
          label: 'Block Comments',
          icon: Icons.comment_rounded),
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
          icon: Icons.video_library_rounded),
      FeatureBlock(
          key: 'stories', label: 'Block Stories', icon: Icons.circle_outlined),
      FeatureBlock(
          key: 'explore',
          label: 'Block Explore Tab',
          icon: Icons.explore_rounded),
    ],
  ),
];
