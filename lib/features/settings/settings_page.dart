import 'package:flutter/material.dart';
import 'package:straight/core/storage/settings_store.dart';
import 'package:straight/features/settings/hotkey_capture_tile.dart';
import 'package:straight/features/settings/model_selector.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDark = true;
  bool _startOnBoot = false;
  bool _pushToTalk = false;

  @override
  void initState() {
    super.initState();
    _isDark = SettingsStore.getThemeMode() == 'dark';
    _startOnBoot = SettingsStore.getStartOnBoot();
    _pushToTalk = SettingsStore.getPushToTalk();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummary(colors),
          const SizedBox(height: 20),
          _sectionHeader('SPEECH'),
          const SizedBox(height: 8),
          const ModelSelector(),
          const SizedBox(height: 12),
          const HotkeyCaptureTile(),
          const SizedBox(height: 20),
          _sectionHeader('BEHAVIOR'),
          const SizedBox(height: 8),
          _settingRow(
            icon: _isDark ? Icons.dark_mode : Icons.light_mode,
            title: 'Theme',
            subtitle: 'Keep the interface dark or switch to light',
            trailing: Switch(
              value: _isDark,
              onChanged: (value) async {
                setState(() => _isDark = value);
                await SettingsStore.setThemeMode(value ? 'dark' : 'light');
              },
            ),
          ),
          const Divider(height: 1),
          _settingRow(
            icon: Icons.power_settings_new,
            title: 'Start on boot',
            subtitle: 'Open Straight when the computer starts',
            trailing: Switch(
              value: _startOnBoot,
              onChanged: (value) async {
                setState(() => _startOnBoot = value);
                await SettingsStore.setStartOnBoot(value);
              },
            ),
          ),
          const Divider(height: 1),
          _settingRow(
            icon: Icons.keyboard_voice,
            title: 'Push to talk',
            subtitle: 'Hold the hotkey instead of toggle dictation',
            trailing: Switch(
              value: _pushToTalk,
              onChanged: (value) async {
                setState(() => _pushToTalk = value);
                await SettingsStore.setPushToTalk(value);
              },
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeader('DATA'),
          const SizedBox(height: 8),
          _navRow(
            icon: Icons.book_outlined,
            title: 'Dictionary',
            subtitle: 'Stored replacements and custom terms',
            onTap: () => Navigator.pushNamed(context, '/dictionary'),
          ),
          const Divider(height: 1),
          _navRow(
            icon: Icons.history,
            title: 'History',
            subtitle: 'Saved dictation history',
            onTap: () => Navigator.pushNamed(context, '/history'),
          ),
          const SizedBox(height: 20),
          _sectionHeader('ABOUT'),
          const SizedBox(height: 8),
          _settingRow(
            icon: Icons.lock_outline,
            title: 'Offline by design',
            subtitle: 'No account, no cloud, no sync',
            trailing: Text(
              'LOCAL',
              style: TextStyle(
                fontFamily: 'SF Mono',
                fontSize: 11,
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colors.onSurface, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TUNE THE VOICE PIPELINE',
            style: TextStyle(
              fontFamily: 'SF Mono',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: colors.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Speech model, hotkey, and cleanup settings live here. Keep it light, local, and predictable.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: colors.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    final mutedFg = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'SF Mono',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: mutedFg,
        letterSpacing: 1.3,
      ),
    );
  }

  Widget _settingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Icon(icon, size: 20),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }

  Widget _navRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Icon(icon, size: 20),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
}
