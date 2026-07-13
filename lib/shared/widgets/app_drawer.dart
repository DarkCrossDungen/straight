import 'package:flutter/material.dart';
import 'package:straight/shared/widgets/app_surface.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Drawer(
      width: 260,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSurface(
                shadow: false,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STRAIGHT',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LOCAL DICTATION',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _navItem(
                Icons.home_outlined,
                'Home',
                () => Navigator.pop(context),
              ),
              _navItem(Icons.settings_outlined, 'Settings', () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              }),
              _navItem(Icons.book_outlined, 'Dictionary', () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/dictionary');
              }),
              _navItem(Icons.history, 'History', () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/history');
              }),
              const Spacer(),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'LOCAL ONLY',
                  style: TextStyle(
                    fontFamily: 'Space Mono',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        leading: Icon(icon, size: 20),
        title: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Space Mono',
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 14),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        dense: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }
}
