import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Returns a map with: platform, deviceModel, osVersion, deviceBrand
  static Future<Map<String, String>> getDeviceDetails() async {
    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        final browser = webInfo.browserName.name; // chrome, firefox, safari, etc.
        final ua = webInfo.userAgent ?? '';
        String os = 'Web';
        if (ua.contains('Windows')) os = 'Windows';
        else if (ua.contains('Mac OS')) os = 'macOS';
        else if (ua.contains('Linux')) os = 'Linux';
        else if (ua.contains('Android')) os = 'Android (Web)';
        else if (ua.contains('iPhone') || ua.contains('iPad')) os = 'iOS (Web)';
        
        return {
          'platform': 'web',
          'deviceModel': '$os — ${_browserLabel(browser)}',
          'osVersion': os,
          'deviceBrand': _browserLabel(browser),
        };
      }

      // Try Android
      try {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'platform': 'android',
          'deviceModel': '${androidInfo.brand} ${androidInfo.model}',
          'osVersion': 'Android ${androidInfo.version.release}',
          'deviceBrand': androidInfo.brand,
          'deviceId': androidInfo.id,
        };
      } catch (_) {}

      // Try iOS
      try {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'platform': 'ios',
          'deviceModel': '${iosInfo.name} (${iosInfo.model})',
          'osVersion': '${iosInfo.systemName} ${iosInfo.systemVersion}',
          'deviceBrand': 'Apple',
          'deviceId': iosInfo.identifierForVendor ?? '',
        };
      } catch (_) {}

      return {
        'platform': 'unknown',
        'deviceModel': 'جهاز غير معروف',
        'osVersion': '',
        'deviceBrand': '',
      };
    } catch (e) {
      return {
        'platform': 'unknown',
        'deviceModel': 'جهاز غير معروف',
        'osVersion': '',
        'deviceBrand': '',
      };
    }
  }

  static String _browserLabel(String browser) {
    switch (browser.toLowerCase()) {
      case 'chrome': return 'Chrome';
      case 'firefox': return 'Firefox';
      case 'safari': return 'Safari';
      case 'edge': return 'Edge';
      case 'opera': return 'Opera';
      default: return 'متصفح';
    }
  }
}
