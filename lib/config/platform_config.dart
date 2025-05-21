import 'package:flutter/foundation.dart' show kIsWeb;

class PlatformConfig {
  static bool get isWeb => kIsWeb;
  
  // Add platform-specific configurations here
  static Map<String, dynamic> get platformSpecificSettings {
    if (kIsWeb) {
      return {
        'useWebStorage': true,
        'enableWebPersistence': true,
        'webRecaptchaSiteKey': '6LfyWvcqAAAAAKo3xn7N6Tx-dCrt4V3QahfRPGVo', // Replace with your actual key
      };
    }
    return {
      'useWebStorage': false,
      'enableWebPersistence': false,
    };
  }

  // Add more platform-specific methods as needed
  static bool shouldUseWebStorage() {
    return kIsWeb && platformSpecificSettings['useWebStorage'] as bool;
  }

  static bool shouldEnableWebPersistence() {
    return kIsWeb && platformSpecificSettings['enableWebPersistence'] as bool;
  }

  static String getWebRecaptchaSiteKey() {
    return platformSpecificSettings['webRecaptchaSiteKey'] as String;
  }
} 