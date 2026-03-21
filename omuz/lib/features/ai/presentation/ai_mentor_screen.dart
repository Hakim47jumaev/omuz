import 'package:flutter/material.dart';

import '../data/ai_repository.dart';

class AiMentorScreen extends StatefulWidget {
  final Map<String, dynamic>? initialContext;
  const AiMentorScreen({super.key, this.initialContext});

  @override
  State<AiMentorScreen> createState() => _AiMentorScreenState();
}

class _AiMentorScreenState extends State<AiMentorScreen> {
  final _repo = AiRepository();
  final _ctrl = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;

  String get _courseTitle => (widget.initialContext?['course_title'] as String?) ?? '';
  String get _lessonTitle => (widget.initialContext?['lesson_title'] as String?) ?? '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _sending = true;
      _ctrl.clear();
    });
    try {
      final history = _messages
          .map((m) => {'role': m.role, 'content': m.text})
          .toList(growable: false);
      final res = await _repo.askMentor(
        message: text,
        history: history,
        courseTitle: _courseTitle.isEmpty ? null : _courseTitle,
        lessonTitle: _lessonTitle.isEmpty ? null : _lessonTitle,
      );
      if (!mounted) return;
      final answer = (res['answer'] as String?)?.trim();
      setState(() {
        _messages.add(
          _ChatMessage(
            role: 'assistant',
            text: answer?.isNotEmpty == true ? answer! : 'Нет ответа от AI',
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.fixed,
          content: Text(
            'Ошибка AI: $e',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Помощник')),
      body: Column(
        children: [
          if (_courseTitle.isNotEmpty || _lessonTitle.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(
                [
                  if (_courseTitle.isNotEmpty) 'Курс: $_courseTitle',
                  if (_lessonTitle.isNotEmpty) 'Урок: $_lessonTitle',
                ].join(' • '),
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text('Спроси по теме урока, и я помогу разобраться.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _bubble(_messages[i]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Например: объясни тему простыми словами',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_ChatMessage m) {
    final isUser = m.role == 'user';
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isUser ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          m.text,
          style: TextStyle(color: isUser ? Colors.white : cs.onSurface),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String text;
  const _ChatMessage({required this.role, required this.text});
}
