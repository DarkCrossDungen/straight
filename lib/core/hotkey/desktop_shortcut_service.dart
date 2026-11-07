import 'dart:io';

/// The desktop's own keyboard-shortcut registry.
///
/// Wayland refuses global key grabs from applications, so on Linux the
/// shortcut is registered with the desktop instead and the desktop runs
/// `straight --toggle`, which reaches the app over its loopback control port.
class DesktopShortcutService {
  static const _mediaKeysSchema =
      'org.gnome.settings-daemon.plugins.media-keys';
  static const _customKeybindingsKey = 'custom-keybindings';
  static const _slotSchema =
      'org.gnome.settings-daemon.plugins.media-keys.custom-keybinding';
  static const _slotPathPrefix =
      '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom';
  static const _slotCount = 64;
  static const entryName = 'Straight dictation';

  static bool? _supported;

  /// Whether this desktop keeps its shortcuts in a schema we can write.
  /// KDE and XFCE store them elsewhere, so the app falls back to opening
  /// the system settings page with instructions.
  static Future<bool> isSupported() async {
    final cached = _supported;
    if (cached != null) return cached;
    final result = await Process.run('gsettings', [
      'list-keys',
      _mediaKeysSchema,
    ]);
    return _supported = result.exitCode == 0;
  }

  static String get toggleCommand =>
      "'${Platform.resolvedExecutable}' --toggle";

  /// The keybinding already pointing at Straight, e.g. `<Alt>space`.
  static Future<String?> registeredBinding() async {
    for (final path in await _ourSlots()) {
      final binding = await _getString(path, 'binding');
      if (binding.isNotEmpty) return binding;
    }
    return null;
  }

  /// The executable the registered shortcut runs, or null when unset.
  static Future<String?> registeredCommand() async {
    for (final path in await _ourSlots()) {
      final command = await _getString(path, 'command');
      if (command.isNotEmpty) return command;
    }
    return null;
  }

  /// Points the desktop shortcut at this executable and the given hotkey.
  static Future<bool> register(Map hotkey) async {
    if (!await isSupported()) return false;
    final path = await _slotPath();
    if (path == null) return false;

    final binding = bindingFor(hotkey);
    await _freeBinding(binding);

    final slots = await _listedSlots();
    if (!slots.contains(path)) {
      slots.add(path);
      final saved = await Process.run('gsettings', [
        'set',
        _mediaKeysSchema,
        _customKeybindingsKey,
        _stringListValue(slots),
      ]);
      if (saved.exitCode != 0) return false;
    }

    for (final entry in {
      'name': entryName,
      'command': toggleCommand,
      'binding': binding,
    }.entries) {
      final result = await Process.run('gsettings', [
        'set',
        '$_slotSchema:$path',
        entry.key,
        _variant(entry.value),
      ]);
      if (result.exitCode != 0) return false;
    }
    return await registeredBinding() == binding;
  }

  /// The first desktop action already holding this combination, if any.
  ///
  /// GNOME ships Alt+Space as the window menu, and a built-in grab wins without
  /// any error, so the custom shortcut we registered would never run.
  static Future<String?> findConflict(String binding) async {
    for (final entry in _preemptable) {
      final values = await _bindingsOf(entry);
      if (values.any((value) => _sameBinding(value, binding))) {
        return entry.label;
      }
    }
    return null;
  }

  /// Drops [binding] from desktop actions that have an equivalent reachable
  /// without it, so the dictation shortcut can have the key.
  static Future<void> _freeBinding(String binding) async {
    for (final entry in _preemptable) {
      final values = await _bindingsOf(entry);
      final kept = values.where((v) => !_sameBinding(v, binding)).toList();
      if (kept.length == values.length) continue;
      await Process.run('gsettings', [
        'set',
        entry.schema,
        entry.id,
        _stringListValue(kept),
      ]);
    }
  }

  static Future<List<String>> _bindingsOf(_Preemptable entry) async {
    final result = await Process.run('gsettings', [
      'get',
      entry.schema,
      entry.id,
    ]);
    if (result.exitCode != 0) return const [];
    return RegExp(
      r"'([^']*)'",
    ).allMatches(result.stdout.toString()).map((m) => m.group(1)!).toList();
  }

  /// Desktop actions whose key Straight may take over, each one reachable just
  /// as easily another way: the window menu lives on a title-bar right-click.
  static const _preemptable = [
    _Preemptable(
      'org.gnome.desktop.wm.keybindings',
      'activate-window-menu',
      'the GNOME window menu',
    ),
  ];

