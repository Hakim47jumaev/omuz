import 'package:flutter/material.dart';

import '../data/admin_repository.dart';

class AdminQuizScreen extends StatefulWidget {
  final int lessonId;
  final String lessonTitle;
  const AdminQuizScreen(
      {super.key, required this.lessonId, required this.lessonTitle});

  @override
  State<AdminQuizScreen> createState() => _AdminQuizScreenState();
}

class _AdminQuizScreenState extends State<AdminQuizScreen> {
  final _repo = AdminRepository();
  Map<String, dynamic>? _quiz;
  List<dynamic> _questions = [];
  Map<int, List<dynamic>> _answersByQuestion = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _quiz = await _repo.getQuizForLesson(widget.lessonId);
    if (_quiz != null) {
      final quizId = _quiz!['id'] as int;
      _questions = await _repo.getQuestions(quizId);
      _answersByQuestion = {};
      for (final q in _questions) {
        final qId = q['id'] as int;
        _answersByQuestion[qId] = await _repo.getAnswers(qId);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Quiz: ${widget.lessonTitle}')),
      floatingActionButton: _quiz != null
          ? FloatingActionButton(
              onPressed: _addQuestion,
              child: const Icon(Icons.add),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _quiz == null
              ? Center(
                  child: FilledButton.icon(
                    onPressed: _createQuiz,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Quiz for this lesson'),
                  ),
                )
              : _questions.isEmpty
                  ? const Center(
                      child: Text('No questions yet. Tap + to add.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _questions.length,
                      itemBuilder: (context, i) => _buildQuestion(i),
                    ),
    );
  }

  Widget _buildQuestion(int index) {
    final q = _questions[index] as Map<String, dynamic>;
    final qId = q['id'] as int;
    final answers = _answersByQuestion[qId] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Q${index + 1}. ${q['text']}',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () async {
                    await _repo.deleteQuestion(qId);
                    _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...answers.map((a) {
              final isCorrect = a['is_correct'] as bool;
              return ListTile(
                dense: true,
                leading: Icon(
                  isCorrect ? Icons.check_circle : Icons.circle_outlined,
                  color: isCorrect ? Colors.green : Colors.grey,
                  size: 20,
                ),
                title: Text(a['text'] as String),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () async {
                    await _repo.deleteAnswer(a['id'] as int);
                    _load();
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _createQuiz() async {
    final quiz = await _repo.createQuiz({
      'lesson': widget.lessonId,
      'title': '${widget.lessonTitle} Quiz',
    });
    setState(() => _quiz = quiz);
    _load();
  }

  void _addQuestion() {
    final questionC = TextEditingController();
    final answer1C = TextEditingController();
    final answer2C = TextEditingController();
    final answer3C = TextEditingController();
    final answer4C = TextEditingController();
    final correct = [true, false, false, false];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionC,
                  decoration: const InputDecoration(labelText: 'Question'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                _answerField(answer1C, 'Option A', correct, 0, setDialogState),
                const SizedBox(height: 8),
                _answerField(answer2C, 'Option B', correct, 1, setDialogState),
                const SizedBox(height: 8),
                _answerField(answer3C, 'Option C', correct, 2, setDialogState),
                const SizedBox(height: 8),
                _answerField(answer4C, 'Option D', correct, 3, setDialogState),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (questionC.text.isEmpty) return;
                final controllers = [answer1C, answer2C, answer3C, answer4C];
                final filled = controllers
                    .where((c) => c.text.isNotEmpty)
                    .toList();
                if (filled.length < 2) return;

                final q = await _repo.createQuestion({
                  'quiz': _quiz!['id'],
                  'text': questionC.text,
                  'order': _questions.length,
                });
                final qId = q['id'] as int;

                for (int i = 0; i < controllers.length; i++) {
                  if (controllers[i].text.isNotEmpty) {
                    await _repo.createAnswer({
                      'question': qId,
                      'text': controllers[i].text,
                      'is_correct': correct[i],
                    });
                  }
                }

                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _answerField(TextEditingController controller, String label,
      List<bool> correct, int index, StateSetter setDialogState) {
    return Row(
      children: [
        Checkbox(
          value: correct[index],
          onChanged: (val) {
            setDialogState(() => correct[index] = val ?? false);
          },
        ),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
