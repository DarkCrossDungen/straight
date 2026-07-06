import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Drawer(
      width: 260,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STRAIGHT',
                      style: TextStyle(
                        fontFamily: 'SF Mono',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'offline dictation',
                      style: TextStyle(
                        fontFamily: 'SF Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface.withValues(alpha: 0.45),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _navItem(Icons.home_outlined, 'Home', () => Navigator.pop(context)),
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
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'local only',
                  style: TextStyle(
                    fontFamily: 'SF Mono',
                    fontSize: 10,
                    color: colors.onSurface.withValues(alpha: 0.3),
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
          label,
          style: const TextStyle(fontFamily: 'SF Mono', fontSize: 13, fontWeight: FontWeight.w500),
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
