import 'package:flutter/material.dart';

import '../core/settings.dart';
import '../core/strings.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'settings_page.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.I,
      builder: (context, _) => Scaffold(
        body: IndexedStack(index: _i, children: [HomePage(), LibraryPage(), SettingsPage()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (i) => setState(() => _i = i),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: S.t('home')),
            NavigationDestination(icon: const Icon(Icons.video_library_outlined), selectedIcon: const Icon(Icons.video_library), label: S.t('library')),
            NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: S.t('settings')),
          ],
        ),
      ),
    );
  }
}
