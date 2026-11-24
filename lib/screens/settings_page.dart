import 'package:flutter/material.dart';

import '../core/settings.dart';
import '../core/strings.dart';
import '../services/pip.dart';
import '../widgets/brand.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({super.key});

  Widget _dd<T>(T value, Map<T, String> items, ValueChanged<T> onChanged) => DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );

  @override
  Widget build(BuildContext context) {
    final s = Settings.I;
    return Scaffold(
      appBar: AppBar(title: Text(S.t('settings'))),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(S.t('language')),
          trailing: _dd<String>(s.lang, {'system': S.t('auto'), 'th': 'ไทย', 'en': 'English'},
              (v) => s.update(() => s.lang = v)),
        ),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: Text(S.t('theme')),
          trailing: _dd<String>(s.theme, {'system': S.t('auto'), 'dark': S.t('dark'), 'light': S.t('light')},
              (v) => s.update(() => s.theme = v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.battery_saver),
          title: Text(S.t('saver')),
          subtitle: Text(S.t('saverDesc')),
          value: s.saver,
          onChanged: (v) => s.update(() => s.saver = v),
        ),
        ListTile(
          leading: const Icon(Icons.high_quality_outlined),
          title: Text(S.t('quality')),
          trailing: _dd<int>(s.quality, {144: '144p', 360: '360p', 720: '720p'}, (v) => s.update(() => s.quality = v)),
        ),
        ListTile(
          leading: const Icon(Icons.exit_to_app),
          title: Text(S.t('leaveMode')),
          trailing: _dd<LeaveMode>(
            (s.leaveMode == LeaveMode.pip && !Pip.supported) ? LeaveMode.audio : s.leaveMode,
            {
              if (Pip.supported) LeaveMode.pip: S.t('modePip'),
              LeaveMode.audio: S.t('modeAudio'),
              LeaveMode.stop: S.t('modeStop'),
            },
            (v) => s.update(() => s.leaveMode = v),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.skip_next_outlined),
          title: Text(S.t('autoplay')),
          value: s.autoplay,
          onChanged: (v) => s.update(() => s.autoplay = v),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(S.t('about')),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Brand(),
              const SizedBox(height: 6),
              Text(S.t('tagline')),
              const SizedBox(height: 4),
              Text(S.t('aboutText')),
              const SizedBox(height: 4),
              const Text('v1.0.0'),
            ]),
          ),
        ),
      ]),
    );
  }
}
