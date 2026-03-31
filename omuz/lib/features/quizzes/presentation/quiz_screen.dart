import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/omuz_ui.dart';
import '../../lessons/providers/lesson_provider.dart';
import '../providers/quiz_provider.dart';

class QuizScreen extends StatefulWidget {
  final int lessonId;
  const QuizScreen({super.key, required this.lessonId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static String _quizLine(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    return s;
  }

  @override
  void initState() {
    super.initState();
    final prov = context.read<QuizProvider>();
    Future.microtask(() => prov.load(widget.lessonId));
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<QuizProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(prov.quiz?['title'] ?? 'Quiz')),
      body: prov.loading
          ? OmuzPage.background(
              context: context,
              child: const Center(child: CircularProgressIndicator()),
            )
          : prov.quiz == null
              ? OmuzPage.background(
                  context: context,
                  child: Center(
                    child: Text('No quiz found',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                )
              : prov.result != null
                  ? _buildResult(prov)
                  : _buildQuestions(prov),
    );
  }

  Widget _buildQuestions(QuizProvider prov) {
    final cs = Theme.of(context).colorScheme;
    final questions = prov.quiz!['questions'] as List<dynamic>;
    final rules = (prov.quiz!['rules'] as Map<String, dynamic>?) ?? const {};
    final attemptsLeft = rules['attempts_left'] as int?;
    final cooldownSeconds = rules['cooldown_seconds'] as int? ?? 0;
    return Column(
      children: [
        if (attemptsLeft != null || cooldownSeconds > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (attemptsLeft != null)
                      Text('Attempts left today: $attemptsLeft'),
                    if (cooldownSeconds > 0)
                      Text('Cooldown: ${_fmtCooldown(cooldownSeconds)}'),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: OmuzPage.background(
            context: context,
            child: ListView.builder(
              padding: OmuzPage.padding,
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final q = questions[index] as Map<String, dynamic>;
                final qId = q['id'].toString();
                final answers = q['answers'] as List<dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  clipBehavior: Clip.none,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SelectableText(
                          'Q${index + 1}. ${_quizLine(q['text'])}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 1.45,
                                    color: cs.onSurface,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        ...answers.map((a) {
                          final aId = a['id'] as int;
                          final selected = prov.selectedAnswers[qId] == aId;
                          return Material(
                            color: selected
                                ? cs.primaryContainer.withValues(alpha: 0.45)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => prov.selectAnswer(qId, aId),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 4,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Icon(
                                        selected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        color: selected
                                            ? cs.primary
                                            : cs.onSurfaceVariant,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: SelectableText(
                                        _quizLine(a['text']),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: CheckboxListTile(
            value: prov.readingCheckpointConfirmed,
            onChanged: (v) => prov.setReadingCheckpoint(v ?? false),
            contentPadding: EdgeInsets.zero,
            title: const Text(
                'I reviewed lesson notes and confirm my answers.'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: FilledButton(
            onPressed: prov.submitting
                ? null
                : () async {
                    final ok = await prov.submit();
                    if (!ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(prov.lastError ?? 'Quiz submit failed'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    if (prov.result != null && mounted) {
                      final r = prov.result!;
                      final passed = r['passed'] as bool;
                      final score = r['score'] as int;
                      final lessonCompleted =
                          r['lesson_completed'] as bool? ?? false;
                      context.read<LessonProvider>().updateAfterQuiz(
                            passed: passed,
                            score: score,
                            lessonCompleted: lessonCompleted,
                          );
                    }
                  },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: prov.submitting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Text('Submit', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  String _fmtCooldown(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    if (m <= 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  Widget _buildResult(QuizProvider prov) {
    final cs = Theme.of(context).colorScheme;
    final r = prov.result!;
    final passed = r['passed'] as bool;
    final score = r['score'] as int;
    final lessonCompleted = r['lesson_completed'] as bool? ?? false;

    Color iconColor;
    if (lessonCompleted) {
      iconColor = AppTheme.success;
    } else if (passed) {
      iconColor = cs.primary;
    } else {
      iconColor = cs.tertiary;
    }

    return OmuzPage.background(
      context: context,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                lessonCompleted
                    ? Icons.celebration
                    : passed
                        ? Icons.check_circle
                        : Icons.sentiment_dissatisfied,
                size: 72,
                color: iconColor,
              ),
              const SizedBox(height: 16),
              Text(
                lessonCompleted
                    ? 'Lesson Completed!'
                    : passed
                        ? 'Quiz Passed!'
                        : 'Try Again',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${r['correct']}/${r['total']} correct  •  $score%',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (passed && !lessonCompleted) ...[
                const SizedBox(height: 8),
                Text(
                  'Watch the video to complete the lesson',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
              if (!passed) ...[
                const SizedBox(height: 8),
                Text(
                  'You need 80% or higher to pass',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Lesson'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
