// services/locale_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';

class LocaleService {
  LocaleService._();
  static final LocaleService instance = LocaleService._();

  Map<String, String> _strings = {};
  String _currentLang = 'en';

  static const Map<String, String> kLanguages = {
    'English': 'en',
    'हिन्दी':  'hi',
    'తెలుగు':  'te',
    'தமிழ்':   'ta',
    'ओड़िआ':   'or',
  };

  String get currentLang => _currentLang;

  Future<void> load(String langCode) async {
    _currentLang = langCode;
    try {
      final s = await rootBundle
          .loadString('assets/translations/$langCode.json');
      final m = jsonDecode(s) as Map<String, dynamic>;
      _strings = m.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      if (langCode != 'en') await load('en');
    }
  }

  String t(String key) => _strings[key] ?? key;
}

String tr(String key) => LocaleService.instance.t(key);
