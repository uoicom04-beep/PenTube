import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LeaveMode { pip, audio, stop }

class Settings extends ChangeNotifier {
  Settings._();
  static final Settings I = Settings._();

  late SharedPreferences _p;
  String lang = 'system'; // system | th | en
  String theme = 'system'; // system | dark | light
  bool saver = true; // saves data, battery and RAM
  int quality = 360;
  LeaveMode leaveMode = LeaveMode.pip;
  bool autoplay = true;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    lang = _p.getString('lang') ?? 'system';
    theme = _p.getString('theme') ?? 'system';
    saver = _p.getBool('saver') ?? true;
    quality = _p.getInt('quality') ?? 360;
    leaveMode = LeaveMode.values[(_p.getInt('leave') ?? 0).clamp(0, 2).toInt()];
    autoplay = _p.getBool('autoplay') ?? true;
  }

  void update(void Function() change) {
    change();
    _p.setString('lang', lang);
    _p.setString('theme', theme);
    _p.setBool('saver', saver);
    _p.setInt('quality', quality);
    _p.setInt('leave', leaveMode.index);
    _p.setBool('autoplay', autoplay);
    notifyListeners();
  }

  /// Effective UI language: 'th' or 'en'.
  String get code {
    if (lang == 'th' || lang == 'en') return lang;
    return PlatformDispatcher.instance.locale.languageCode == 'th' ? 'th' : 'en';
  }

  ThemeMode get themeMode =>
      theme == 'dark' ? ThemeMode.dark : theme == 'light' ? ThemeMode.light : ThemeMode.system;
}
