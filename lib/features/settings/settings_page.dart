import 'package:flutter/material.dart';
import 'package:straight/core/storage/settings_store.dart';
import 'package:straight/core/startup/startup_service.dart';
import 'package:straight/features/bubble/desktop_bubble_service.dart';
import 'package:straight/features/settings/hotkey_capture_tile.dart';
import 'package:straight/features/settings/model_selector.dart';
import 'package:straight/shared/theme/colors.dart';
import 'package:straight/shared/widgets/app_surface.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDark = true;
  bool _startOnBoot = false;
  bool _pushToTalk = false;
  bool _desktopBubble = true;

  @override
  void initState() {
    super.initState();
    _isDark = SettingsStore.getThemeMode() == 'dark';
    _startOnBoot = SettingsStore.getStartOnBoot();
    _pushToTalk = SettingsStore.getPushToTalk();
    _desktopBubble = SettingsStore.getDesktopBubbleEnabled();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
        actions: [
          IconButton(
            tooltip: 'Close settings',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final content = wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _speechPanel(scheme)),
                      const SizedBox(width: 16),
                      Expanded(child: _behaviorPanel(scheme)),
                    ],
                  )
                : Column(
                    children: [
                      _speechPanel(scheme),
                      const SizedBox(height: 16),
                      _behaviorPanel(scheme),
                    ],
                  );
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [_header(scheme), const SizedBox(height: 16), content],
            );
          },
        ),
      ),
    );
  }

  Widget _header(ColorScheme scheme) {
    return Row(
      children: [
        AppBadge(label: 'Local'),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Speech model, hotkey, launch, and cleanup controls.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface.withValues(alpha: 0.76),
            ),
          ),
        ),
      ],
    );
  }

  Widget _speechPanel(ColorScheme scheme) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionLabel('Speech'),
          const SizedBox(height: 12),
          const ModelSelector(),
          const Divider(),
          const HotkeyCaptureTile(),
          const SizedBox(height: 16),
          _linkRow(
            Icons.spellcheck,
            'Dictionary',
            'Words and replacements',
            () {
              Navigator.pushNamed(context, '/dictionary');
            },
          ),
          const Divider(),
          _linkRow(Icons.schedule, 'History', 'Recent dictation log', () {
            Navigator.pushNamed(context, '/history');
          }),
        ],
      ),
    );
  }

  Widget _behaviorPanel(ColorScheme scheme) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionLabel('Behavior'),
          const SizedBox(height: 12),
          _switchRow(
            icon: _isDark ? Icons.dark_mode : Icons.light_mode,
            title: 'Dark mode',
            subtitle: 'Use the black command surface',
            value: _isDark,
            onChanged: (value) async {
              setState(() => _isDark = value);
              await SettingsStore.setThemeMode(value ? 'dark' : 'light');
            },
          ),
          const Divider(),
          _switchRow(
            icon: Icons.power_settings_new,
            title: 'Start on boot',
            subtitle: 'Open with Windows',
            value: _startOnBoot,
            onChanged: (value) async {
              setState(() => _startOnBoot = value);
              await SettingsStore.setStartOnBoot(value);
              await StartupService.setEnabled(value);
            },
          ),
          const Divider(),
          _switchRow(
            icon: Icons.graphic_eq_rounded,
            title: 'Desktop bubble',
            subtitle: 'Keep a small dictation control over other apps',
            value: _desktopBubble,
            onChanged: (value) async {
              setState(() => _desktopBubble = value);
              await DesktopBubbleService.instance.setEnabled(value);
            },
          ),
          const Divider(),
          _switchRow(
            icon: Icons.keyboard_voice,
            title: 'Push to talk',
            subtitle: 'Hold the hotkey to record',
            value: _pushToTalk,
            onChanged: (value) async {
              setState(() => _pushToTalk = value);
              await SettingsStore.setPushToTalk(value);
            },
          ),
          const SizedBox(height: 16),
          AppSurface(
            padding: const EdgeInsets.all(12),
            color: scheme.secondary,
            shadow: false,
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  color: AppColors.lightFg,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No account. No cloud sync. Models run on this machine.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.lightFg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  Widget _linkRow(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
}
