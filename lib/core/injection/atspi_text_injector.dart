import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

import 'linux_typing_helper.dart';
import 'text_injector_platform.dart';

const _stateEditable = 7;
const _stateFocused = 12;
const _rolePasswordText = 40;
const _roleText = 61;
const _roleParagraph = 73;
const _roleEntry = 79;
const _maxDepth = 24;
const _maxChildren = 48;

typedef _InitNative = Int32 Function();
typedef _GetDesktopNative = Pointer<Void> Function(Int32);
typedef _ChildCountNative = Int32 Function(Pointer<Void>, Pointer<Void>?);
typedef _ChildAtNative =
    Pointer<Void> Function(Pointer<Void>, Int32, Pointer<Void>?);
typedef _GetNameNative = Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?);
typedef _StateSetNative = Pointer<Void> Function(Pointer<Void>);
typedef _HasStateNative = Int32 Function(Pointer<Void>, Int32);
typedef _RoleNative = Int32 Function(Pointer<Void>, Pointer<Void>?);
typedef _TextIntNative = Int32 Function(Pointer<Void>, Pointer<Void>?);
typedef _AttributesNative = Pointer<Void> Function(
    Pointer<Void>, Pointer<Void>?);
typedef _InsertNative =
    Int32 Function(Pointer<Void>, Int32, Pointer<Utf8>, Int32, Pointer<Void>?);

/// Types into other apps through AT-SPI, the Linux accessibility bus.
///
/// Wayland refuses synthetic key events, but the accessibility API that screen
/// readers use stays open. Writing into the focused editable object directly
/// also keeps the target app's caret and undo history intact, and needs no
/// extra permissions.
class AtspiTextInjector implements TextInjectorPlatform {
  _Atspi? _api;
  String _targetApp = '';

  /// Name of the app remembered by [captureFocus]; empty when nothing focused
  /// an editable object.
  String get targetApp => _targetApp;

  @override
  void captureFocus() {
    _targetApp = '';
    final api = _open();
    if (api == null) return;
    final desktop = api.getDesktop(0);
    for (var i = 0; i < api.childCount(desktop, nullptr); i++) {
      final app = api.childAt(desktop, i, nullptr);
      if (app.address == 0) continue;
      final appName = api.name(app, nullptr);
      if (_isOwnApp(appName)) continue;
      api.wake(app);
      // Only remember an app that currently reports a focused editable: an app
      // remembered from the desktop listing could be anything, and typing into
      // the wrong window is worse than falling back to key events.
      if (api.findFocused(appName, desktop).address != 0) {
        _targetApp = appName;
        return;
      }
    }
  }

  @override
  Future<bool> inject(String text) async {
    if (text.trim().isEmpty) return false;

    final api = _open();
    if (api != null && _insertIntoAccessible(api, text)) return true;

    // AT-SPI had nothing to write into. That is not a broken bus: GTK4 builds
    // here link no accessibility bridge, and Electron and Chromium apps expose
    // no document tree, so no editable object exists to insert text into. The
    // remaining way to reach those apps is synthesised key events, which the
    // compositor routes to whatever window has focus.
    return _typeWithKeyEvents(text);
  }

  /// Inserts into an editable accessible object and proves it landed by reading
  /// the node back. Returns false when there is nothing trustworthy to write
  /// into, which sends the caller on to synthesised key events.
  bool _insertIntoAccessible(_Atspi api, String text) {
    final desktop = api.getDesktop(0);
    if (desktop.address == 0) return false;

    Pointer<Void>? node;
    if (_targetApp.isNotEmpty) {
      final focused = api.findFocused(_targetApp, desktop);
      node = focused.address != 0
          ? focused
          : api.findInApp(desktop, _targetApp, focusedOnly: false);
    } else {
      node = _pickFocusEditable(api, desktop);
    }
    if (node == null || node.address == 0) return false;
    // Labels and paragraphs expose the text interface but do not accept typed
    // input; inserting there loses the transcript without any error.
    if (!_hasPlainText(api, node)) return false;

    final before = api.characterCount(node, nullptr);
    if (before < 0) return false;
    final caret = api.caretOffset(node, nullptr);
    if (caret < 0) return false;

    final utf = text.toNativeUtf8();
    try {
      api.insertText(node, caret, utf, utf.length);
    } finally {
      calloc.free(utf);
    }

    final after = api.characterCount(node, nullptr);
    if (after >= before + text.length) return true;
    // A node that reports no larger buffer may still have taken the text, so a
    // caret that advanced the length of the insert counts as proof too.
    return api.caretOffset(node, nullptr) >= caret + text.length;
  }

