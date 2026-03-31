import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/youtube_id.dart';
import '../../../core/widgets/course_rating.dart';
import '../../../core/widgets/omuz_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/course_provider.dart';
import 'course_preview_player_screen.dart';

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
    final isActiveSub = sub != null && sub['status'] == 'active';
    final isStaff = context.watch<AuthProvider>().isStaff;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(course?['title'] ?? 'Course')),
      body: prov.loading || course == null || sub == null
          ? OmuzPage.background(
              context: context,
              child: const Center(child: CircularProgressIndicator()),
            )
          : OmuzPage.background(
              context: context,
              child: ListView(
                padding: OmuzPage.padding,
                children: [
                if (paywall) ...[
                  _buildPreviewVideoBanner(cs),
                  if ((course['preview_video_url'] as String?)?.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 8),
                    _IntroVideoCard(
                      key: ValueKey(course['preview_video_url'] as String),
                      url: course['preview_video_url'] as String,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Full lesson access unlocks after you subscribe.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  if ((course['preview_video_url'] as String?)?.isNotEmpty ==
                      true) ...[
                    Text(
                      'Course introduction',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _IntroVideoCard(
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

                _buildCourseRatingSection(
                  context,
                  course,
                  prov,
                  isStaff,
                  paywall: paywall,
                ),
                const SizedBox(height: 16),

                if (paywall)
                  _buildPurchaseSection(prov, sub, cs)
                else ...[
                  if (isActiveSub)
                    _buildActiveSubBanner(sub, cs),
                  if (isActiveSub) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _handleContinue(course, prov),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Continue'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildUserCourseDataCard(course, prov, sub),
                  ],
                  if (!isActiveSub) ...[
                    const SizedBox(height: 8),
                    Text('Modules',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._buildModules(course, prov, cs),
                  ],
                ],
              ],
            ),
            ),
    );
  }

  Widget _buildCourseRatingSection(
    BuildContext context,
    Map<String, dynamic> course,
    CourseProvider prov,
    bool isStaff, {
    required bool paywall,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isFree = course['is_free'] == true;
    final canRate = isFree || !paywall;
    int? myRating;
    final mr = course['my_rating'];
    if (mr is int) {
      myRating = mr;
    } else if (mr is num) {
      myRating = mr.toInt();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rating',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        CourseRatingSummary(course: course),
        if (!isStaff) ...[
          const SizedBox(height: 14),
          if (!canRate) ...[
            Text(
              'Subscribe to rate this course.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ] else ...[
            Text(
              'Your rating (1–5)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            CourseStarPicker(
              value: myRating,
              enabled: !prov.reviewSubmitting,
              onChanged: (s) async {
                final ok = await prov.submitReview(s);
                if (!context.mounted) return;
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Thanks! You rated this course $s out of 5'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          prov.reviewError ?? 'Could not save your rating'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildPreviewVideoBanner(ColorScheme cs) {
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
                    'Free preview video',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Watch the intro to decide before you subscribe.',
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
        expiresLabel = '$days days left';
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppTheme.success, size: 20),
          const SizedBox(width: 8),
          Text('Subscription active',
              style: TextStyle(
                  color: AppTheme.success, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (expiresLabel.isNotEmpty)
            Text(expiresLabel,
                style: TextStyle(color: AppTheme.success, fontSize: 13)),
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
                  ? 'Subscription expired'
                  : 'Paid course',
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
                      color: cs.onSecondaryContainer,
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
                        color: cs.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Discounted price: ${_money(price)}',
                style: TextStyle(
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if ((discountEndsAtRaw ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Discount ends: ${_fmtDateTime(discountEndsAtRaw!)}',
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
                child: Text('Buy 1 month — ${_money(price)}'),
              ),
            ],
            if (subStatus == 'expired') ...[
              Text('Extend access:',
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
                      foregroundColor: cs.onSecondaryContainer,
                      side: BorderSide(color: cs.onSecondaryContainer.withAlpha(180)),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                        '$days ${days == 1 ? "day" : "days"} — ${_money(optPrice)}'),
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
        title: const Text('Payment failed'),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmPurchase(String price) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm purchase'),
        content: Text(
          '${_money(price)} will be charged from your wallet for course access. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
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
        const SnackBar(content: Text('Course purchased successfully')),
      );
    } else {
      _showErrorDialog(prov.lastError ?? 'Purchase could not be completed.');
    }
  }

  Future<void> _handleRenew(CourseProvider prov, int days) async {
    final ok = await prov.renew(widget.courseId, days);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Subscription extended by $days day(s)')),
      );
    } else {
      _showErrorDialog(prov.lastError ?? 'Could not renew subscription.');
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

  Widget _buildUserCourseDataCard(
    Map<String, dynamic> course,
    CourseProvider prov,
    Map<String, dynamic> sub,
  ) {
    final modules = (course['modules'] as List<dynamic>?) ?? const [];
    final allLessonIds = <int>[];
    for (final module in modules) {
      final lessons = (module['lessons'] as List<dynamic>?) ?? const [];
      for (final lesson in lessons) {
        allLessonIds.add(lesson['id'] as int);
      }
    }

    final totalLessons = allLessonIds.length;
    final completedLessons = allLessonIds
        .where((id) => prov.completedLessonIds.contains(id))
        .length;
    final progress = totalLessons == 0 ? 0.0 : completedLessons / totalLessons;
    final progressPercent = (progress * 100).round();
    final expiresAt = sub['expires_at'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your progress',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            Text('Lessons completed: $completedLessons of $totalLessons'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 6),
            Text('$progressPercent% complete'),
            if ((expiresAt ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Renews until: ${_fmtDateTime(expiresAt!)}'),
            ],
          ],
        ),
      ),
    );
  }

  void _handleContinue(Map<String, dynamic> course, CourseProvider prov) {
    final nextModuleId = _findNextModuleId(course, prov);
    final modules = (course['modules'] as List<dynamic>?) ?? const [];
    if (nextModuleId != null) {
      context.push('/course/${widget.courseId}/module/$nextModuleId');
      return;
    }
    if (modules.isNotEmpty) {
      context.push('/course/${widget.courseId}/module/${modules.first['id']}');
    }
  }

  int? _findNextModuleId(Map<String, dynamic> course, CourseProvider prov) {
    final modules = (course['modules'] as List<dynamic>?) ?? const [];
    for (final module in modules) {
      final lessons = (module['lessons'] as List<dynamic>?) ?? const [];
      if (lessons.isEmpty) continue;
      for (final lesson in lessons) {
        final lessonId = lesson['id'] as int;
        if (!prov.completedLessonIds.contains(lessonId)) {
          return module['id'] as int;
        }
      }
    }
    return null;
  }

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
                ? AppTheme.success
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
          subtitle: Text('$completedCount / $total lessons completed'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(
            '/course/${widget.courseId}/module/${module['id']}',
          ),
        ),
      );
    }).toList();
  }
}

/// YouTube thumbnail + dialog player (WebView is not inside scrollable lists).
class _IntroVideoCard extends StatelessWidget {
  const _IntroVideoCard({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final id = resolveYoutubeVideoId(url);
    final cs = Theme.of(context).colorScheme;
    if (id == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Invalid YouTube URL. Update the link in the admin panel.',
            style: TextStyle(color: cs.error),
          ),
        ),
      );
    }
    final thumb = 'https://img.youtube.com/vi/$id/hqdefault.jpg';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (ctx) => CoursePreviewPlayerScreen(
                url: url,
                title: 'Course introduction',
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  thumb,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: cs.surfaceContainerHighest,
                    child: Icon(Icons.play_circle_outline,
                        size: 64, color: cs.onSurfaceVariant),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),
              Icon(Icons.play_circle_filled,
                  size: 56, color: Colors.white.withValues(alpha: 0.95)),
              Positioned(
                bottom: 10,
                left: 12,
                right: 12,
                child: Text(
                  'Watch intro video',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(blurRadius: 10, color: Colors.black87),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
