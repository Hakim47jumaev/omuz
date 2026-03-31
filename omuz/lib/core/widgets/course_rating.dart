import 'package:flutter/material.dart';

/// Average rating and review count from API (rating_avg, rating_count).
class CourseRatingSummary extends StatelessWidget {
  const CourseRatingSummary({
    super.key,
    required this.course,
    this.compact = false,
  });

  final Map<String, dynamic> course;
  final bool compact;

  static double? parseAvg(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int parseCount(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final count = parseCount(course['rating_count']);
    final avg = parseAvg(course['rating_avg']);

    final iconSize = compact ? 14.0 : 16.0;
    final style = (compact ? textTheme.labelSmall : textTheme.bodySmall)?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    if (count <= 0 || avg == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_outline, size: iconSize, color: cs.onSurfaceVariant),
          SizedBox(width: compact ? 4 : 6),
          Text(
            'No ratings yet',
            style: style,
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: iconSize, color: Colors.amber.shade600),
        SizedBox(width: compact ? 3 : 4),
        Text(
          avg.toStringAsFixed(1),
          style: style?.copyWith(color: cs.onSurface),
        ),
        Text(
          ' · $count',
          style: style,
        ),
      ],
    );
  }
}

/// 1–5 star picker for the course screen.
class CourseStarPicker extends StatelessWidget {
  const CourseStarPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final int? value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = value ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final n = i + 1;
        final filled = n <= v;
        return IconButton(
          onPressed: enabled ? () => onChanged(n) : null,
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: filled ? Colors.amber.shade600 : cs.onSurfaceVariant,
            size: 32,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        );
      }),
    );
  }
}
