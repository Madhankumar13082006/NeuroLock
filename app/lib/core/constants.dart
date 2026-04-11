class AppConstants {
  /// Your PC's LAN IP + Node port (same URL for API + invite links in local dev).
  /// Example: `http://192.168.1.50:3000` — phone must be on same Wi-Fi.
  /// Android emulator → host: `http://10.0.2.2:3000`
  static const String baseUrl = 'http://10.1.182.117:3000';

  /// Safe for `Uri.parse` (strips accidental spaces).
  static String get baseUrlNormalized =>
      baseUrl.replaceAll(RegExp(r'\s+'), '').trim();

  /// Invite links use the same host as [baseUrl]: `http:// 10.1.182.117:3000/invite/<token>`
  static String get inviteLinkBase => baseUrlNormalized;

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';

  static const List<Map<String, String>> defaultBlockedApps = [
    {'packageName': 'com.instagram.android', 'appName': 'Instagram'},
    {'packageName': 'com.google.android.youtube', 'appName': 'YouTube'},
    {'packageName': 'com.zhiliaoapp.musically', 'appName': 'TikTok'},
    {'packageName': 'com.twitter.android', 'appName': 'Twitter/X'},
  ];
}
