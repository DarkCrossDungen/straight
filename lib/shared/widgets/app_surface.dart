import 'package:flutter/material.dart';
import 'package:straight/shared/theme/colors.dart';

class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? shadowColor;
  final bool shadow;

  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.shadowColor,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        border: Border.all(color: scheme.onSurface, width: 1),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: shadowColor ?? scheme.onSurface,
                  offset: const Offset(4, 4),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class AppBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? foregroundColor;

  const AppBadge({
    super.key,
    required this.label,
    this.color,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color ?? scheme.secondary,
        border: Border.all(color: scheme.onSurface, width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Space Mono',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
          letterSpacing: 0,
          color: foregroundColor ?? AppColors.lightFg,
        ),
      ),
    );
  }
}

class AppSectionLabel extends StatelessWidget {
  final String label;

  const AppSectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Space Mono',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.68),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? foregroundColor;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          style: IconButton.styleFrom(
            backgroundColor: color ?? scheme.surface,
            foregroundColor: foregroundColor ?? scheme.onSurface,
            disabledBackgroundColor: scheme.surface.withValues(alpha: 0.5),
            shape: const RoundedRectangleBorder(),
            side: BorderSide(color: scheme.onSurface, width: 1),
            padding: EdgeInsets.zero,
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
        ),
      ),
    );
  }
}
