import 'package:flutter/material.dart';

import '../services/models.dart';
import '../services/yt.dart';
import '../widgets/feed_list.dart';

/// Opened from the watch screen. Picking a video pops it back to the player.
class ChannelScreen extends StatelessWidget {
  final String channelId, name;
  const ChannelScreen({super.key, required this.channelId, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: FeedList(
        first: (_) => Yt.uploads(channelId),
        compact: true,
        onTap: (VideoRef v) => Navigator.of(context).pop(v),
      ),
    );
  }
}
