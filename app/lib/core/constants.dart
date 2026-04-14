class AppConstants {
  /// Hosted backend URL (same URL for API + invite links).
  static const String baseUrl = 'https://neurolock.onrender.com/';

  /// Safe for `Uri.parse` (strips accidental spaces).
  static String get baseUrlNormalized => baseUrl
      .replaceAll(RegExp(r'\s+'), '')
      .trim()
      .replaceFirst(RegExp(r'/+$'), '');

  /// Invite links use the same host as [baseUrl]: `<base>/invite/<token>`
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
