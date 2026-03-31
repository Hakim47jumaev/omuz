import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../core/utils/youtube_id.dart';

/// Full-screen preview player. Dialog + WebView often fails on Android; this matches [LessonScreen] pattern.
class CoursePreviewPlayerScreen extends StatefulWidget {
  const CoursePreviewPlayerScreen({
    super.key,
    required this.url,
    this.title = 'Preview',
  });

  final String url;
  final String title;

  @override
  State<CoursePreviewPlayerScreen> createState() =>
      _CoursePreviewPlayerScreenState();
}

class _CoursePreviewPlayerScreenState extends State<CoursePreviewPlayerScreen> {
  YoutubePlayerController? _controller;
  bool _wasFullScreen = false;

  @override
  void initState() {
    super.initState();
    final id = resolveYoutubeVideoId(widget.url);
    if (id == null) return;
    _controller = YoutubePlayerController(
      initialVideoId: id,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
      ),
    )..addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    final ctrl = _controller;
    if (ctrl == null) return;
    final fs = ctrl.value.isFullScreen;
    if (fs != _wasFullScreen) {
      _wasFullScreen = fs;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.restoreSystemUIOverlays();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = resolveYoutubeVideoId(widget.url);
    final cs = Theme.of(context).colorScheme;
    final ytFs = _controller?.value.isFullScreen ?? false;

    if (id == null || _controller == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Invalid or unsupported YouTube URL.',
              style: TextStyle(color: cs.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: ytFs
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(widget.title),
            ),
      body: YoutubePlayerBuilder(
        onEnterFullScreen: () {
          SystemChrome.setPreferredOrientations(const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        },
        onExitFullScreen: () {
          SystemChrome.setPreferredOrientations(DeviceOrientation.values);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          SystemChrome.restoreSystemUIOverlays();
        },
        player: YoutubePlayer(
          controller: _controller!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: cs.primary,
          progressColors: ProgressBarColors(
            playedColor: cs.primary,
            handleColor: cs.primary,
            bufferedColor: cs.primary.withValues(alpha: 0.35),
            backgroundColor: Colors.white24,
          ),
        ),
        builder: (context, player) {
          return Center(
            child: ColoredBox(
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: player,
              ),
            ),
          );
        },
      ),
    );
  }
}
