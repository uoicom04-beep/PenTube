import '../core/fmt.dart';
import '../core/strings.dart';

class VideoRef {
  final String id, title, author, channelId;
  final int seconds;
  final int? views;
  final String? published;
  final bool live;

  const VideoRef({
    required this.id,
    required this.title,
    required this.author,
    required this.channelId,
    this.seconds = 0,
    this.views,
    this.published,
    this.live = false,
  });

  /// 320x180 thumbnail: small download.
  String get thumb => 'https://i.ytimg.com/vi/$id/mqdefault.jpg';

  String subtitle({bool author = true}) {
    final parts = <String>[
      if (author && this.author.isNotEmpty) this.author,
      if (fmtViews(views).isNotEmpty) '${fmtViews(views)} ${S.t('views')}',
      if (published != null && published!.isNotEmpty) published!,
    ];
    return parts.join(' · ');
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'author': author, 'channelId': channelId,
        'seconds': seconds, 'views': views, 'published': published, 'live': live,
      };

  factory VideoRef.fromJson(Map<String, dynamic> j) => VideoRef(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        author: j['author'] as String? ?? '',
        channelId: j['channelId'] as String? ?? '',
        seconds: j['seconds'] as int? ?? 0,
        views: j['views'] as int?,
        published: j['published'] as String?,
        live: j['live'] as bool? ?? false,
      );
}

class Paged {
  final List<VideoRef> items;
  final Future<Paged?> Function()? _next;
  Paged(this.items, [this._next]);
  Future<Paged?> more() async => _next == null ? null : _next!();
}
