import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/course_rating.dart';
import '../../../core/widgets/omuz_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/home_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _lastShownStreakReason;
  int _topTab = 0;

  @override
  void initState() {
    super.initState();
    final prov = context.read<HomeProvider>();
    Future.microtask(() async {
      await prov.load();
      if (mounted) {
        await context.read<ProfileProvider>().loadProfile();
      }
    });
  }

  List<dynamic> _partitionCategories(HomeProvider home, bool firstHalf) {
    final list = [...home.categories];
    list.sort((a, b) {
      final na = (a['name'] as String?) ?? '';
      final nb = (b['name'] as String?) ?? '';
      return na.compareTo(nb);
    });
    if (list.isEmpty) return [];
    final mid = (list.length / 2).ceil();
    if (firstHalf) return list.sublist(0, mid);
    return list.sublist(mid);
  }

  Future<void> _setTopTab(int index, HomeProvider home) async {
    setState(() => _topTab = index);
    if (index == 0) {
      await home.filterByCategory(null);
    } else {
      await home.filterByCategory(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final isStaff = context.watch<AuthProvider>().isStaff;
    final profile = context.watch<ProfileProvider>().profile;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (!isStaff) {
      _maybeShowStreakSnack(profile);
    }

    final totalLessons = home.courses.fold<int>(
      0,
      (s, c) => s + ((c['lessons_count'] as int?) ?? 0),
    );
    final totalCourses = home.courses.length;
    final topicsCount = home.categories.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: home.loading && home.courses.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                color: AppTheme.accentPink,
                onRefresh: () => home.load(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    if (home.loadError != null) ...[
                      _buildLoadErrorBanner(context, home, cs),
                      const SizedBox(height: 16),
                    ],
                    _buildStatsRow(
                      context,
                      stats: [
                        ('$totalLessons', 'video lessons'),
                        ('$totalCourses', 'courses'),
                        ('$topicsCount', 'topics'),
                      ],
                    ),
                    const SizedBox(height: 28),
                    if (!isStaff) ...[
                      _buildStreakStrip(profile, cs, textTheme),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      'Course catalog',
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTopTabs(context, home, cs, textTheme),
                    if (_topTab != 0) ...[
                      const SizedBox(height: 14),
                      _buildCategoryChips(
                        home,
                        cs,
                        _topTab == 1
                            ? _partitionCategories(home, true)
                            : _partitionCategories(home, false),
                      ),
                    ],
                    const SizedBox(height: 22),
                    _buildSectionLabel('Popular', cs, textTheme),
                    const SizedBox(height: 12),
                    _buildHorizontalCoursesRow(home.popularCourses, cs, textTheme,
                        emptyText: 'No popular courses yet'),
                    const SizedBox(height: 22),
                    if (!isStaff) ...[
                      _buildSectionLabel('For you', cs, textTheme),
                      const SizedBox(height: 12),
                      _buildHorizontalCoursesRow(home.recommendations, cs, textTheme,
                          emptyText: 'No recommendations yet — explore categories above'),
                      const SizedBox(height: 22),
                      _buildSectionLabel('Continue', cs, textTheme),
                      const SizedBox(height: 12),
                      _buildHorizontalCoursesRow(home.continueLearning, cs, textTheme,
                          emptyText: 'Start any lesson to see progress here'),
                      const SizedBox(height: 22),
                      _buildSectionLabel('Promotions', cs, textTheme),
                      const SizedBox(height: 10),
                      _buildPromotions(home.promotions, cs, textTheme),
                      const SizedBox(height: 22),
                    ] else ...[
                      _buildSectionLabel('Promotions', cs, textTheme),
                      const SizedBox(height: 10),
                      _buildPromotions(home.promotions, cs, textTheme),
                      const SizedBox(height: 22),
                    ],
                    _buildSectionLabel('Catalog', cs, textTheme),
                    const SizedBox(height: 12),
                    if (home.courses.isEmpty)
                      _emptyCard(cs, textTheme, 'No courses yet')
                    else ...[
                      for (var i = 0; i < home.courses.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _courseRowCard(home.courses[i], cs, textTheme),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context, {
    required List<(String, String)> stats,
  }) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _outlineCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      stats[i].$1,
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stats[i].$2,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTopTabs(
    BuildContext context,
    HomeProvider home,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    const labels = ['All', 'Subjects', 'Careers'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: _TopTabItem(
              label: labels[i],
              selected: _topTab == i,
              onTap: () => _setTopTab(i, home),
              cs: cs,
              textTheme: textTheme,
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryChips(HomeProvider home, ColorScheme cs, List<dynamic> cats) {
    if (cats.isEmpty) {
      return Text(
        'No categories in this section',
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
      );
    }
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = cats[index] as Map<String, dynamic>;
          final id = cat['id'] as int;
          final name = cat['name'] as String? ?? '';
          final selected = home.selectedCategoryId == id;
          return FilterChip(
            label: Text(
              name,
              style: TextStyle(
                color: selected ? AppTheme.accentPink : cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            selected: selected,
            onSelected: (_) => home.filterByCategory(id),
            selectedColor: cs.primaryContainer.withValues(alpha: 0.6),
            backgroundColor: cs.surfaceContainerHighest,
            checkmarkColor: AppTheme.accentPink,
            showCheckmark: false,
            side: BorderSide(
              color: selected ? AppTheme.accentPink.withValues(alpha: 0.5) : cs.outline,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalCoursesRow(
    List<dynamic> courses,
    ColorScheme cs,
    TextTheme textTheme, {
    required String emptyText,
  }) {
    if (courses.isEmpty) return _emptyCard(cs, textTheme, emptyText);
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: courses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: 308,
          child: Align(
            alignment: Alignment.center,
            child: _courseRowCard(courses[i], cs, textTheme, compact: true),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, ColorScheme cs, TextTheme textTheme) {
    return Text(
      title,
      style: textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: cs.onSurfaceVariant,
      ),
    );
  }

  Widget _buildLoadErrorBanner(
    BuildContext context,
    HomeProvider home,
    ColorScheme cs,
  ) {
    return OmuzGlass(
      borderRadius: 14,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_off_rounded, color: cs.error, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                home.loadError!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface,
                    ),
              ),
            ),
            TextButton(
              onPressed: home.loading ? null : () => home.load(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakStrip(
    Map<String, dynamic>? profile,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    if (profile == null) return const SizedBox.shrink();
    final xp = profile['xp'] as Map<String, dynamic>?;
    if (xp == null) return const SizedBox.shrink();

    final current = (xp['current_streak'] as int?) ?? 0;
    final best = (xp['best_streak'] as int?) ?? 0;
    final lastDate = (xp['last_activity_date'] as String?) ?? '';
    final isActive = current > 0;

    return _outlineCard(
      gradient: isActive
          ? LinearGradient(
              colors: [
                AppTheme.gradientEnd.withValues(alpha: 0.42),
                AppTheme.gradientStart.withValues(alpha: 0.28),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily streak: $current day${current == 1 ? '' : 's'}',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Best: $best days${lastDate.isNotEmpty ? ' · last: $lastDate' : ''}',
                    style: textTheme.bodySmall?.copyWith(
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.85)
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.15)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.outline),
              ),
              child: Text(
                '+5 XP/day',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isActive ? Colors.white : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotions(
    Map<String, dynamic> promotions,
    ColorScheme cs,
    TextTheme textTheme,
  ) {
    final active = promotions['is_active'] == true;
    if (!active) return _emptyCard(cs, textTheme, 'No active promotions right now');

    final name = (promotions['name'] as String?) ?? 'Promotion';
    final percent = (promotions['percent'] as int?) ?? 0;
    final promoCourses = (promotions['courses'] as List<dynamic>?) ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppTheme.gradientStart.withValues(alpha: 0.88),
                    AppTheme.gradientEnd.withValues(alpha: 0.9),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Text(
                '$name · −$percent%',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (promoCourses.isEmpty)
          _emptyCard(cs, textTheme, 'Promotion is active, courses will appear soon')
        else
          ...promoCourses.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _promotionCard(c, cs, textTheme),
              )),
      ],
    );
  }

  Widget _promotionCard(dynamic course, ColorScheme cs, TextTheme textTheme) {
    final basePrice = course['base_price']?.toString() ?? '0';
    final finalPrice = course['final_price']?.toString() ?? basePrice;
    final discountPercent = course['discount_percent']?.toString() ?? '0';
    final courseMap = Map<String, dynamic>.from(course as Map);

    return _outlineCard(
      child: ListTile(
        onTap: () => context.push('/course/${course['id']}'),
        title: Text(
          course['title'] ?? '',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$discountPercent% off',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            CourseRatingSummary(course: courseMap, compact: true),
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$basePrice TJS',
              style: TextStyle(
                decoration: TextDecoration.lineThrough,
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
            Text(
              '$finalPrice TJS',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.accentPink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _maybeShowStreakSnack(Map<String, dynamic>? profile) {
    if (profile == null) return;
    final history = (profile['xp_history'] as List<dynamic>?) ?? const [];
    if (history.isEmpty) return;
    final latest = history.first as Map<String, dynamic>;
    final reason = (latest['reason'] as String?) ?? '';
    final amount = latest['amount'];
    if (!reason.startsWith('Daily streak bonus')) return;
    if (_lastShownStreakReason == reason) return;

    _lastShownStreakReason = reason;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Streak +1, +$amount XP'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  Widget _emptyCard(ColorScheme cs, TextTheme textTheme, String text) {
    return _outlineCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Text(
          text,
          style: textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _outlineCard({
    required Widget child,
    Gradient? gradient,
  }) {
    final glass = OmuzGlass(
      borderRadius: 14,
      child: child,
    );
    if (gradient == null) {
      return SizedBox(width: double.infinity, child: glass);
    }
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            glass,
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: gradient),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _courseSubtitle(Map<String, dynamic> course) {
    final cat = course['category'];
    if (cat is Map<String, dynamic>) {
      return (cat['name'] as String?) ?? '';
    }
    return '';
  }

  Widget _courseRowCard(
    dynamic course,
    ColorScheme cs,
    TextTheme textTheme, {
    bool compact = false,
  }) {
    final map = course as Map<String, dynamic>;
    final id = map['id'];
    final title = map['title']?.toString() ?? '';
    final imageUrl = map['image']?.toString() ?? '';
    final subtitle = _courseSubtitle(map);
    final lessons = (map['lessons_count'] as int?) ?? 0;
    final subLine = subtitle.isEmpty ? '$lessons lessons' : '$subtitle · $lessons lessons';

    final imageSize = compact ? 88.0 : 100.0;
    final imageRadius = compact ? 12.0 : 14.0;
    final placeholderIcon = (imageSize * 0.36).clamp(26.0, 36.0);

    return OmuzGlass(
      borderRadius: 14,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/course/$id'),
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white24,
          highlightColor: AppTheme.accentPink.withValues(alpha: 0.12),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, compact ? 7 : 8, 12, compact ? 7 : 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(imageRadius),
                  child: SizedBox(
                    width: imageSize,
                    height: imageSize,
                    child: imageUrl.isEmpty
                        ? ColoredBox(
                            color: cs.surfaceContainerHighest,
                            child: Icon(Icons.school, color: cs.onSurfaceVariant, size: placeholderIcon),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: cs.surfaceContainerHighest,
                              child: Icon(Icons.school, color: cs.onSurfaceVariant, size: placeholderIcon),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          height: compact ? 1.15 : 1.2,
                          letterSpacing: -0.2,
                          fontSize: compact ? 14 : null,
                        ),
                      ),
                      SizedBox(height: compact ? 3 : 4),
                      Text(
                        subLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: compact ? 12 : null,
                          height: compact ? 1.1 : 1.15,
                        ),
                      ),
                      SizedBox(height: compact ? 5 : 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: CourseRatingSummary(course: map, compact: true),
                          ),
                          const SizedBox(width: 10),
                          _GradientCta(
                            label: 'Open',
                            compact: true,
                            onTap: () => context.push('/course/$id'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopTabItem extends StatelessWidget {
  const _TopTabItem({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
    required this.textTheme,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.accentPink : cs.onSurface,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: selected ? AppTheme.accentPink : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientCta extends StatelessWidget {
  const _GradientCta({
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppTheme.ctaGradient,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gradientEnd.withValues(alpha: compact ? 0.25 : 0.35),
                blurRadius: compact ? 8 : 12,
                offset: Offset(0, compact ? 2 : 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 22,
              vertical: compact ? 6 : 10,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: compact ? 12.5 : 14,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
