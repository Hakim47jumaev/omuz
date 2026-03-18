import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../lessons/providers/lesson_provider.dart';
import '../providers/quiz_provider.dart';

class QuizScreen extends StatefulWidget {
  final int lessonId;
  const QuizScreen({super.key, required this.lessonId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<QuizProvider>();
    Future.microtask(() => prov.load(widget.lessonId));
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<QuizProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(prov.quiz?['title'] ?? 'Quiz')),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : prov.quiz == null
              ? const Center(child: Text('No quiz found'))
              : prov.result != null
                  ? _buildResult(prov)
                  : _buildQuestions(prov),
    );
  }

  Widget _buildQuestions(QuizProvider prov) {
    final questions = prov.quiz!['questions'] as List<dynamic>;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final q = questions[index] as Map<String, dynamic>;
              final qId = q['id'].toString();
              final answers = q['answers'] as List<dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q${index + 1}. ${q['text']}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      ...answers.map((a) {
                        final aId = a['id'] as int;
                        final selected = prov.selectedAnswers[qId] == aId;
                        return ListTile(
                          leading: Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(a['text'] as String),
                          onTap: () => prov.selectAnswer(qId, aId),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: prov.submitting
                ? null
                : () async {
                    await prov.submit();
                    if (prov.result != null && mounted) {
                      final r = prov.result!;
                      final passed = r['passed'] as bool;
                      final score = r['score'] as int;
                      final lessonCompleted = r['lesson_completed'] as bool? ?? false;
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
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(QuizProvider prov) {
    final r = prov.result!;
    final passed = r['passed'] as bool;
    final score = r['score'] as int;
    final lessonCompleted = r['lesson_completed'] as bool? ?? false;

    return Center(
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
              color: lessonCompleted
                  ? Colors.green
                  : passed
                      ? Colors.blue
                      : Colors.orange,
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
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
            if (!passed) ...[
              const SizedBox(height: 8),
              Text(
                'You need 80% or higher to pass',
                style: TextStyle(color: Colors.grey.shade600),
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
    );
  }
}
