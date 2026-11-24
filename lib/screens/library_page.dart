import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../services/downloads.dart';
import '../services/models.dart';
import '../services/store.dart';
import '../widgets/video_tile.dart';

class LibraryPage extends StatelessWidget {
  LibraryPage({super.key});

  Widget _list(List<VideoRef> l, String empty) {
    if (l.isEmpty) return Center(child: Text(empty));
    return ListView.builder(
      itemCount: l.length,
      itemBuilder: (_, i) => VideoTile(key: ValueKey(l[i].id), v: l[i], compact: true),
    );
  }

  Widget _offline() {
    final d = Downloads.I;
    final act = d.progress.keys.toList();
    if (d.items.isEmpty && act.isEmpty) return Center(child: Text(S.t('noDownloads')));
    return ListView(children: [
      for (final id in act)
        ListTile(
          title: Text('${((d.progress[id] ?? 0) * 100).round()}%'),
          subtitle: LinearProgressIndicator(value: d.progress[id]),
          trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => d.cancel(id)),
        ),
      for (final v in d.items) VideoTile(key: ValueKey(v.id), v: v, compact: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(S.t('library')),
          actions: [
            IconButton(
              tooltip: S.t('clear'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => Store.I.clearHistory(),
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(text: S.t('history')),
            Tab(text: S.t('saved')),
            Tab(text: S.t('downloads')),
          ]),
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([Store.I, Downloads.I]),
          builder: (_, __) => TabBarView(children: [
            _list(Store.I.history, S.t('noHistory')),
            _list(Store.I.saved, S.t('noSaved')),
            _offline(),
          ]),
        ),
      ),
    );
  }
}
