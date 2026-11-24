import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Local-only history / saved / recent searches.
class Store extends ChangeNotifier {
  Store._();
  static final Store I = Store._();

  late SharedPreferences _p;
  List<VideoRef> history = [];
  List<VideoRef> saved = [];
  List<String> recent = [];

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    history = _read('history');
    saved = _read('saved');
    recent = _p.getStringList('recent') ?? [];
  }

  List<VideoRef> _read(String k) {
    try {
      final raw = _p.getString(k);
      if (raw == null) return [];
      return (jsonDecode(raw) as List)
          .map((e) => VideoRef.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _write(String k, List<VideoRef> l) =>
      _p.setString(k, jsonEncode(l.map((e) => e.toJson()).toList()));

  void addHistory(VideoRef v) {
    history.removeWhere((e) => e.id == v.id);
    history.insert(0, v);
    if (history.length > 100) history.removeLast();
    _write('history', history);
    notifyListeners();
  }

  void clearHistory() {
    history = [];
    _write('history', history);
    notifyListeners();
  }

  bool isSaved(String id) => saved.any((e) => e.id == id);

  void toggleSaved(VideoRef v) {
    if (isSaved(v.id)) {
      saved.removeWhere((e) => e.id == v.id);
    } else {
      saved.insert(0, v);
    }
    _write('saved', saved);
    notifyListeners();
  }

  void addRecent(String q) {
    recent.remove(q);
    recent.insert(0, q);
    if (recent.length > 15) recent.removeLast();
    _p.setStringList('recent', recent);
    notifyListeners();
  }

  void removeRecent(String q) {
    recent.remove(q);
    _p.setStringList('recent', recent);
    notifyListeners();
  }
}
