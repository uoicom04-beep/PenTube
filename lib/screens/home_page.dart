import 'package:flutter/material.dart';

import '../core/settings.dart';
import '../core/strings.dart';
import '../services/yt.dart';
import '../widgets/brand.dart';
import '../widgets/feed_list.dart';
import 'search_screen.dart';

class HomePage extends StatefulWidget {
  HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _c = 0;

  static const List<(String, Map<String, String>)> _cats = [
    ('c_all', {'en': 'trending today', 'th': 'ยอดนิยมวันนี้'}),
    ('c_music', {'en': 'new music', 'th': 'เพลงใหม่ล่าสุด'}),
    ('c_gaming', {'en': 'gaming', 'th': 'เกมมิ่ง'}),
    ('c_news', {'en': 'news today', 'th': 'ข่าววันนี้'}),
    ('c_movies', {'en': 'movie trailers', 'th': 'ตัวอย่างหนังใหม่'}),
    ('c_sports', {'en': 'sports highlights', 'th': 'ไฮไลท์กีฬา'}),
    ('c_learn', {'en': 'learn something new', 'th': 'ความรู้น่ารู้'}),
    ('c_cook', {'en': 'cooking', 'th': 'ทำอาหาร'}),
    ('c_tech', {'en': 'tech review', 'th': 'รีวิวมือถือ'}),
  ];

  @override
  Widget build(BuildContext context) {
    final code = Settings.I.code;
    final q = _cats[_c].$2[code]!;
    return Scaffold(
      appBar: AppBar(
        title: const Brand(),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchScreen())),
          ),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: _cats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(S.t(_cats[i].$1)),
              selected: _c == i,
              onSelected: (_) => setState(() => _c = i),
            ),
          ),
        ),
        Expanded(child: FeedList(key: ValueKey('$_c$code'), first: (f) => Yt.search(q, force: f))),
      ]),
    );
  }
}
