import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android Picture-in-Picture (floating window) via a tiny native channel
/// (see scripts/patch_platforms.py -> MainActivity.kt).
class Pip {
  static const MethodChannel _c = MethodChannel('app.pentube/pip');
  static final ValueNotifier<bool> inPip = ValueNotifier<bool>(false);
  static bool supported = false;

  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      supported = await _c.invokeMethod<bool>('supported') ?? false;
      _c.setMethodCallHandler((call) async {
        if (call.method == 'pipChanged') inPip.value = call.arguments as bool;
      });
    } catch (_) {
      supported = false;
    }
  }

  /// When armed, pressing Home turns the video into a floating window.
  static Future<void> arm(bool on) async {
    if (!supported) return;
    try {
      await _c.invokeMethod('arm', on);
    } catch (_) {}
  }

  static Future<bool> enter() async {
    if (!supported) return false;
    try {
      return await _c.invokeMethod<bool>('enter') ?? false;
    } catch (_) {
      return false;
    }
  }
}