  /// The focused editable on the desktop. Used when no app was remembered at
  /// capture time; an unfocused field in another app is a guess, and key
  /// synthesis targets the real focus instead.
  Pointer<Void>? _pickFocusEditable(_Atspi api, Pointer<Void> desktop) {
    for (var i = 0; i < api.childCount(desktop, nullptr); i++) {
      final app = api.childAt(desktop, i, nullptr);
      if (app.address == 0) continue;
      final appName = api.name(app, nullptr);
      if (_isOwnApp(appName)) continue;
      final hit = api.findFocused(appName, desktop);
      if (hit.address != 0) return hit;
    }
    return null;
  }

  /// Filters AT-SPI nodes to the ones an app actually accepts text into: some
  /// expose the text interface without accepting the editable one.
  bool _hasPlainText(_Atspi api, Pointer<Void> node) {
    final nodeRole = api.role(node, nullptr);
    return api.supportedTextRoles.contains(nodeRole);
  }

  Future<bool> _typeWithKeyEvents(String text) async {
    final xtype = await LinuxTypingHelper.xtype(text);
    if (xtype == TypingResult.typed) return true;
    if (xtype == TypingResult.missingCharacter) {
      // A codepoint with no key on this keymap (curly quotes, accented words)
      // cannot be synthesized, so paste it instead: the clipboard carries full
      // Unicode and the paste key is one keypress.
      return _pasteFromClipboard(text);
    }
    // No usable X display means the app is a pure Wayland client. The kernel
    // keyboard reaches those even though the accessibility bus cannot.
    return await LinuxTypingHelper.ktype(text) == TypingResult.typed;
  }

  Future<bool> _pasteFromClipboard(String text) async {
    if (!LinuxTypingHelper.xtypeUsable) return false;
    await Clipboard.setData(ClipboardData(text: text));
    return (await LinuxTypingHelper.paste()) == TypingResult.pasted;
  }

  _Atspi? _open() {
    final existing = _api;
    if (existing != null) return existing;
    try {
      final api = _Atspi(DynamicLibrary.open('libatspi.so.0'));
      api.init();
      _api = api;
      return api;
    } catch (_) {
      return null;
    }
  }

  bool _isOwnApp(String name) =>
      name.isEmpty || name.toLowerCase().contains('straight');
}

