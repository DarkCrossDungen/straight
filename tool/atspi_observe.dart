// ignore_for_file: avoid_print

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _Init = Int32 Function();
typedef _GetDesktop = Pointer<Void> Function(Int32);
typedef _ChildCount = Int32 Function(Pointer<Void>, Pointer<Void>?);
typedef _ChildAt = Pointer<Void> Function(Pointer<Void>, Int32, Pointer<Void>?);
typedef _GetName = Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?);
typedef _StateSet = Pointer<Void> Function(Pointer<Void>);
typedef _HasState = Int32 Function(Pointer<Void>, Int32);

void main(List<String> args) async {
  final api = _Api(DynamicLibrary.open('libatspi.so.0'));
  api.init();
  final desktop = api.getDesktop(0);
  print('desktop: ${desktop.address} children=${api.childCount(desktop, nullptr)}');
  for (var i = 0; i < api.childCount(desktop, nullptr); i++) {
    final app = api.childAt(desktop, i, nullptr);
    if (app.address == 0) continue;
    final name = api.name(app, nullptr);
    if (name.isEmpty) continue;
    print('APP "$name" (window count=${api.childCount(app, nullptr)})');
    // Walk windows one level deep; print titles.
    for (var w = 0; w < api.childCount(app, nullptr); w++) {
      final window = api.childAt(app, w, nullptr);
      if (window.address == 0) continue;
      print('   WINDOW name="${api.name(window, nullptr)}" states=${api.states(window)}');
    }
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
        stateSet = lib.lookupFunction<_StateSet,
                Pointer<Void> Function(Pointer<Void>)>(
            'atspi_accessible_get_state_set'),
        hasState = lib.lookupFunction<_HasState, int Function(Pointer<Void>, int)>(
            'atspi_state_set_contains');

  final int Function() init;
  final Pointer<Void> Function(int) getDesktop;
  final int Function(Pointer<Void>, Pointer<Void>?) childCount;
  final Pointer<Void> Function(Pointer<Void>, int, Pointer<Void>?) childAt;
  final Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?) nameOf;
  final Pointer<Void> Function(Pointer<Void>) stateSet;
  final int Function(Pointer<Void>, int) hasState;

  String name(Pointer<Void> node, Pointer<Void>? error) {
    final raw = nameOf(node, error);
    return raw.address == 0 ? '' : raw.toDartString();
  }

  String states(Pointer<Void> node) {
    final states = stateSet(node);
    if (states.address == 0) return '-';
    final buf = StringBuffer();
    // active=0, focused=12 (common ones we care about)
    for (final s in <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]) {
      if (hasState(states, s) != 0) buf.write('$s ');
    }
    return buf.toString().trim();
  }
}
