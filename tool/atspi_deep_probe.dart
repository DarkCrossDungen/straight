// ignore_for_file: avoid_print

import 'dart:ffi';

import 'package:ffi/ffi.dart';

typedef _Init = Int32 Function();
typedef _GetDesktop = Pointer<Void> Function(Int32);
typedef _ChildCount = Int32 Function(Pointer<Void>, Pointer<Void>?);
typedef _ChildAt =
    Pointer<Void> Function(Pointer<Void>, Int32, Pointer<Void>?);
typedef _GetName = Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?);
typedef _StateSet = Pointer<Void> Function(Pointer<Void>);
typedef _HasState = Int32 Function(Pointer<Void>, Int32);
typedef _RoleName = Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?);
typedef _Attributes = Pointer<Void> Function(Pointer<Void>, Pointer<Void>?);
typedef _Insert = Int32 Function(
    Pointer<Void>, Int32, Pointer<Utf8>, Int32, Pointer<Void>?);
typedef _TextInt = Int32 Function(Pointer<Void>, Pointer<Void>?);
typedef _GetText = Pointer<Utf8> Function(
    Pointer<Void>, Int32, Int32, Pointer<Void>?);

/// Walks the whole AT-SPI desktop and reports, per app: node counts, editable
/// nodes (name/role/states), and any FOCUSED node. Proves whether GTK apps in
/// this session expose text trees at all, and whether focus is observable.
Future<void> main(List<String> args) async {
  final doInsert = args.contains('insert');
  final doRead = args.contains('read');
  final api = _Api(DynamicLibrary.open('libatspi.so.0'));
  api.init();
  final desktop = api.getDesktop(0);
  if (desktop.address == 0) {
    print('FAIL: no desktop');
    return;
  }
  final apps = api.childCount(desktop, nullptr);
  print('desktop apps=$apps');
  for (var i = 0; i < apps; i++) {
    final app = api.childAt(desktop, i, nullptr);
    if (app.address == 0) continue;
    final appName = api.name(app, nullptr);
    api.wake(app);
    final acc = _Acc();
    _walk(app, api, 0, acc);
    print(
        'APP "$appName" nodes=${acc.nodeCount} editables=${acc.editableCount} '
        'focused=${acc.focusedCount} windows=${api.childCount(app, nullptr)}');
    for (final hit in acc.hits) {
      print('   EDITABLE role=${hit.role} name="${hit.name}" '
          'focused=${hit.focused} showing=${hit.showing} '
          'enabled=${hit.enabled} sensitive=${hit.sensitive}');
      if (doRead) {
        final total = api.characterCount(hit.node, nullptr);
        print('   READ len=$total '
            'text="${api.readText(hit.node, 0, total)}"');
      }
    }
    if (doInsert && !api.isOwnApp(appName)) {
      for (final hit in acc.hits) {
        final marker =
            'straight-verify-${DateTime.now().millisecondsSinceEpoch}';
        final caret = api.caretOffset(hit.node, nullptr);
        final pos = caret >= 0 ? caret : api.characterCount(hit.node, nullptr);
        final ok = api.insertText(marker, hit.node, pos);
        final total = api.characterCount(hit.node, nullptr);
        final tail = api.readText(hit.node, total - marker.length, total);
        print('   INSERT role=${hit.role} rc=$ok readback="$tail" '
            'match=${tail == marker}');
      }
    }
  }
}

class _Acc {
  int nodeCount = 0;
  int editableCount = 0;
  int focusedCount = 0;
  final List<_Hit> hits = [];
}

class _Hit {
  _Hit(this.node, this.name, this.role, this.focused, this.showing,
      this.enabled, this.sensitive);
  final Pointer<Void> node;
  final String name;
  final String role;
  final bool focused;
  final bool showing;
  final bool enabled;
  final bool sensitive;
}

void _walk(Pointer<Void> node, _Api api, int depth, _Acc acc) {
  if (depth > 12) return;
  acc.nodeCount++;
  if (api.has(node, 7)) {
    acc.editableCount++;
    acc.hits.add(_Hit(node, api.name(node, nullptr), api.roleName(node, nullptr),
        api.has(node, 12), api.has(node, 25), api.has(node, 8), api.has(node, 24)));
  }
  if (api.has(node, 12)) acc.focusedCount++;
  final children = api.childCount(node, nullptr);
  for (var i = 0; i < children && i < 60; i++) {
    final child = api.childAt(node, i, nullptr);
    if (child.address == 0) continue;
    _walk(child, api, depth + 1, acc);
  }
}

