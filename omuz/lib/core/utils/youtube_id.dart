import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Resolves watch/embed URLs and YouTube Shorts (`/shorts/VIDEO_ID`).
String? resolveYoutubeVideoId(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final fromPkg = YoutubePlayer.convertUrlToId(trimmed);
  if (fromPkg != null) return fromPkg;
  final shorts =
      RegExp(r'(?:youtube\.com/shorts/)([\w-]{11})').firstMatch(trimmed);
  if (shorts != null) return shorts.group(1);
  return null;
}
