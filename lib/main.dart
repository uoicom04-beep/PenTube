import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/settings.dart';
import 'screens/shell.dart';
import 'services/audio_handler.dart';
import 'services/pip.dart';
import 'services/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep RAM small for low-end phones.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 60 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 120;

  await Settings.I.load();
  await Store.I.load();
  await Pip.init();
  audioHandler = await AudioService.init(
    builder: () => PenAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'app.pentube.audio',
      androidNotificationChannelName: 'PenTube',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  runApp(const PenTubeApp());
}

class PenTubeApp extends StatelessWidget {
  const PenTubeApp({super.key});

  ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? const Color(0xFF0F0F0F) : Colors.white;
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE53935), brightness: b),
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(backgroundColor: bg, elevation: 0, scrolledUnderElevation: 0),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: bg),
      splashFactory: NoSplash.splashFactory,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.I,
      builder: (context, _) => MaterialApp(
        title: 'PenTube',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: Settings.I.themeMode,
        locale: Locale(Settings.I.code),
        supportedLocales: const [Locale('en'), Locale('th')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Shell(),
      ),
    );
  }
}
