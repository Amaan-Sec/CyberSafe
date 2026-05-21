import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the current UI/TTS language. Persists across launches.
class LocaleService extends ChangeNotifier {
  static const _kKey = 'mcs_locale';

  /// Supported locales. Order matches the picker.
  static const supported = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('mr'),
  ];

  Locale _current = const Locale('en');
  Locale get current => _current;

  /// Sarvam TTS expects BCP-47 codes with India region.
  String get sarvamCode {
    switch (_current.languageCode) {
      case 'hi':
        return 'hi-IN';
      case 'mr':
        return 'mr-IN';
      default:
        return 'en-IN';
    }
  }

  String get displayName {
    switch (_current.languageCode) {
      case 'hi':
        return 'हिन्दी';
      case 'mr':
        return 'मराठी';
      default:
        return 'English';
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kKey);
    if (code != null && supported.any((l) => l.languageCode == code)) {
      _current = Locale(code);
      notifyListeners();
    }
  }

  Future<void> set(Locale locale) async {
    if (locale == _current) return;
    _current = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, locale.languageCode);
  }
}
