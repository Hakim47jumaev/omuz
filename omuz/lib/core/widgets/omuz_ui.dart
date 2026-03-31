import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Glass panel: backdrop blur + light fill and border.
class OmuzGlass extends StatelessWidget {
  const OmuzGlass({
    super.key,
    required this.child,
    this.borderRadius = 14,
    this.blurSigma,
    this.padding,
  });

  final Widget child;
  final double borderRadius;
  final double? blurSigma;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final sigma = blurSigma ?? AppTheme.glassBlurSigma;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: AppTheme.glassFill,
            border: Border.all(color: AppTheme.glassBorder, width: 1),
          ),
          child: padding != null ? Padding(padding: padding!, child: child) : child,
        ),
      ),
    );
  }
}

/// Page scaffold: full-screen content above [OmuzAmbientShell] from [MaterialApp.builder].
class OmuzPage {
  OmuzPage._();

  static const EdgeInsets padding = EdgeInsets.fromLTRB(20, 12, 20, 28);

  static Widget background({
    required BuildContext context,
    required Widget child,
  }) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: child,
    );
  }
}

class OmuzSectionTitle extends StatelessWidget {
  final String text;
  const OmuzSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: cs.onSurface,
          ),
    );
  }
}
