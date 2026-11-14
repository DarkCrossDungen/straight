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
typedef _RoleGet = Pointer<Void> Function(Pointer<Void>);
typedef _RoleName = Pointer<Utf8> Function(Pointer<Void>);

void main(List<String> args) async {
  final api = _Api(DynamicLibrary.open('libatspi.so.0'));
  api.init();
  final desktop = api.getDesktop(0);
  print('desktop children=${api.childCount(desktop, nullptr)}');
  for (var i = 0; i < api.childCount(desktop, nullptr); i++) {
    final app = api.childAt(desktop, i, nullptr);
    if (app.address == 0) continue;
    final name = api.name(app, nullptr);
    if (!name.contains('straight') && !name.contains('Qoder')) continue;
    print('APP "$name"');
    for (var w = 0; w < api.childCount(app, nullptr); w++) {
      final window = api.childAt(app, w, nullptr);
      if (window.address == 0) continue;
      print('   WINDOW name="${api.name(window, nullptr)}"');
      _walk(window, api, '      ', 0);
    }
  }
}

void _walk(Pointer<Void> node, _Api api, String indent, int depth) {
  if (depth > 6) return;
  final n = api.name(node, nullptr);
  if (n.isNotEmpty) print('$indent"$n" role=${api.roleName(node)}');
  final children = api.childCount(node, nullptr);
  for (var i = 0; i < children; i++) {
    final child = api.childAt(node, i, nullptr);
    if (child.address == 0) continue;
    _walk(child, api, indent + '  ', depth + 1);
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
            'atspi_state_set_contains'),
        roleNative = lib.lookupFunction<_RoleGet,
                Pointer<Void> Function(Pointer<Void>)>(
            'atspi_accessible_get_role'),
        roleNameOf = lib.lookupFunction<_RoleName,
                Pointer<Utf8> Function(Pointer<Void>)>(
            'atspi_accessible_get_role_name');

  final int Function() init;
  final Pointer<Void> Function(int) getDesktop;
  final int Function(Pointer<Void>, Pointer<Void>?) childCount;
  final Pointer<Void> Function(Pointer<Void>, int, Pointer<Void>?) childAt;
  final Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?) nameOf;
  final Pointer<Void> Function(Pointer<Void>) stateSet;
  final int Function(Pointer<Void>, int) hasState;
  final Pointer<Void> Function(Pointer<Void>) roleNative;
  final Pointer<Utf8> Function(Pointer<Void>) roleNameOf;

  String name(Pointer<Void> node, Pointer<Void>? error) {
    final raw = nameOf(node, error);
    return raw.address == 0 ? '' : raw.toDartString();
  }

  String roleName(Pointer<Void> node) {
    final raw = roleNameOf(roleNative(node));
    return raw.address == 0 ? '?' : raw.toDartString();
  }
}
