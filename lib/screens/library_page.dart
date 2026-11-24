import 'package:flutter/material.dart';

import '../core/strings.dart';
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
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
          bottom: TabBar(tabs: [Tab(text: S.t('history')), Tab(text: S.t('saved'))]),
        ),
        body: ListenableBuilder(
          listenable: Store.I,
          builder: (_, __) => TabBarView(children: [
            _list(Store.I.history, S.t('noHistory')),
            _list(Store.I.saved, S.t('noSaved')),
          ]),
        ),
      ),
    );
  }
}
