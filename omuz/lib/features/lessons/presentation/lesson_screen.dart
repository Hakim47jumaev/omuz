import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/youtube_id.dart';
import '../../../core/widgets/omuz_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/lesson_provider.dart';

class LessonScreen extends StatefulWidget {
  final int lessonId;
  const LessonScreen({super.key, required this.lessonId});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  YoutubePlayerController? _ytController;
  double _watchPercent = 0;
  bool _videoMarked = false;
  bool _wasYtFullScreen = false;

  @override
  void initState() {
    super.initState();
    final prov = context.read<LessonProvider>();
    Future.microtask(() => prov.load(widget.lessonId));
  }

  void _initYoutube(String url) {
    final videoId = resolveYoutubeVideoId(url);
    if (videoId != null && _ytController == null) {
      _ytController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: false),
      );
      _ytController!.addListener(_onYoutubeControllerUpdate);
      if (mounted) setState(() {});
    }
  }

  void _onYoutubeControllerUpdate() {
    final ctrl = _ytController;
    if (ctrl == null) return;

    final fs = ctrl.value.isFullScreen;
    if (fs != _wasYtFullScreen) {
      _wasYtFullScreen = fs;
      if (mounted) setState(() {});
    }

    _updateWatchProgress();
  }

  Future<void> _updateWatchProgress() async {
    final ctrl = _ytController;
    if (ctrl == null || _videoMarked) return;

    final position = ctrl.value.position;
    final duration = ctrl.metadata.duration;

    if (duration.inSeconds <= 0) return;

    final percent = position.inSeconds / duration.inSeconds;
    if (mounted) {
      setState(() => _watchPercent = percent.clamp(0.0, 1.0));
    }

    if (percent >= 0.8 && !_videoMarked) {
      _videoMarked = true;
      final prov = context.read<LessonProvider>();
      if (!prov.videoWatched) {
        await prov.markVideoWatched(widget.lessonId);
        if (mounted) {
          final msg = prov.completed
              ? 'Lesson completed!'
              : prov.hasQuiz
                  ? 'Video watched! Pass the quiz to complete the lesson.'
                  : 'Video watched! This lesson is complete.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.restoreSystemUIOverlays();
    _ytController?.removeListener(_onYoutubeControllerUpdate);
    _ytController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<LessonProvider>();
    final isStaff = context.watch<AuthProvider>().isStaff;
    final lesson = prov.lesson;

    if (lesson != null && _ytController == null) {
      _initYoutube(lesson['video_url'] as String);
    }

    final cs = Theme.of(context).colorScheme;

    final ytFullScreen = _ytController?.value.isFullScreen ?? false;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: ytFullScreen
          ? null
          : AppBar(title: Text(lesson?['title'] ?? 'Lesson')),
      body: prov.loading || lesson == null
          ? OmuzPage.background(
              context: context,
              child: const Center(child: CircularProgressIndicator()),
            )
          : OmuzPage.background(
              context: context,
              child: _ytController != null
                  ? YoutubePlayerBuilder(
                      onEnterFullScreen: () {
                        SystemChrome.setPreferredOrientations(const [
                          DeviceOrientation.landscapeLeft,
                          DeviceOrientation.landscapeRight,
                        ]);
                      },
                      onExitFullScreen: () {
                        SystemChrome.setPreferredOrientations(
                          DeviceOrientation.values,
                        );
                        SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.edgeToEdge,
                        );
                        SystemChrome.restoreSystemUIOverlays();
                      },
                      player: YoutubePlayer(
                        controller: _ytController!,
                        showVideoProgressIndicator: true,
                        progressIndicatorColor: cs.primary,
                        progressColors: ProgressBarColors(
                          playedColor: cs.primary,
                          handleColor: cs.primary,
                          bufferedColor: cs.primary.withValues(alpha: 0.35),
                          backgroundColor: cs.surfaceContainerHighest,
                        ),
                      ),
                      builder: (context, player) {
                        // Do not nest WebView inside ListView — on Android it does not
                        // scroll with the list and causes duplicate scroll areas.
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRect(
                              clipBehavior: Clip.hardEdge,
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: player,
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                padding: OmuzPage.padding,
                                children: [
                                  Text(
                                    lesson['title'] as String,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  if ((lesson['description'] as String)
                                      .isNotEmpty)
                                    Text(lesson['description'] as String),
                                  const SizedBox(height: 16),
                                  _buildStatusCard(prov),
                                  const SizedBox(height: 12),
                                  if (prov.hasQuiz && !isStaff)
                                    FilledButton.icon(
                                      onPressed: () async {
                                        final lessonProv =
                                            context.read<LessonProvider>();
                                        await context
                                            .push('/quiz/${widget.lessonId}');
                                        if (mounted) {
                                          lessonProv.load(widget.lessonId);
                                        }
                                      },
                                      icon: const Icon(Icons.quiz),
                                      label: Text(
                                        prov.quizPassed
                                            ? 'Quiz Passed (${prov.quizScore}%)'
                                            : 'Take Quiz',
                                      ),
                                      style: FilledButton.styleFrom(
                                        minimumSize:
                                            const Size.fromHeight(48),
                                        backgroundColor: prov.quizPassed
                                            ? AppTheme.success
                                            : null,
                                        foregroundColor: prov.quizPassed
                                            ? Colors.white
                                            : null,
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      context.push(
                                        '/ai-mentor',
                                        extra: widget.lessonId,
                                      );
                                    },
                                    icon: const Icon(Icons.smart_toy_outlined),
                                    label: const Text('AI for this lesson'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize:
                                          const Size.fromHeight(48),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : ListView(
                      children: [
                        SizedBox(
                          height: 200,
                          child: Center(
                            child: Text(
                              'Video unavailable',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ),
                        Padding(
                          padding: OmuzPage.padding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                lesson['title'] as String,
                                style:
                                    Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              if ((lesson['description'] as String).isNotEmpty)
                                Text(lesson['description'] as String),
                              const SizedBox(height: 16),
                              _buildStatusCard(prov),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _buildStatusCard(LessonProvider prov) {
    final cs = Theme.of(context).colorScheme;

    if (prov.completed) {
      return Card(
        color: AppTheme.success.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.success.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.success, size: 28),
              const SizedBox(width: 12),
              Text(
                'Lesson Completed',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Progress', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  prov.videoWatched ? Icons.check_circle : Icons.play_circle_outline,
                  color: prov.videoWatched ? AppTheme.success : cs.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prov.videoWatched ? 'Video watched' : 'Watch 80% of the video',
                  ),
                ),
              ],
            ),
            if (!prov.videoWatched) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _watchPercent,
                borderRadius: BorderRadius.circular(4),
                color: cs.primary,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ],
            if (prov.hasQuiz) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    prov.quizPassed ? Icons.check_circle : Icons.quiz_outlined,
                    color: prov.quizPassed ? AppTheme.success : cs.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      prov.quizPassed
                          ? 'Quiz passed (${prov.quizScore}%)'
                          : 'Pass the quiz with 80%+',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
