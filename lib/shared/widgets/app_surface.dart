import 'package:flutter/material.dart';

class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? shadowColor;
  final bool shadow;

  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.shadowColor,
    this.shadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: (shadowColor ?? Colors.black).withValues(alpha: 0.04),
                  offset: const Offset(0, 3),
                  blurRadius: 10,
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
        borderRadius: const BorderRadius.all(Radius.circular(5)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Cascadia Mono',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          height: 1,
          color: foregroundColor ?? scheme.onSecondary,
        ),
      ),
    );
  }
}

class AppSectionLabel extends StatelessWidget {
  final String label;
  const AppSectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: TextStyle(
      fontFamily: 'Cascadia Mono',
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.7,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
    ),
  );
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
            side: BorderSide(color: Theme.of(context).dividerColor),
            padding: EdgeInsets.zero,
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
        ),
      ),
    );
  }
}
