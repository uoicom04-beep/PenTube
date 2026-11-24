import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'models.dart';

/// Thin wrapper over youtube_explode_dart. No account, no ads, no tracking.
class Yt {
  static final YoutubeExplode _yt = YoutubeExplode();
  static final Map<String, Paged> _searchCache = {};
  static final Map<String, StreamManifest> _manifestCache = {};

  static VideoRef _v(Video v) => VideoRef(
        id: v.id.value,
        title: v.title,
        author: v.author,
        channelId: v.channelId.value,
        seconds: v.duration?.inSeconds ?? 0,
        views: v.engagement.viewCount,
        published: v.uploadDateRaw,
        live: v.isLive,
      );

  static Paged _wrap(VideoSearchList l) => Paged(l.map(_v).toList(), () async {
        final n = await l.nextPage();
        return n == null ? null : _wrap(n);
      });

  static Future<Paged> search(String q, {bool force = false}) async {
    if (!force && _searchCache.containsKey(q)) return _searchCache[q]!;
    final r = await _yt.search.search(q);
    if (_searchCache.length > 20) _searchCache.remove(_searchCache.keys.first);
    return _searchCache[q] = _wrap(r);
  }

  static Future<Paged> uploads(String channelId) async {
    final l = await _yt.channels.getUploads(ChannelId(channelId)).take(30).toList();
    return Paged(l.map(_v).toList());
  }

  static Future<List<String>> suggest(String q) => _yt.search.getQuerySuggestions(q);

  static Future<StreamManifest> manifest(String id) async {
    final c = _manifestCache[id];
    if (c != null) return c;
    final m = await _yt.videos.streamsClient.getManifest(id);
    if (_manifestCache.length > 10) _manifestCache.remove(_manifestCache.keys.first);
    return _manifestCache[id] = m;
  }

  static void forget(String id) => _manifestCache.remove(id);

  /// Video+audio in one file (progressive), sorted by height ascending.
  static Future<List<MuxedStreamInfo>> muxed(String id) async {
    final m = await manifest(id);
    final l = m.muxed.toList();
    l.sort((a, b) => a.videoResolution.height.compareTo(b.videoResolution.height));
    return l;
  }

  static Future<AudioOnlyStreamInfo> audio(String id, {required bool low}) async {
    final m = await manifest(id);
    var l = m.audioOnly.where((a) => a.container.name == 'mp4').toList();
    if (l.isEmpty) l = m.audioOnly.toList();
    l.sort((a, b) => a.bitrate.bitsPerSecond.compareTo(b.bitrate.bitsPerSecond));
    return low ? l.first : l.last;
  }
}
