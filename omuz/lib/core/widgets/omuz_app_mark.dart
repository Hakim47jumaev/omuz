import 'package:flutter/material.dart';

/// Same mark as the home AppBar: circle + [Icons.auto_graph_rounded].
class OmuzMark extends StatelessWidget {
  const OmuzMark({super.key, this.size = 44});

  /// Square box side length (circle diameter).
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconSize = size * (26 / 44);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surface,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.auto_graph_rounded,
        size: iconSize,
        color: cs.primary,
      ),
    );
  }
}
