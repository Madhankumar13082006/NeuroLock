import 'package:flutter/material.dart';

class AppInfo {
  final String packageName;
  final String displayName;
  final String emoji;
  final Color color;
  final List<AppFeature> features;

  const AppInfo({
    required this.packageName,
    required this.displayName,
    required this.emoji,
    required this.color,
    required this.features,
  });
}

class AppFeature {
  final String key;
  final String label;
  final String description;

  const AppFeature({
    required this.key,
    required this.label,
    required this.description,
  });
}

const List<AppInfo> kSupportedApps = [
  AppInfo(
    packageName: 'com.google.android.youtube',
    displayName: 'YouTube',
    emoji: '▶',
    color: Color(0xFFFF0000),
    features: [
      AppFeature(
          key: 'block_shorts',
          label: 'Block Shorts',
          description: 'Block YouTube Shorts feed'),
      AppFeature(
          key: 'block_search',
          label: 'Block Search',
          description: 'Block video search'),
      AppFeature(
          key: 'block_comments',
          label: 'Block Comments',
          description: 'Block comment sections'),
      AppFeature(
          key: 'block_all',
          label: 'Block Entire App',
          description: 'Block YouTube completely'),
    ],
  ),
  AppInfo(
    packageName: 'com.instagram.android',
    displayName: 'Instagram',
    emoji: '📷',
    color: Color(0xFFE1306C),
    features: [
      AppFeature(
          key: 'block_reels',
          label: 'Block Reels',
          description: 'Block Instagram Reels'),
      AppFeature(
          key: 'block_explore',
          label: 'Block Explore',
          description: 'Block Explore page'),
      AppFeature(
          key: 'block_stories',
          label: 'Block Stories',
          description: 'Block Stories'),
      AppFeature(
          key: 'block_all',
          label: 'Block Entire App',
          description: 'Block Instagram completely'),
    ],
  ),
  AppInfo(
    packageName: 'com.zhiliaoapp.musically',
    displayName: 'TikTok',
    emoji: '🎵',
    color: Color(0xFF010101),
    features: [
      AppFeature(
          key: 'block_all',
          label: 'Block Entire App',
          description: 'Block TikTok completely'),
      AppFeature(
          key: 'block_fyp',
          label: 'Block For You Page',
          description: 'Block FYP feed'),
    ],
  ),
  AppInfo(
    packageName: 'com.twitter.android',
    displayName: 'Twitter / X',
    emoji: '𝕏',
    color: Color(0xFF1DA1F2),
    features: [
      AppFeature(
          key: 'block_all',
          label: 'Block Entire App',
          description: 'Block Twitter completely'),
      AppFeature(
          key: 'block_trending',
          label: 'Block Trending',
          description: 'Block Trending tab'),
    ],
  ),
  AppInfo(
    packageName: 'com.reddit.frontpage',
    displayName: 'Reddit',
    emoji: '🤖',
    color: Color(0xFFFF4500),
    features: [
      AppFeature(
          key: 'block_all',
          label: 'Block Entire App',
          description: 'Block Reddit completely'),
      AppFeature(
          key: 'block_popular',
          label: 'Block Popular Feed',
          description: 'Block Popular tab'),
    ],
  ),
  AppInfo(
    packageName: 'com.facebook.katana',
    displayName: 'Facebook',
    emoji: '👤',
    color: Color(0xFF1877F2),
    features: [
      AppFeature(
          key: 'block_all',
          label: 'Block Entire App',
          description: 'Block Facebook completely'),
      AppFeature(
          key: 'block_reels',
          label: 'Block Reels',
          description: 'Block Facebook Reels'),
    ],
  ),
];
