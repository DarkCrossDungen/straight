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
typedef _TextInt = Int32 Function(Pointer<Void>, Pointer<Void>?);
typedef _Attributes = Pointer<Void> Function(
    Pointer<Void>, Pointer<Void>?);
typedef _Insert = Int32 Function(
    Pointer<Void>, Int32, Pointer<Utf8>, Int32, Pointer<Void>?);
typedef _GetText = Pointer<Utf8> Function(
    Pointer<Void>, Int32, Int32, Pointer<Void>?);

/// Mirrors AtspiTextInjector call for call: wake an app, find the focused
/// editable, insert at the caret, read the tail back to prove it landed.
Future<void> main(List<String> args) async {
  final marker =
      args.isNotEmpty ? args.first : 'straight-atspi-${DateTime.now().millisecondsSinceEpoch}';
  final api = _Api(DynamicLibrary.open('libatspi.so.0'));
  api.init();
  final desktop = api.getDesktop(0);
  if (desktop.address == 0) {
    print('FAIL: no desktop');
    return;
  }
  print('desktop children=${api.childCount(desktop, nullptr)}');

  for (var i = 0; i < api.childCount(desktop, nullptr); i++) {
    final app = api.childAt(desktop, i, nullptr);
    if (app.address == 0) continue;
    final name = api.name(app);
    if (name.toLowerCase().contains('straight')) continue;
    api.wake(app);
    final focused = api.findFocusable(app);
    print('app "$name" focused-editable=${focused.address != 0}');
    if (focused.address == 0) continue;

    final caret = api.caretOffset(focused, nullptr);
    final ok = api.inject(marker, focused, caret);
    print('insert rc=$ok into "$name" at caret=$caret');
    if (ok) {
      final count = api.charCount(focused, nullptr);
      final tail = api.text(focused, count - marker.length, count);
      print('readback tail="$tail" match=${tail == marker}');
    }
    return;
  }
  print('NO focused editable found in any non-straight app');
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
                Pointer<Void> Function(
                    Pointer<Void>, int, Pointer<Void>?)>(
            'atspi_accessible_get_child_at_index'),
        nameOf = lib.lookupFunction<_GetName,
                Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?)>(
            'atspi_accessible_get_name'),
        attributes = lib.lookupFunction<_Attributes,
                Pointer<Void> Function(
                    Pointer<Void>, Pointer<Void>?)>(
            'atspi_accessible_get_attributes'),
        stateSet = lib.lookupFunction<_StateSet,
                Pointer<Void> Function(Pointer<Void>)>(
            'atspi_accessible_get_state_set'),
        hasState = lib.lookupFunction<_HasState, int Function(Pointer<Void>, int)>(
            'atspi_state_set_contains'),
        charCount = lib.lookupFunction<_TextInt,
                int Function(Pointer<Void>, Pointer<Void>?)>(
            'atspi_text_get_character_count'),
        caretOffset = lib.lookupFunction<_TextInt,
                int Function(Pointer<Void>, Pointer<Void>?)>(
            'atspi_text_get_caret_offset'),
        insert = lib.lookupFunction<_Insert,
                int Function(
                    Pointer<Void>, int, Pointer<Utf8>, int, Pointer<Void>?)>(
            'atspi_editable_text_insert_text'),
        getText = lib.lookupFunction<_GetText,
                Pointer<Utf8> Function(
                    Pointer<Void>, int, int, Pointer<Void>?)>(
            'atspi_text_get_text');

  final int Function() init;
  final Pointer<Void> Function(int) getDesktop;
  final int Function(Pointer<Void>, Pointer<Void>?) childCount;
  final Pointer<Void> Function(Pointer<Void>, int, Pointer<Void>?) childAt;
  final Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?) nameOf;
  final Pointer<Void> Function(Pointer<Void>, Pointer<Void>?) attributes;
  final Pointer<Void> Function(Pointer<Void>) stateSet;
  final int Function(Pointer<Void>, int) hasState;
  final int Function(Pointer<Void>, Pointer<Void>?) charCount;
  final int Function(Pointer<Void>, Pointer<Void>?) caretOffset;
  final int Function(
      Pointer<Void>, int, Pointer<Utf8>, int, Pointer<Void>?) insert;
  final Pointer<Utf8> Function(
      Pointer<Void>, int, int, Pointer<Void>?) getText;

  String name(Pointer<Void> node) {
    final raw = nameOf(node, nullptr);
    return raw.address == 0 ? '' : raw.toDartString();
  }

  void wake(Pointer<Void> app) {
    attributes(app, nullptr);
    final children = childCount(app, nullptr);
    for (var i = 0; i < children && i < 48; i++) {
      final window = childAt(app, i, nullptr);
      if (window.address != 0) attributes(window, nullptr);
    }
  }

  Pointer<Void> findFocusable(Pointer<Void> app) => _search(app, 0) ?? nullptr;

  Pointer<Void>? _search(Pointer<Void> node, int depth) {
    if (depth > 24) return null;
    if (_isEditable(node) && _isFocused(node)) return node;
    final children = childCount(node, nullptr);
    for (var i = 0; i < children && i < 48; i++) {
      final child = childAt(node, i, nullptr);
      if (child.address == 0) continue;
      final hit = _search(child, depth + 1);
      if (hit != null) return hit;
    }
    return null;
  }

  bool _isEditable(Pointer<Void> node) {
    final states = stateSet(node);
    return states.address != 0 && hasState(states, 7) != 0;
  }

  bool _isFocused(Pointer<Void> node) {
    final states = stateSet(node);
    return states.address != 0 && hasState(states, 12) != 0;
  }

  bool inject(String text, Pointer<Void> node, int position) {
    final utf = text.toNativeUtf8();
    try {
      return insert(node, position, utf, utf.length, nullptr) != 0;
    } finally {
      calloc.free(utf);
    }
  }

  String text(Pointer<Void> node, int from, int to) {
    final raw = getText(node, from, to, nullptr);
    return raw.address == 0 ? '' : raw.toDartString();
  }
}
