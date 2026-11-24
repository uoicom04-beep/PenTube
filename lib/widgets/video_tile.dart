import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/fmt.dart';
import '../core/settings.dart';
import '../core/strings.dart';
import '../screens/watch_screen.dart';
import '../services/downloads.dart';
import '../services/models.dart';
import '../services/store.dart';

class VideoTile extends StatelessWidget {
  final VideoRef v;
  final bool compact;
  final VoidCallback? onTap;
  const VideoTile({super.key, required this.v, this.compact = false, this.onTap});

  void _open(BuildContext c) {
    Navigator.of(c).push(MaterialPageRoute(builder: (_) => WatchScreen(video: v)));
  }

  Widget _badge(String t, {Color color = Colors.black87}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final cacheW = compact ? 320 : (Settings.I.saver ? 360 : 640);
    final thumb = AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(fit: StackFit.expand, children: [
        CachedNetworkImage(
          imageUrl: v.thumb,
          fit: BoxFit.cover,
          memCacheWidth: cacheW,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (_, __) => Container(color: th.colorScheme.surfaceContainerHighest),
          errorWidget: (_, __, ___) => Container(color: th.colorScheme.surfaceContainerHighest),
        ),
        Positioned(
          right: 6,
          bottom: 6,
          child: v.live
              ? _badge(S.t('live'), color: Colors.red)
              : (v.seconds > 0 ? _badge(fmtSeconds(v.seconds)) : const SizedBox()),
        ),
      ]),
    );

    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: th.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(v.subtitle(), maxLines: 2, overflow: TextOverflow.ellipsis,
          style: th.textTheme.bodySmall?.copyWith(color: th.colorScheme.onSurfaceVariant)),
    ]);

    final menu = PopupMenuButton<int>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (i) {
        if (i == 0) {
          Store.I.toggleSaved(v);
        } else if (i == 2) {
          final d = Downloads.I;
          d.has(v.id) ? d.remove(v.id) : d.start(v);
        } else {
          Clipboard.setData(ClipboardData(text: 'https://youtu.be/${v.id}'));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.t('copied'))));
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 0, child: Text(S.t('save'))),
        PopupMenuItem(value: 2, child: Text(S.t(Downloads.I.has(v.id) ? 'removeDownload' : 'download'))),
        PopupMenuItem(value: 1, child: Text(S.t('copyLink'))),
      ],
    );

    return InkWell(
      onTap: onTap ?? () => _open(context),
      child: compact
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 160, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: thumb)),
                const SizedBox(width: 10),
                Expanded(child: info),
                menu,
              ]),
            )
          : Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                thumb,
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: info),
                    menu,
                  ]),
                ),
              ]),
            ),
    );
  }
}
