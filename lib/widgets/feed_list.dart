import 'package:flutter/material.dart';

import '../core/settings.dart';
import '../core/strings.dart';
import '../services/models.dart';
import 'video_tile.dart';

/// Paged, lazily-built list of videos with pull-to-refresh.
class FeedList extends StatefulWidget {
  final Future<Paged> Function(bool force) first;
  final void Function(VideoRef v)? onTap;
  final bool compact;
  const FeedList({super.key, required this.first, this.onTap, this.compact = false});

  @override
  State<FeedList> createState() => _FeedListState();
}

class _FeedListState extends State<FeedList> {
  List<VideoRef> _items = [];
  Paged? _cur;
  bool _loading = true, _more = false, _done = false;
  String? _error;
  int _pages = 1;
  final Set<String> _seen = {};

  @override
  void initState() {
    super.initState();
    _load(false);
  }

  void _add(List<VideoRef> l) {
    for (final v in l) {
      if (_seen.add(v.id)) _items.add(v);
    }
  }

  Future<void> _load(bool force) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await widget.first(force);
      _cur = p;
      _items = [];
      _seen.clear();
      _add(p.items);
      _pages = 1;
      _done = false;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_more || _done || _loading || _cur == null) return;
    if (_pages >= (Settings.I.saver ? 3 : 8)) {
      _done = true;
      return;
    }
    setState(() => _more = true);
    try {
      final n = await _cur!.more();
      if (n == null) {
        _done = true;
      } else {
        _cur = n;
        _add(n.items);
        _pages++;
      }
    } catch (_) {
      _done = true;
    }
    if (mounted) setState(() => _more = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(S.t('error')),
          TextButton(onPressed: () => _load(true), child: Text(S.t('retry'))),
        ]),
      );
    }
    if (_items.isEmpty) return Center(child: Text(S.t('noResults')));
    return RefreshIndicator(
      onRefresh: () => _load(true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 800) _loadMore();
          return false;
        },
        child: ListView.builder(
          cacheExtent: 400,
          itemCount: _items.length + (_more ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= _items.length) {
              return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
            }
            final v = _items[i];
            return VideoTile(
              key: ValueKey(v.id),
              v: v,
              compact: widget.compact,
              onTap: widget.onTap == null ? null : () => widget.onTap!(v),
            );
          },
        ),
      ),
    );
  }
}
