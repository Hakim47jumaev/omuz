import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    final prov = context.read<LessonProvider>();
    Future.microtask(() => prov.load(widget.lessonId));
  }

  void _initYoutube(String url) {
    final videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId != null && _ytController == null) {
      _ytController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: false),
      );
      _ytController!.addListener(_onVideoProgress);
      if (mounted) setState(() {});
    }
  }

  void _onVideoProgress() async {
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
              : 'Video watched! Now pass the quiz to complete the lesson.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _ytController?.removeListener(_onVideoProgress);
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

    return Scaffold(
      appBar: AppBar(title: Text(lesson?['title'] ?? 'Lesson')),
      body: prov.loading || lesson == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_ytController != null)
                  YoutubePlayer(controller: _ytController!)
                else
                  const SizedBox(
                    height: 200,
                    child: Center(child: Text('Video unavailable')),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        lesson['title'] as String,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      if ((lesson['description'] as String).isNotEmpty)
                        Text(lesson['description'] as String),
                      const SizedBox(height: 16),
                      _buildStatusCard(prov),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: () => context.push(
                          '/ai/mentor',
                          extra: {
                            'lesson_title': lesson['title'],
                          },
                        ),
                        icon: const Icon(Icons.smart_toy_outlined),
                        label: const Text('AI Помощник'),
                      ),
                      const SizedBox(height: 12),
                      if (lesson['has_quiz'] == true && !isStaff)
                        FilledButton.icon(
                          onPressed: () async {
                            final lessonProv = context.read<LessonProvider>();
                            await context.push('/quiz/${widget.lessonId}');
                            if (mounted) {
                              lessonProv.load(widget.lessonId);
                            }
                          },
                          icon: const Icon(Icons.quiz),
                          label: Text(prov.quizPassed ? 'Quiz Passed (${prov.quizScore}%)' : 'Take Quiz'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: prov.quizPassed ? Colors.green : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusCard(LessonProvider prov) {
    if (prov.completed) {
      return Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              Text(
                'Lesson Completed',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green.shade800,
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
                  color: prov.videoWatched ? Colors.green : Colors.grey,
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
              ),
            ],
            if (prov.hasQuiz) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    prov.quizPassed ? Icons.check_circle : Icons.quiz_outlined,
                    color: prov.quizPassed ? Colors.green : Colors.grey,
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
