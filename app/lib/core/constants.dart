class AppConstants {
  static const String baseUrl =
      'http://10.38.140.209:3000'; // real device → use PC IP

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';

  static const List<Map<String, String>> defaultBlockedApps = [
    {'packageName': 'com.instagram.android', 'appName': 'Instagram'},
    {'packageName': 'com.google.android.youtube', 'appName': 'YouTube'},
    {'packageName': 'com.zhiliaoapp.musically', 'appName': 'TikTok'},
    {'packageName': 'com.twitter.android', 'appName': 'Twitter/X'},
  ];
}
