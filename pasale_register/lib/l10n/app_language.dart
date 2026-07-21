import 'package:flutter/material.dart';

/// App languages. English is the default.
enum AppLanguage {
  english,
  nepali,
  bengali,
  hindi,
  urdu,
}

extension AppLanguageX on AppLanguage {
  String get code => switch (this) {
        AppLanguage.english => 'en',
        AppLanguage.nepali => 'ne',
        AppLanguage.bengali => 'bn',
        AppLanguage.hindi => 'hi',
        AppLanguage.urdu => 'ur',
      };

  /// Name shown in the language’s own script (for the picker).
  String get nativeLabel => switch (this) {
        AppLanguage.english => 'English',
        AppLanguage.nepali => 'नेपाली',
        AppLanguage.bengali => 'বাংলা',
        AppLanguage.hindi => 'हिन्दी',
        AppLanguage.urdu => 'اردو',
      };

  /// English label for settings subtitles.
  String get englishLabel => switch (this) {
        AppLanguage.english => 'English',
        AppLanguage.nepali => 'Nepali',
        AppLanguage.bengali => 'Bengali',
        AppLanguage.hindi => 'Hindi',
        AppLanguage.urdu => 'Urdu',
      };

  Locale get locale => Locale(code);

  bool get isRtl => this == AppLanguage.urdu;

  static AppLanguage fromCode(String? code) {
    switch (code) {
      case 'ne':
        return AppLanguage.nepali;
      case 'bn':
        return AppLanguage.bengali;
      case 'hi':
        return AppLanguage.hindi;
      case 'ur':
        return AppLanguage.urdu;
      case 'en':
      default:
        return AppLanguage.english;
    }
  }

  static AppLanguage fromLocale(Locale locale) => fromCode(locale.languageCode);
}