class _Api {
  _Api(DynamicLibrary lib)
      : init = lib.lookupFunction<_Init, int Function()>('atspi_init'),
        getDesktop =
            lib.lookupFunction<_GetDesktop, Pointer<Void> Function(int)>(
                'atspi_get_desktop'),
        childCount = lib.lookupFunction<_ChildCount,
                int Function(Pointer<Void>, Pointer<Void>?)>(
            'atspi_accessible_get_child_count'),
        childAt = lib.lookupFunction<_ChildAt,
                Pointer<Void> Function(Pointer<Void>, int, Pointer<Void>?)>(
            'atspi_accessible_get_child_at_index'),
        nameOf = lib.lookupFunction<_GetName,
                Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?)>(
            'atspi_accessible_get_name'),
        attributes = lib.lookupFunction<_Attributes,
                Pointer<Void> Function(Pointer<Void>, Pointer<Void>?)>(
            'atspi_accessible_get_attributes'),
        stateSet = lib.lookupFunction<_StateSet,
                Pointer<Void> Function(Pointer<Void>)>(
            'atspi_accessible_get_state_set'),
        hasState = lib.lookupFunction<_HasState,
                int Function(Pointer<Void>, int)>('atspi_state_set_contains'),
        roleNameOf = lib.lookupFunction<_RoleName,
                Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?)>(
            'atspi_accessible_get_role_name'),
        insert = lib.lookupFunction<_Insert,
                int Function(Pointer<Void>, int, Pointer<Utf8>, int,
                    Pointer<Void>?)>('atspi_editable_text_insert_text'),
        charCount = lib.lookupFunction<_TextInt,
                int Function(Pointer<Void>, Pointer<Void>?)>(
            'atspi_text_get_character_count'),
        caret = lib.lookupFunction<_TextInt,
                int Function(Pointer<Void>, Pointer<Void>?)>(
            'atspi_text_get_caret_offset'),
        getText = lib.lookupFunction<_GetText,
                Pointer<Utf8> Function(Pointer<Void>, int, int, Pointer<Void>?)>(
            'atspi_text_get_text');

  final int Function() init;
  final Pointer<Void> Function(int) getDesktop;
  final int Function(Pointer<Void>, Pointer<Void>?) childCount;
  final Pointer<Void> Function(Pointer<Void>, int, Pointer<Void>?) childAt;
  final Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?) nameOf;
  final Pointer<Void> Function(Pointer<Void>, Pointer<Void>?) attributes;
  final Pointer<Void> Function(Pointer<Void>) stateSet;
  final int Function(Pointer<Void>, int) hasState;
  final Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?) roleNameOf;
  final int Function(
      Pointer<Void>, int, Pointer<Utf8>, int, Pointer<Void>?) insert;
  final int Function(Pointer<Void>, Pointer<Void>?) charCount;
  final int Function(Pointer<Void>, Pointer<Void>?) caret;
  final Pointer<Utf8> Function(
      Pointer<Void>, int, int, Pointer<Void>?) getText;

  String name(Pointer<Void> node, Pointer<Void>? error) =>
      _str(nameOf(node, error));
  String roleName(Pointer<Void> node, Pointer<Void>? error) =>
      _str(roleNameOf(node, error));

  static String _str(Pointer<Utf8> raw) =>
      raw.address == 0 ? '' : raw.toDartString();

  bool has(Pointer<Void> node, int state) {
    final states = stateSet(node);
    return states.address != 0 && hasState(states, state) != 0;
  }

  bool isOwnApp(String name) =>
      name.isEmpty || name.toLowerCase().contains('straight');

  void wake(Pointer<Void> app) {
    attributes(app, nullptr);
    final children = childCount(app, nullptr);
    for (var i = 0; i < children && i < 60; i++) {
      final window = childAt(app, i, nullptr);
      if (window.address != 0) attributes(window, nullptr);
    }
  }

  bool insertText(String text, Pointer<Void> node, int position) {
    final utf = text.toNativeUtf8();
    try {
      return insert(node, position, utf, utf.length, nullptr) != 0;
    } finally {
      calloc.free(utf);
    }
  }

  int characterCount(Pointer<Void> node, Pointer<Void>? error) =>
      charCount(node, error);

  int caretOffset(Pointer<Void> node, Pointer<Void>? error) => caret(node, error);

  String readText(Pointer<Void> node, int from, int to) =>
      _str(getText(node, from, to, nullptr));
}
