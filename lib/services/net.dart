import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Range download with retry. YouTube throttles single huge requests, but
/// serves small byte-ranges at full speed.
class Net {
  static final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 30);

  static Future<Uint8List> range(Uri url, int a, int b) async {
    Object? err;
    for (var t = 0; t < 3; t++) {
      try {
        final rq = await client.getUrl(url);
        rq.headers.set(HttpHeaders.rangeHeader, 'bytes=$a-$b');
        final rs = await rq.close();
        if (rs.statusCode != 206 && rs.statusCode != 200) {
          await rs.drain<void>();
          throw HttpException('HTTP ${rs.statusCode}');
        }
        final bb = BytesBuilder(copy: false);
        await for (final d in rs.timeout(const Duration(seconds: 20))) {
          bb.add(d);
        }
        return bb.takeBytes();
      } catch (e) {
        err = e;
        await Future.delayed(Duration(milliseconds: 400 * (t + 1)));
      }
    }
    throw err!;
  }
}

class _Src {
  final Uri url;
  final int total;
  final String mime;
  _Src(this.url, this.total, this.mime);
}

/// Tiny loopback server between the player and YouTube.
/// - fetches only the part being watched (in small chunks, 1 chunk read-ahead)
/// - small chunks avoid YouTube throttling => fast start, fast seek
/// - stops fetching as soon as the player stops reading => saves data+battery
class Proxy {
  static HttpServer? _s;
  static final Map<String, _Src> _m = {};
  static int _n = 0;
  static const _first = 512 << 10, _chunk = 1536 << 10;

  static Future<Uri> wrap(Uri url, int total, String mime) async {
    _s ??= await _start();
    final id = '${++_n}';
    if (_m.length > 8) _m.remove(_m.keys.first);
    _m[id] = _Src(url, total, mime);
    return Uri.parse('http://127.0.0.1:${_s!.port}/$id');
  }

  static Future<HttpServer> _start() async {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    s.listen(_handle, onError: (_) {});
    return s;
  }

  static Future<void> _handle(HttpRequest rq) async {
    final res = rq.response;
    final src = rq.uri.pathSegments.isEmpty ? null : _m[rq.uri.pathSegments.first];
    if (src == null) {
      res.statusCode = 404;
      await res.close();
      return;
    }
    var a = 0, b = src.total - 1;
    var partial = false;
    final h = rq.headers.value(HttpHeaders.rangeHeader);
    final m = h == null ? null : RegExp(r'bytes=(\d*)-(\d*)').firstMatch(h);
    if (m != null) {
      partial = true;
      final s = m.group(1)!, e = m.group(2)!;
      if (s.isEmpty) {
        a = src.total - (int.tryParse(e) ?? 0);
      } else {
        a = int.parse(s);
        if (e.isNotEmpty) b = min(int.parse(e), b);
      }
    }
    if (a < 0) a = 0;
    if (a > b) {
      res.statusCode = 416;
      await res.close();
      return;
    }
    res.statusCode = partial ? 206 : 200;
    res.headers
      ..set(HttpHeaders.contentTypeHeader, src.mime)
      ..set(HttpHeaders.acceptRangesHeader, 'bytes');
    if (partial) res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $a-$b/${src.total}');
    res.contentLength = b - a + 1;

    Future<Uint8List> get(int p, int sz) => Net.range(src.url, p, min(p + sz - 1, b));
    Future<Uint8List>? cur;
    try {
      var pos = a;
      cur = get(pos, _first);
      while (pos <= b) {
        final d = await cur!;
        if (d.isEmpty) throw const HttpException('empty');
        pos += d.length;
        cur = pos <= b ? get(pos, _chunk) : null; // read-ahead 1 chunk
        res.add(d);
        await res.flush(); // back-pressure: only as fast as the player reads
      }
    } catch (_) {
      // player left (seek/close) or network error: just end this response
    } finally {
      cur?.ignore();
      try {
        await res.close();
      } catch (_) {}
    }
  }
}