/// The slice of the AT-SPI C API this injector needs. Every call carries a
/// trailing `GError **`, passed as NULL so failures surface as null or -1.
class _Atspi {
  _Atspi(DynamicLibrary lib)
      : init = lib.lookupFunction<_InitNative, int Function()>(
            'atspi_init'),
        getDesktop = lib.lookupFunction<_GetDesktopNative,
                Pointer<Void> Function(int)>('atspi_get_desktop'),
        childCount = lib.lookupFunction<_ChildCountNative,
                int Function(Pointer<Void>, Pointer<Void>? )>(
            'atspi_accessible_get_child_count'),
        childAt = lib.lookupFunction<_ChildAtNative,
                Pointer<Void> Function(
                    Pointer<Void>, int, Pointer<Void>?)>(
            'atspi_accessible_get_child_at_index'),
        attributes = lib.lookupFunction<_AttributesNative,
                Pointer<Void> Function(
                    Pointer<Void>, Pointer<Void>?)>(
            'atspi_accessible_get_attributes'),
        nameOf = lib.lookupFunction<_GetNameNative,
                Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>? )>(
            'atspi_accessible_get_name'),
        stateSet = lib.lookupFunction<_StateSetNative,
                Pointer<Void> Function(Pointer<Void>)>(
            'atspi_accessible_get_state_set'),
        hasState = lib.lookupFunction<_HasStateNative,
                int Function(Pointer<Void>, int)>('atspi_state_set_contains'),
        charCount = lib.lookupFunction<_TextIntNative,
                int Function(
                    Pointer<Void>, Pointer<Void>? )>(
            'atspi_text_get_character_count'),
        caret = lib.lookupFunction<_TextIntNative,
                int Function(
                    Pointer<Void>, Pointer<Void>? )>(
            'atspi_text_get_caret_offset'),
        insert = lib.lookupFunction<_InsertNative,
                int Function(Pointer<Void>, int, Pointer<Utf8>, int,
                    Pointer<Void>?)>('atspi_editable_text_insert_text'),
        roleOf = lib.lookupFunction<_RoleNative,
                int Function(Pointer<Void>, Pointer<Void>?)>(
            'atspi_accessible_get_role');

  final int Function() init;
  final Pointer<Void> Function(int) getDesktop;
  final int Function(Pointer<Void>, Pointer<Void>?) childCount;
  final Pointer<Void> Function(Pointer<Void>, int, Pointer<Void>?) childAt;
  final Pointer<Void> Function(Pointer<Void>, Pointer<Void>?) attributes;
  final Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?) nameOf;
  final Pointer<Void> Function(Pointer<Void>) stateSet;
  final int Function(Pointer<Void>, int) hasState;
  final int Function(Pointer<Void>, Pointer<Void>?) charCount;
  final int Function(Pointer<Void>, Pointer<Void>?) caret;
  final int Function(Pointer<Void>, Pointer<Void>?) roleOf;
  final int Function(Pointer<Void>, int, Pointer<Utf8>, int, Pointer<Void>?)
      insert;

  String name(Pointer<Void> node, Pointer<Void>? error) {
    final raw = nameOf(node, error);
    return raw.address == 0 ? '' : raw.toDartString();
  }

  bool _isEditable(Pointer<Void> node) {
    final states = stateSet(node);
    return states.address != 0 && hasState(states, _stateEditable) != 0;
  }

  bool _isFocused(Pointer<Void> node) {
    final states = stateSet(node);
    return states.address != 0 && hasState(states, _stateFocused) != 0;
  }

  /// Browsers and Electron builds keep their text tree hidden until an
  /// assistive technology reads their attributes. The reply is discarded; the
  /// call itself is the switch, and the tree then fills in asynchronously.
  void wake(Pointer<Void> app) {
    attributes(app, nullptr);
    final children = childCount(app, nullptr);
    for (var i = 0; i < children && i < _maxChildren; i++) {
      final window = childAt(app, i, nullptr);
      if (window.address != 0) attributes(window, nullptr);
    }
  }

  Pointer<Void> findFocused(String appName, Pointer<Void> desktop) {
    for (var i = 0; i < childCount(desktop, nullptr); i++) {
      final app = childAt(desktop, i, nullptr);
      if (app.address == 0) continue;
      if (name(app, nullptr) != appName) continue;
      wake(app);
      final hit = _search(app, 0, true);
      if (hit.address != 0) return hit;
    }
    return nullptr;
  }

  Pointer<Void> findInApp(
      Pointer<Void> desktop, String appName, {required bool focusedOnly}) {
    for (var i = 0; i < childCount(desktop, nullptr); i++) {
      final app = childAt(desktop, i, nullptr);
      if (app.address == 0) continue;
      if (name(app, nullptr) != appName) continue;
      wake(app);
      return _search(app, 0, focusedOnly);
    }
    return nullptr;
  }

  /// Roles an app accepts typed text into. Chrome's address bar is an ENTRY and
  /// a document view is a TEXT, but a label or paragraph only displays text and
  /// swallows the insert without telling anyone.
  List<int> get supportedTextRoles =>
      const [_roleEntry, _rolePasswordText, _roleText, _roleParagraph];

  int role(Pointer<Void> node, Pointer<Void>? error) => roleOf(node, error);

  Pointer<Void> _search(Pointer<Void> node, int depth, bool focusedOnly) {
    if (depth > _maxDepth) return nullptr;
    if (_isEditable(node) && (!focusedOnly || _isFocused(node))) return node;
    final children = childCount(node, nullptr);
    for (var i = 0; i < children && i < _maxChildren; i++) {
      final child = childAt(node, i, nullptr);
      if (child.address == 0) continue;
      final hit = _search(child, depth + 1, focusedOnly);
      if (hit.address != 0) return hit;
    }
    return nullptr;
  }

  int characterCount(Pointer<Void> node, Pointer<Void>? error) =>
      charCount(node, error);

  int caretOffset(Pointer<Void> node, Pointer<Void>? error) =>
      caret(node, error);

  bool insertText(
      Pointer<Void> node, int position, Pointer<Utf8> text, int length) {
    return insert(node, position, text, length, nullptr) != 0;
  }
}
