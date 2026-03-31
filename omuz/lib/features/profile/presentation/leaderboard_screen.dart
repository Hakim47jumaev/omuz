import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<ProfileProvider>();
    Future.microtask(() => prov.loadLeaderboard());
  }

  static int _maxRank(List<dynamic> list) {
    var m = 0;
    for (final e in list) {
      final r = (e as Map<String, dynamic>)['rank'] as int;
      if (r > m) m = r;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProfileProvider>();
    final maxRank = prov.leaderboard.isEmpty ? 0 : _maxRank(prov.leaderboard);

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: prov.leaderboardLoading && prov.leaderboard.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : prov.leaderboard.isEmpty
              ? const Center(child: Text('No students yet'))
              : RefreshIndicator(
                  onRefresh: () => prov.loadLeaderboard(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: prov.leaderboard.length,
                    itemBuilder: (context, index) {
                      final entry = prov.leaderboard[index] as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LeaderboardEntryCard(
                          entry: entry,
                          maxRank: maxRank,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _LeaderboardEntryCard extends StatelessWidget {
  const _LeaderboardEntryCard({
    required this.entry,
    required this.maxRank,
  });

  final Map<String, dynamic> entry;
  final int maxRank;

  /// 0 = last places (muted), 1 = rank 4 (strongest green among non-medal).
  static double _greenStrength(int rank, int maxRank) {
    if (rank <= 3 || maxRank <= 3) return 0.35;
    if (maxRank <= 4) return 1.0;
    final t = (maxRank - rank) / (maxRank - 4.0);
    return t.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final rank = entry['rank'] as int;
    final firstName = (entry['first_name'] as String? ?? '').trim();
    final lastName = (entry['last_name'] as String? ?? '').trim();
    final fullName = [firstName, lastName].where((e) => e.isNotEmpty).join(' ');
    final initialsSource = firstName.isNotEmpty ? firstName : (lastName.isNotEmpty ? lastName : '?');
    final avatarUrl = (entry['avatar_url'] as String?)?.trim() ?? '';
    final hasAvatar = avatarUrl.isNotEmpty;
    final userId = entry['user_id'] as int?;
    final level = entry['level'];
    final xp = entry['total_xp'];

    final medal = _MedalStyle.forRank(rank);
    final green = _greenStrength(rank, maxRank);

    final BorderRadius radius = BorderRadius.circular(18);
    final BoxDecoration decoration;
    final Color titleColor;
    final Color subtitleColor;
    final Color xpColor;
    final Color badgeFg;
    final Color? avatarBorder;

    if (medal != null) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: medal.gradientColors,
          stops: const [0.0, 0.45, 1.0],
        ),
        borderRadius: radius,
        border: Border.all(color: medal.borderColor, width: medal.borderWidth),
        boxShadow: [
          BoxShadow(
            color: medal.shadowColor,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      );
      titleColor = medal.onGradientPrimary;
      subtitleColor = medal.onGradientSecondary;
      xpColor = medal.onGradientPrimary;
      badgeFg = medal.badgeForeground;
      avatarBorder = medal.avatarRing;
    } else {
      final g = green;
      final top = Color.lerp(const Color(0xFFF3FAF5), const Color(0xFFC8E6C9), g)!;
      final bottom = Color.lerp(const Color(0xFFE8F5E9), const Color(0xFF81C784), g)!;
      final borderC = Color.lerp(const Color(0xFFC8E6C9), const Color(0xFF43A047), g)!;
      decoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ),
        borderRadius: radius,
        border: Border.all(color: borderC, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Color.lerp(Colors.green.withValues(alpha: 0.08), Colors.green.withValues(alpha: 0.22), g)!,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
      titleColor = const Color(0xFF1B2E1F);
      subtitleColor = const Color(0xFF2E4A32);
      xpColor = Color.lerp(const Color(0xFF2E7D32), const Color(0xFF1B5E20), g)!;
      badgeFg = Colors.white;
      avatarBorder = Color.lerp(const Color(0xFF66BB6A), const Color(0xFF2E7D32), g);
    }

    final avatarRadius = medal != null ? 26.0 : 22.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: userId == null ? null : () => context.push('/leaderboard/user/$userId'),
        borderRadius: radius,
        child: Ink(
          decoration: decoration,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: avatarBorder ?? Colors.white24, width: 2),
                        boxShadow: medal != null
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: medal != null ? Colors.white.withValues(alpha: 0.35) : null,
                        backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                        child: hasAvatar
                            ? null
                            : Text(
                                initialsSource[0].toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: medal != null ? 20 : 18,
                                  color: medal != null ? medal.onGradientPrimary : const Color(0xFF1B5E20),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -2,
                      child: _RankMedalBubble(
                        rank: rank,
                        medal: medal,
                        foreground: badgeFg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isEmpty ? 'Learner' : fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: titleColor,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Level $level',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: subtitleColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$xp',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: xpColor,
                            height: 1.0,
                          ),
                    ),
                    Text(
                      'XP',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: subtitleColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MedalStyle {
  const _MedalStyle({
    required this.gradientColors,
    required this.borderColor,
    required this.borderWidth,
    required this.shadowColor,
    required this.onGradientPrimary,
    required this.onGradientSecondary,
    required this.badgeForeground,
    required this.avatarRing,
  });

  final List<Color> gradientColors;
  final Color borderColor;
  final double borderWidth;
  final Color shadowColor;
  final Color onGradientPrimary;
  final Color onGradientSecondary;
  final Color badgeForeground;
  final Color avatarRing;

  static _MedalStyle? forRank(int rank) {
    switch (rank) {
      case 1:
        return const _MedalStyle(
          gradientColors: [
            Color(0xFFFFF8E1),
            Color(0xFFFFD54F),
            Color(0xFFFFA000),
          ],
          borderColor: Color(0xFFB8860B),
          borderWidth: 2.2,
          shadowColor: Color(0x66FFB300),
          onGradientPrimary: Color(0xFF3E2723),
          onGradientSecondary: Color(0xFF5D4037),
          badgeForeground: Color(0xFF3E2723),
          avatarRing: Color(0xFFFFECB3),
        );
      case 2:
        return const _MedalStyle(
          gradientColors: [
            Color(0xFFF5F5F5),
            Color(0xFFB0BEC5),
            Color(0xFF78909C),
          ],
          borderColor: Color(0xFF90A4AE),
          borderWidth: 2.0,
          shadowColor: Color(0x5590A4AE),
          onGradientPrimary: Color(0xFF263238),
          onGradientSecondary: Color(0xFF37474F),
          badgeForeground: Color(0xFF263238),
          avatarRing: Color(0xFFECEFF1),
        );
      case 3:
        return const _MedalStyle(
          gradientColors: [
            Color(0xFFFFE0B2),
            Color(0xFFCD7F32),
            Color(0xFF6D4C41),
          ],
          borderColor: Color(0xFF8D5524),
          borderWidth: 2.0,
          shadowColor: Color(0x66A1887F),
          onGradientPrimary: Color(0xFF1B0F0A),
          onGradientSecondary: Color(0xFF3E2723),
          badgeForeground: Color(0xFFFFF8E1),
          avatarRing: Color(0xFFFFCC80),
        );
      default:
        return null;
    }
  }
}

class _RankMedalBubble extends StatelessWidget {
  const _RankMedalBubble({
    required this.rank,
    required this.medal,
    required this.foreground,
  });

  final int rank;
  final _MedalStyle? medal;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final isMedal = medal != null;
    final label = rank <= 3 ? ['1', '2', '3'][rank - 1] : '$rank';

    return Container(
      width: isMedal ? 28 : 26,
      height: isMedal ? 28 : 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isMedal
            ? RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.15),
                ],
              )
            : null,
        color: isMedal ? null : Color.lerp(const Color(0xFF43A047), const Color(0xFF1B5E20), 0.35),
        border: Border.all(
          color: isMedal ? medal!.borderColor : Colors.white,
          width: isMedal ? 1.8 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: rank <= 3 ? 12 : 10,
          fontWeight: FontWeight.w900,
          color: foreground,
          height: 1,
        ),
      ),
    );
  }
}
