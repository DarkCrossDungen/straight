// ignore_for_file: avoid_print

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:straight/core/injection/atspi_text_injector.dart';

typedef _Init = Int32 Function();
typedef _GetDesktop = Pointer<Void> Function(Int32);
typedef _ChildCount = Int32 Function(Pointer<Void>, Pointer<Void>?);
typedef _ChildAt = Pointer<Void> Function(Pointer<Void>, Int32, Pointer<Void>?);
typedef _GetName = Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?);
typedef _StateSet = Pointer<Void> Function(Pointer<Void>);
typedef _HasState = Int32 Function(Pointer<Void>, Int32);
typedef _TextInt = Int32 Function(Pointer<Void>, Pointer<Void>?);
typedef _GetText = Pointer<Utf8> Function(
    Pointer<Void>, Int32, Int32, Pointer<Void>?);

const _editable = 7;
const _focused = 12;

void main(List<String> args) {
  final injector = AtspiTextInjector();
  injector.captureFocus();
  print('focused app: "${injector.targetApp}"');
  if (injector.targetApp.isEmpty) {
    print('NO EDITABLE FOCUSED');
    exit(2);
  }

  final api = _Api(DynamicLibrary.open('libatspi.so.0'));
  api.init();
  final desktop = api.getDesktop(0);

  String? before;
  Pointer<Void>? node;
  for (var i = 0; i < api.childCount(desktop, nullptr); i++) {
    final app = api.childAt(desktop, i, nullptr);
    if (app.address == 0) continue;
    if (api.name(app, nullptr) != injector.targetApp) continue;
    node = api.findEditable(app, 0, true);
    if (node == null) node = api.findEditable(app, 0, false);
    break;
  }
  if (node == null || node.address == 0) {
    print('NO EDITABLE NODE');
    exit(3);
  }
  final count = api.charCount(node, nullptr);
  if (count > 0) {
    final raw = api.getText(node, 0, count, nullptr);
    if (raw.address != 0) before = raw.toDartString();
  }
  print('editable text before: "${before ?? ''}"');

  final marker =
      'ATSPI-OK-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
  final ok = injector.inject(' $marker');
  print('inject returned: $ok');

  final afterCount = api.charCount(node, nullptr);
  String after = '';
  if (afterCount > 0) {
    final raw = api.getText(node, 0, afterCount, nullptr);
    if (raw.address != 0) after = raw.toDartString();
  }
  print('editable text after: "$after"');
  print(after.contains(marker) ? 'RESULT: REAL-TYPING-OK' : 'RESULT: FAILED');
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
        stateSet = lib.lookupFunction<_StateSet,
                Pointer<Void> Function(Pointer<Void>)>(
            'atspi_accessible_get_state_set'),
        hasState = lib.lookupFunction<_HasState, int Function(Pointer<Void>, int)>(
            'atspi_state_set_contains'),
        charCount = lib.lookupFunction<_TextInt,
                int Function(Pointer<Void>, Pointer<Void>?)>(
            'atspi_text_get_character_count'),
        getText = lib.lookupFunction<_GetText,
                Pointer<Utf8> Function(
                    Pointer<Void>, int, int, Pointer<Void>?)>(
            'atspi_text_get_text');

  final int Function() init;
  final Pointer<Void> Function(int) getDesktop;
  final int Function(Pointer<Void>, Pointer<Void>?) childCount;
  final Pointer<Void> Function(Pointer<Void>, int, Pointer<Void>?) childAt;
  final Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?) nameOf;
  final Pointer<Void> Function(Pointer<Void>) stateSet;
  final int Function(Pointer<Void>, int) hasState;
  final int Function(Pointer<Void>, Pointer<Void>?) charCount;
  final Pointer<Utf8> Function(Pointer<Void>, int, int, Pointer<Void>?) getText;

  String name(Pointer<Void> node, Pointer<Void>? error) {
    final raw = nameOf(node, error);
    return raw.address == 0 ? '' : raw.toDartString();
  }

  Pointer<Void>? findEditable(Pointer<Void> node, int depth, bool focusedOnly) {
    if (depth > 24) return null;
    final states = stateSet(node);
    if (states.address != 0 && hasState(states, _editable) != 0) {
      if (!focusedOnly || hasState(states, _focused) != 0) return node;
    }
    final children = childCount(node, nullptr);
    for (var i = 0; i < children && i < 48; i++) {
      final child = childAt(node, i, nullptr);
      if (child.address == 0) continue;
      final hit = findEditable(child, depth + 1, focusedOnly);
      if (hit != null) return hit;
    }
    return null;
  }
}
