import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../providers/course_provider.dart';

class CourseDetailScreen extends StatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<CourseProvider>();
    Future.microtask(() => prov.load(widget.courseId));
  }

  bool _showPaywall(CourseProvider prov, Map<String, dynamic> sub) {
    return !prov.hasAccess && sub['status'] != 'free';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CourseProvider>();
    final course = prov.course;
    final sub = prov.subscription;
    final cs = Theme.of(context).colorScheme;

    final paywall = course != null && sub != null && _showPaywall(prov, sub);

    return Scaffold(
      appBar: AppBar(title: Text(course?['title'] ?? 'Курс')),
      body: prov.loading || course == null || sub == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (paywall) ...[
                  _buildPaywallDemoHeader(cs),
                  if ((course['preview_video_url'] as String?)?.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 8),
                    _PublicDemoVideo(
                      key: ValueKey(course['preview_video_url'] as String),
                      url: course['preview_video_url'] as String,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Полный доступ к урокам открывается после оплаты подписки.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  if ((course['preview_video_url'] as String?)?.isNotEmpty ==
                      true) ...[
                    Text(
                      'Знакомство с курсом',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _PublicDemoVideo(
                      key: ValueKey(course['preview_video_url'] as String),
                      url: course['preview_video_url'] as String,
                    ),
                    const SizedBox(height: 16),
                  ],
                ],

                if ((course['description'] as String).isNotEmpty) ...[
                  Text(course['description'] as String,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                ],

                if (paywall)
                  _buildPurchaseSection(prov, sub, cs)
                else ...[
                  if (sub['status'] == 'active')
                    _buildActiveSubBanner(sub, cs),
                  const SizedBox(height: 8),
                  Text('Модули',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._buildModules(course, prov, cs),
                ],
              ],
            ),
    );
  }

  Widget _buildPaywallDemoHeader(ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.primaryContainer.withAlpha(200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.play_circle_fill, color: cs.primary, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Демо-видео — доступно всем',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Посмотрите вводное видео, чтобы оценить курс перед покупкой.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onPrimaryContainer.withAlpha(220),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSubBanner(Map<String, dynamic> sub, ColorScheme cs) {
    final expiresAt = sub['expires_at'] as String? ?? '';
    String expiresLabel = '';
    if (expiresAt.isNotEmpty) {
      final dt = DateTime.tryParse(expiresAt);
      if (dt != null) {
        final days = dt.difference(DateTime.now()).inDays;
        expiresLabel = 'Осталось: $days дн.';
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text('Подписка активна',
              style: TextStyle(
                  color: Colors.green.shade700, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (expiresLabel.isNotEmpty)
            Text(expiresLabel,
                style: TextStyle(color: Colors.green.shade700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPurchaseSection(
      CourseProvider prov, Map<String, dynamic> sub, ColorScheme cs) {
    final subStatus = sub['status'] as String;
    final price = sub['price'] as String? ?? '0';
    final basePrice = sub['base_price'] as String? ?? price;
    final discountPercent = (sub['discount_percent'] as num?)?.toInt() ?? 0;
    final discountEndsAtRaw = sub['discount_ends_at'] as String?;
    final hasDiscount = discountPercent > 0 && basePrice != price;

    return Card(
      elevation: 0,
      color: cs.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              subStatus == 'expired' ? Icons.timer_off : Icons.lock_outline,
              size: 48,
              color: cs.onSecondaryContainer,
            ),
            const SizedBox(height: 12),
            Text(
              subStatus == 'expired'
                  ? 'Подписка истекла'
                  : 'Платный курс',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSecondaryContainer,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (hasDiscount) ...[
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    _money(basePrice),
                    style: TextStyle(
                      color: cs.onSecondaryContainer.withAlpha(180),
                      decoration: TextDecoration.lineThrough,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _money(price),
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withAlpha(35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '-$discountPercent%',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if ((discountEndsAtRaw ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Скидка активна до: ${_fmtDateTime(discountEndsAtRaw!)}',
                  style: TextStyle(
                    color: cs.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],
            if (subStatus == 'none') ...[
              FilledButton(
                onPressed: () => _handlePurchase(prov, price),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Купить на 1 месяц — ${_money(price)}'),
              ),
            ],
            if (subStatus == 'expired') ...[
              Text('Продлить доступ:',
                  style: TextStyle(color: cs.onSecondaryContainer)),
              const SizedBox(height: 12),
              ...(sub['renewal_options'] as List<dynamic>).map((opt) {
                final days = opt['days'] as int;
                final optPrice = opt['price'] as String;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () => _handleRenew(prov, days),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                        '$days ${days == 1 ? "день" : "дней"} — ${_money(optPrice)}'),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Оплата не прошла'),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmPurchase(String price) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение оплаты'),
        content: Text(
          'С вашего счета спишется ${_money(price)} за доступ к курсу. Продолжить?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _handlePurchase(CourseProvider prov, String price) async {
    final confirmed = await _confirmPurchase(price);
    if (!confirmed) return;
    final ok = await prov.purchase(widget.courseId);
    if (!mounted) return;
    if (ok) {
      await prov.load(widget.courseId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Курс успешно оплачен!')),
      );
    } else {
      _showErrorDialog(prov.lastError ?? 'Не удалось оформить покупку.');
    }
  }

  Future<void> _handleRenew(CourseProvider prov, int days) async {
    final ok = await prov.renew(widget.courseId, days);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Подписка продлена на $days дн.!')),
      );
    } else {
      _showErrorDialog(prov.lastError ?? 'Не удалось продлить подписку.');
    }
  }

  String _fmtDateTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.$y $hh:$mm';
  }

  String _money(String value) => '$value TJS';

  List<Widget> _buildModules(
      Map<String, dynamic> course, CourseProvider prov, ColorScheme cs) {
    return (course['modules'] as List<dynamic>).map((module) {
      final lessons = module['lessons'] as List<dynamic>;
      final completedCount = lessons
          .where((l) => prov.completedLessonIds.contains(l['id'] as int))
          .length;
      final total = lessons.length;

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: completedCount == total && total > 0
                ? Colors.green
                : cs.primaryContainer,
            child: Icon(
              completedCount == total && total > 0
                  ? Icons.check
                  : Icons.folder_outlined,
              color: completedCount == total && total > 0
                  ? Colors.white
                  : cs.onPrimaryContainer,
            ),
          ),
          title: Text(module['title'] as String),
          subtitle: Text('$completedCount / $total уроков завершено'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(
            '/course/${widget.courseId}/module/${module['id']}',
          ),
        ),
      );
    }).toList();
  }
}

/// Плеер с корректным dispose при смене URL / уходе со экрана.
class _PublicDemoVideo extends StatefulWidget {
  final String url;

  const _PublicDemoVideo({super.key, required this.url});

  @override
  State<_PublicDemoVideo> createState() => _PublicDemoVideoState();
}

class _PublicDemoVideoState extends State<_PublicDemoVideo> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant _PublicDemoVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _controller = null;
      _init();
      setState(() {});
    }
  }

  void _init() {
    final id = YoutubePlayer.convertUrlToId(widget.url);
    if (id == null) return;
    _controller = YoutubePlayerController(
      initialVideoId: id,
      flags: const YoutubePlayerFlags(autoPlay: false),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = YoutubePlayer.convertUrlToId(widget.url);
    if (id == null || _controller == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Некорректная ссылка на видео. Укажите YouTube URL в админке.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: true,
      ),
    );
  }
}
