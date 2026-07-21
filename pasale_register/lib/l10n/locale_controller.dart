import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';
import 'app_strings.dart';

export 'app_language.dart';
export 'app_strings.dart';

const _prefsKey = 'appLanguageCode';

/// Global app language. English is default until the user picks another.
class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  AppLanguage _language = AppLanguage.english;
  bool _loaded = false;

  AppLanguage get language => _language;
  bool get isLoaded => _loaded;
  AppStrings get strings => AppStrings(_language);
  bool get isRtl => _language.isRtl;
  Locale get locale => _language.locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    _language = AppLanguageX.fromCode(code);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, language.code);
    notifyListeners();
  }
}