  static List<String> _bindingParts(String binding) {
    final lowered = binding.toLowerCase();
    final modifiers =
        RegExp(r'<(\w+)>')
            .allMatches(lowered)
            .map((m) => m.group(1) == 'primary' ? 'control' : m.group(1)!)
            .toList()
          ..sort();
    final key = lowered.replaceAll(RegExp(r'<\w+>'), '').trim();
    return [...modifiers, key];
  }

  static bool _sameBinding(String a, String b) =>
      _bindingParts(a).join('+') == _bindingParts(b).join('+');

  static Future<void> remove() async {
    final ours = await _ourSlots();
    if (ours.isEmpty) return;
    for (final path in ours) {
      await Process.run('gsettings', [
        'reset-recursively',
        '$_slotSchema:$path',
      ]);
    }
    final slots = (await _listedSlots())
        .where((path) => !ours.contains(path))
        .toList();
    await Process.run('gsettings', [
      'set',
      _mediaKeysSchema,
      _customKeybindingsKey,
      _stringListValue(slots),
    ]);
  }

  /// Opens the desktop's own shortcut page for users on an unsupportable
  /// desktop, or when they would rather set it themselves.
  static Future<bool> openKeyboardSettings() async {
    try {
      await Process.start('gnome-control-center', [
        'keyboard',
      ], mode: ProcessStartMode.detached);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _slotPath() async {
    final ours = await _ourSlots();
    if (ours.isNotEmpty) return ours.first;
    final listed = (await _listedSlots()).toSet();
    for (var index = 0; index < _slotCount; index++) {
      final path = '$_slotPathPrefix$index/';
      if (!listed.contains(path)) return path;
    }
    return null;
  }

  static Future<List<String>> _ourSlots() async {
    final found = <String>[];
    for (final path in await _listedSlots()) {
      final command = await _getString(path, 'command');
      if ((await _getString(path, 'name')) == entryName ||
          command.endsWith(' --toggle')) {
        found.add(path);
      }
    }
    return found;
  }

  static Future<String> _getString(String path, String key) async {
    final result = await Process.run('gsettings', [
      'get',
      '$_slotSchema:$path',
      key,
    ]);
    if (result.exitCode != 0) return '';
    return _unquote(result.stdout.toString().trim());
  }

  /// A GVariant string literal, which is what `gsettings set` expects. The
  /// command contains single quotes and the binding contains angle brackets,
  /// so both need double-quoted form.
  static String _variant(String value) =>
      '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';

  static String _unquote(String raw) {
    if (raw.length < 2) return raw;
    final first = raw[0];
    if (first != raw[raw.length - 1] || (first != "'" && first != '"')) {
      return raw;
    }
    final body = raw.substring(1, raw.length - 1);
    return body.replaceAll('\\$first', first).replaceAll(r'\\', r'\');
  }

  static Future<List<String>> _listedSlots() async {
    final result = await Process.run('gsettings', [
      'get',
      _mediaKeysSchema,
      _customKeybindingsKey,
    ]);
    if (result.exitCode != 0) return [];
    return RegExp(
      r"'(/[^']*)'",
    ).allMatches(result.stdout.toString()).map((m) => m.group(1)!).toList();
  }

  static String _stringListValue(List<String> values) {
    if (values.isEmpty) return '@as []';
    return "[${values.map((v) => "'$v'").join(', ')}]";
  }

  /// The desktop key string for a stored hotkey, e.g. `<Alt>space`.
  static String bindingFor(Map hotkey) {
    final modifiers = <String>[
      if (hotkey['ctrl'] == true) '<Control>',
      if (hotkey['alt'] == true) '<Alt>',
      if (hotkey['shift'] == true) '<Shift>',
      if (hotkey['meta'] == true) '<Super>',
    ];
    return '${modifiers.join()}${_keysym((hotkey['key'] ?? 'Space').toString())}';
  }

  static String _keysym(String label) {
    switch (label.toLowerCase()) {
      case 'space':
        return 'space';
      case 'enter':
        return 'Return';
      case 'tab':
        return 'Tab';
      case 'escape':
        return 'Escape';
      default:
        return label.length == 1 ? label.toLowerCase() : 'space';
    }
  }
}

class _Preemptable {
  const _Preemptable(this.schema, this.id, this.label);

  final String schema;
  final String id;
  final String label;
}
