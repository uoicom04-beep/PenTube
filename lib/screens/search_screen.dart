import 'dart:async';
import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../services/store.dart';
import '../services/yt.dart';
import '../widgets/feed_list.dart';

class SearchScreen extends StatefulWidget {
  SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctl = TextEditingController();
  final _focus = FocusNode();
  Timer? _deb;
  List<String> _sugg = [];
  String _q = '';
  bool _results = false;

  @override
  void dispose() {
    _deb?.cancel();
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String t) {
    _deb?.cancel();
    setState(() => _results = false);
    if (t.trim().isEmpty) {
      setState(() => _sugg = []);
      return;
    }
    _deb = Timer(const Duration(milliseconds: 350), () async {
      try {
        final s = await Yt.suggest(t.trim());
        if (mounted && _ctl.text.trim() == t.trim()) setState(() => _sugg = s.take(8).toList());
      } catch (_) {}
    });
  }

  void _submit(String t) {
    final q = t.trim();
    if (q.isEmpty) return;
    _ctl.text = q;
    _ctl.selection = TextSelection.collapsed(offset: q.length);
    Store.I.addRecent(q);
    _focus.unfocus();
    setState(() {
      _q = q;
      _results = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final typing = _ctl.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctl,
          focusNode: _focus,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: S.t('searchHint'), border: InputBorder.none),
          onChanged: _changed,
          onTap: () => setState(() => _results = false),
          onSubmitted: _submit,
        ),
        actions: [
          if (typing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _ctl.clear();
                _changed('');
                _focus.requestFocus();
              },
            ),
        ],
      ),
      body: _results
          ? FeedList(key: ValueKey(_q), first: (f) => Yt.search(_q, force: f))
          : ListenableBuilder(
              listenable: Store.I,
              builder: (_, __) {
                final list = typing ? _sugg : Store.I.recent;
                return ListView.builder(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: list.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: Icon(typing ? Icons.search : Icons.history),
                    title: Text(list[i], maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: typing
                        ? IconButton(
                            icon: const Icon(Icons.north_west, size: 18),
                            onPressed: () {
                              _ctl.text = list[i];
                              _ctl.selection = TextSelection.collapsed(offset: list[i].length);
                              _changed(list[i]);
                            },
                          )
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => Store.I.removeRecent(list[i]),
                          ),
                    onTap: () => _submit(list[i]),
                  ),
                );
              },
            ),
    );
  }
}
