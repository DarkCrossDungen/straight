// ignore_for_file: avoid_print

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _Init = Int32 Function();
typedef _GetDesktop = Pointer<Void> Function(Int32);
typedef _ChildCount = Int32 Function(Pointer<Void>, Pointer<Void>?);
typedef _ChildAt = Pointer<Void> Function(Pointer<Void>, Int32, Pointer<Void>?);
typedef _GetName = Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?);

void main() async {
  final api = _Api(DynamicLibrary.open('libatspi.so.0'));
  try {
    api.init();
  } catch (e) {
    print('init failed: $e');
    return;
  }
  final desktop = api.getDesktop(0);
  print('desktop children=${api.childCount(desktop, nullptr)}');
  for (var i = 0; i < api.childCount(desktop, nullptr); i++) {
    final app = api.childAt(desktop, i, nullptr);
    if (app.address == 0) continue;
    final name = api.safeName(app);
    if (name.isEmpty || !name.contains('straight')) continue;
    print('APP "$name" windows=${api.childCount(app, nullptr)}');
    for (var w = 0; w < api.childCount(app, nullptr); w++) {
      final window = api.childAt(app, w, nullptr);
      if (window.address == 0) continue;
      print('   WINDOW name="${api.safeName(window)}"');
      _walk(window, api, '      ', 0, 'straight', []);
    }
  }
}

void _walk(Pointer<Void> node, _Api api, String indent, int depth,
    String target, List<String> path) {
  if (depth > 5) return;
  try {
    final n = api.safeName(node);
    if (n.isNotEmpty) print('$indent"$n"');
    final children = api.childCount(node, nullptr);
    for (var i = 0; i < children && i < 40; i++) {
      final child = api.childAt(node, i, nullptr);
      if (child.address == 0) continue;
      _walk(child, api, indent + '  ', depth + 1, target, path);
    }
  } catch (e) {
    // ignore bad nodes rather than crashing the whole probe
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
            'atspi_accessible_get_name');

  final int Function() init;
  final Pointer<Void> Function(int) getDesktop;
  final int Function(Pointer<Void>, Pointer<Void>?) childCount;
  final Pointer<Void> Function(Pointer<Void>, int, Pointer<Void>?) childAt;
  final Pointer<Utf8> Function(Pointer<Void>, Pointer<Void>?) nameOf;

  String safeName(Pointer<Void> node) {
    try {
      final raw = nameOf(node, nullptr);
      return raw.address == 0 ? '' : raw.toDartString();
    } catch (_) {
      return '';
    }
  }
}
