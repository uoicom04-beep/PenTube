import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/settings.dart';
import 'models.dart';
import 'net.dart';
import 'yt.dart';

/// Offline videos: saved on the phone, play with no internet.
class Downloads extends ChangeNotifier {
  Downloads._();
  static final Downloads I = Downloads._();

  late SharedPreferences _p;
  late Directory _dir;
  List<VideoRef> items = []; // finished
  final Map<String, double> progress = {}; // active (0..1)
  final Set<String> failed = {};
  final Set<String> _cancel = {};

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    _dir = Directory('${(await getApplicationDocumentsDirectory()).path}/offline');
    await _dir.create(recursive: true);
    try {
      final raw = _p.getString('downloads');
      if (raw != null) {
        items = (jsonDecode(raw) as List)
            .map((e) => VideoRef.fromJson(e as Map<String, dynamic>))
            .where((v) => File('${_dir.path}/${v.id}.mp4').existsSync())
            .toList();
      }
    } catch (_) {}
    // drop half-finished files from a previous run
    for (final f in _dir.listSync()) {
      if (f.path.endsWith('.part')) f.deleteSync();
    }
  }

  File? file(String id) {
    if (!items.any((e) => e.id == id)) return null;
    final f = File('${_dir.path}/$id.mp4');
    return f.existsSync() ? f : null;
  }

  bool has(String id) => items.any((e) => e.id == id);
  bool active(String id) => progress.containsKey(id);

  void _save() => _p.setString('downloads', jsonEncode(items.map((e) => e.toJson()).toList()));

  Future<void> remove(String id) async {
    items.removeWhere((e) => e.id == id);
    _save();
    notifyListeners();
    try {
      await File('${_dir.path}/$id.mp4').delete();
    } catch (_) {}
  }

  void cancel(String id) {
    if (active(id)) _cancel.add(id);
  }

  Future<void> start(VideoRef v) async {
    if (has(v.id) || active(v.id)) return;
    failed.remove(v.id);
    progress[v.id] = 0;
    notifyListeners();
    final part = File('${_dir.path}/${v.id}.part');
    try {
      final all = await Yt.muxed(v.id);
      var pick = all.first;
      for (final m in all) {
        if (m.videoResolution.height <= Settings.I.quality) pick = m;
      }
      final total = pick.size.totalBytes;
      final out = part.openSync(mode: FileMode.write);
      try {
        const chunk = 2 << 20;
        var pos = 0;
        Future<Uint8List>? cur = Net.range(pick.url, 0, min(chunk, total) - 1);
        var last = 0;
        while (pos < total) {
          final d = await cur!;
          if (d.isEmpty) throw const HttpException('empty');
          pos += d.length;
          cur = pos < total ? Net.range(pick.url, pos, min(pos + chunk, total) - 1) : null;
          out.writeFromSync(d);
          if (_cancel.contains(v.id)) {
            cur?.ignore();
            throw StateError('cancelled');
          }
          final pc = (pos * 100 ~/ total);
          if (pc != last) {
            last = pc;
            progress[v.id] = pos / total;
            notifyListeners();
          }
        }
      } finally {
        out.closeSync();
      }
      await part.rename('${_dir.path}/${v.id}.mp4');
      items.insert(0, v);
      _save();
    } catch (e) {
      Yt.forget(v.id);
      if (!_cancel.contains(v.id)) failed.add(v.id);
      try {
        await part.delete();
      } catch (_) {}
    } finally {
      _cancel.remove(v.id);
      progress.remove(v.id);
      notifyListeners();
    }
  }
}
