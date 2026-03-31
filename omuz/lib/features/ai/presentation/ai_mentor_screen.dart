import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/widgets/omuz_ui.dart';
import '../data/ai_repository.dart';

/// [lessonId] == null: home-tab mentor (catalog, discounts, how the app works).
/// [lessonId] != null: lesson-scoped help; answers rendered as Markdown.
class AiMentorScreen extends StatefulWidget {
  final int? lessonId;

  const AiMentorScreen({super.key, this.lessonId});

  @override
  State<AiMentorScreen> createState() => _AiMentorScreenState();
}

class _AiMentorScreenState extends State<AiMentorScreen> {
  final _repo = AiRepository();
  final _ctrl = TextEditingController();
  final List<_ChatMessage> _messages = [];
  static const int _maxSessionMessages = 10;
  bool _sending = false;

  bool get _lessonMode => widget.lessonId != null;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    if (_messages.length >= _maxSessionMessages) {
      setState(_messages.clear);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Chat cleared after 10 messages. Starting a fresh thread.'),
          ),
        );
      }
    }
    final history = _messages
        .map((m) => {'role': m.role, 'content': m.text})
        .toList(growable: false);
    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _sending = true;
      _ctrl.clear();
    });
    try {
      final res = await _repo.askMentor(
        message: text,
        history: history,
        lessonId: widget.lessonId,
      );
      if (!mounted) return;
      final answer = (res['answer'] as String?)?.trim();
      setState(() {
        _messages.add(
          _ChatMessage(
            role: 'assistant',
            text: answer?.isNotEmpty == true ? answer! : 'No response from AI',
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
            'AI error: $e',
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_lessonMode ? 'AI · Lesson' : 'AI mentor'),
      ),
      body: OmuzPage.background(
        context: context,
        child: Column(
          children: [
            if (_lessonMode)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  border: Border(
                    bottom: BorderSide(color: cs.outline.withValues(alpha: 0.6)),
                  ),
                ),
                child: Text(
                  'I can explain this lesson and suggest courses from the catalog that match your goals.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  border: Border(
                    bottom: BorderSide(color: cs.outline.withValues(alpha: 0.6)),
                  ),
                ),
                child: Text(
                  'Ask about courses, promotions, or how Omuz works. Off-topic questions are out of scope.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _lessonMode
                              ? 'Ask anything about this lesson.'
                              : 'Try: what courses are available, current discounts, or how lessons and quizzes work.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: OmuzPage.padding,
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _bubble(_messages[i]),
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: _lessonMode
                              ? 'Question about this lesson…'
                              : 'Question about Omuz…',
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _sending ? null : _send,
                      child: _sending
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
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
      ),
    );
  }

  Widget _bubble(_ChatMessage m) {
    final isUser = m.role == 'user';
    final cs = Theme.of(context).colorScheme;
    final assistantStyle = MarkdownStyleSheet(
      p: TextStyle(color: cs.onSurface, height: 1.45, fontSize: 15),
      h1: TextStyle(
        color: cs.onSurface,
        fontWeight: FontWeight.w800,
        fontSize: 18,
        height: 1.25,
      ),
      h2: TextStyle(
        color: cs.onSurface,
        fontWeight: FontWeight.w700,
        fontSize: 17,
        height: 1.3,
      ),
      h3: TextStyle(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        height: 1.35,
      ),
      listBullet: TextStyle(color: cs.primary, height: 1.45),
      listIndent: 20,
      blockSpacing: 10,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outline.withValues(alpha: 0.35)),
        ),
      ),
      code: TextStyle(
        color: cs.onSurface,
        fontSize: 13,
        fontFamily: 'monospace',
        backgroundColor: cs.surfaceContainerHighest,
      ),
      codeblockDecoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
      ),
      a: TextStyle(color: cs.primary, decoration: TextDecoration.underline),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: isUser ? cs.primary : cs.surface,
          border: Border.all(
            color: isUser ? cs.primary : cs.outline.withValues(alpha: 0.8),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: isUser
            ? Text(
                m.text,
                style: TextStyle(color: cs.onPrimary, height: 1.4),
              )
            : MarkdownBody(
                data: m.text,
                shrinkWrap: true,
                selectable: true,
                styleSheet: assistantStyle,
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
