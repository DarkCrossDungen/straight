import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Reads the keyboard below the compositor so a shortcut can tell a hold from
/// a tap.
///
/// Wayland never delivers a key release to an application, and a desktop custom
/// shortcut only reports "pressed". The raw event devices do carry releases, so
/// hold-to-record is possible only with read access to /dev/input, which
/// `InputAccess` grants once per machine.
class KeyboardWatcher {
  KeyboardWatcher._(this._isolate, this._receiver, this._control) {
    _receiver.listen((message) {
      if (message is! List<int> || _events.isClosed) return;
      _events.add(KeyboardEvent(message[0] == 1, message[1]));
    });
  }

  final Isolate _isolate;
  final ReceivePort _receiver;
  final SendPort _control;
  final StreamController<KeyboardEvent> _events =
      StreamController<KeyboardEvent>.broadcast();

  Stream<KeyboardEvent> get events => _events.stream;

  /// Starts a reader, or returns null when no event device can be opened.
  static Future<KeyboardWatcher?> start(HotkeySpec spec) async {
    final receiver = ReceivePort();
    final controlPort = Completer<SendPort?>();
    Isolate? isolate;
    receiver.listen((message) {
      if (message is SendPort) {
        if (!controlPort.isCompleted) controlPort.complete(message);
      } else if (message == null && !controlPort.isCompleted) {
        controlPort.complete(null);
      }
    });

    try {
      isolate = await Isolate.spawn(
        _readKeyboard,
        (receiver.sendPort, spec.encode()),
        errorsAreFatal: false,
      );
      final announced = await controlPort.future.timeout(
        const Duration(seconds: 3),
      );
      if (announced == null) {
        receiver.close();
        isolate.kill(priority: Isolate.immediate);
        return null;
      }
      return KeyboardWatcher._(isolate, receiver, announced);
    } catch (_) {
      receiver.close();
      isolate?.kill(priority: Isolate.immediate);
      return null;
    }
  }

  /// Retargets the reader; the combination is matched inside the reader thread,
  /// so only a finished press or release reaches the app.
  void updateSpec(HotkeySpec spec) => _control.send(spec.encode());

  Future<void> dispose() async {
    _control.send(const [-1]);
    await _events.close();
    _receiver.close();
    _isolate.kill(priority: Isolate.immediate);
  }
}

const _eventBytes = 24;
const _batchEvents = 64;

class KeyboardEvent {
  const KeyboardEvent(this.isDown, this.keyCode);

  final bool isDown;
  final int keyCode;
}

/// The combination the reader watches for, expressed as evdev key codes.
class HotkeySpec {
  HotkeySpec({required this.keyCode, required this.modifierGroups});

  HotkeySpec.fromSettings(Map hotkey)
    : keyCode = evdevKeyCode((hotkey['key'] ?? 'Space').toString()),
      modifierGroups = [
        if (hotkey['alt'] == true) const [56, 64],
        if (hotkey['ctrl'] == true) const [29, 97],
        if (hotkey['shift'] == true) const [42, 54],
        if (hotkey['meta'] == true) const [125, 126],
      ];

  final int keyCode;

  /// One entry per modifier, each listing the left and right code that satisfy
  /// it, so either Alt works.
  final List<List<int>> modifierGroups;

  /// [keyCode, group count, then each group prefixed by its size].
  List<int> encode() => [
    keyCode,
    modifierGroups.length,
    for (final group in modifierGroups) ...[group.length, ...group],
  ];
}

List<List<int>> _decodeGroups(List<int> encoded) {
  final groups = <List<int>>[];
  var cursor = 2;
  for (var index = 0; index < encoded[1]; index++) {
    final size = encoded[cursor++];
    groups.add(encoded.sublist(cursor, cursor + size));
    cursor += size;
  }
  return groups;
}

/// evdev key codes for the labels the hotkey capture widget can produce.
int evdevKeyCode(String label) {
  switch (label.toLowerCase()) {
    case 'space':
      return 57;
    case 'enter':
      return 28;
    case 'tab':
      return 15;
    case 'escape':
      return 1;
    default:
      if (label.length != 1) return 57;
      final unit = label.toUpperCase().codeUnitAt(0);
      if (unit >= 65 && unit <= 90) return _alphabet[unit - 65];
      if (unit >= 49 && unit <= 57) return unit - 47;
      if (unit == 48) return 11;
      return 57;
  }
}

/// A-Z in order, from linux/input-event-codes.h.
const _alphabet = [
  30, 48, 46, 32, 18, 33, 34, 35, 23, 36, 37, 38, 50,
  49, 24, 25, 16, 19, 31, 20, 22, 47, 17, 45, 21, 44,
];

void _readKeyboard((SendPort, List<int>) bootstrap) {
  final (toApp, encodedSpec) = bootstrap;
  final fromApp = ReceivePort();
  final libc = DynamicLibrary.process();
  final open = libc.lookupFunction<
    Int32 Function(Pointer<Utf8>, Int32),
    int Function(Pointer<Utf8>, int)
  >('open');
  final read = libc.lookupFunction<
    IntPtr Function(Int32, Pointer<Uint8>, IntPtr),
    int Function(int, Pointer<Uint8>, int)
  >('read');
  final close = libc.lookupFunction<
    Int32 Function(Int32),
    int Function(int)
  >('close');
  final nanosleep = libc.lookupFunction<
    Int32 Function(Pointer<Long>, Pointer<Long>),
    int Function(Pointer<Long>, Pointer<Long>)
  >('nanosleep');

  final devices = <int>[];
  try {
    for (final entry in Directory(deviceDirectory).listSync()) {
      final name = entry.uri.pathSegments.last;
      if (!name.startsWith('event')) continue;
      final path = '$deviceDirectory/$name'.toNativeUtf8();
      // O_RDONLY with O_NONBLOCK, so one quiet keyboard cannot stall this
      // thread and leave press/release events stuck in the queue.
      final fd = open(path, 2048);
      calloc.free(path);
      if (fd >= 0) devices.add(fd);
    }
  } catch (_) {
    devices.clear();
  }
  if (devices.isEmpty) {
    toApp.send(null);
    fromApp.close();
    return;
  }

  var target = encodedSpec[0];
  var groups = _decodeGroups(encodedSpec);
  var watching = false;
  var running = true;
  final held = <int>{};
  final buffer = calloc<Uint8>(_eventBytes * _batchEvents);
  final byteView = buffer.asTypedList(_eventBytes * _batchEvents);
  final nap = calloc<Long>(2);
  nap[0] = 0;
  nap[1] = 6000000;

  fromApp.listen((message) {
    if (message is List<int>) {
      if (message.length == 1 && message[0] == -1) {
        running = false;
      } else {
        target = message[0];
        groups = _decodeGroups(message);
      }
    }
  });

  toApp.send(fromApp.sendPort);

  while (running) {
    var changed = false;
    for (final fd in devices) {
      final count = read(fd, buffer, _eventBytes * _batchEvents);
      if (count < _eventBytes) continue;
      final reader = ByteData.sublistView(byteView, 0, count);
      for (
        var offset = 0;
        offset + _eventBytes <= count;
        offset += _eventBytes
      ) {
        // A struct input_event is a timeval, then type, code, value.
        final type = reader.getUint16(offset + 16, Endian.host);
        final code = reader.getUint16(offset + 18, Endian.host);
        final value = reader.getInt32(offset + 20, Endian.host);
        if (type != 1) continue; // EV_KEY
        if (value == 0) {
          held.remove(code);
        } else {
          held.add(code);
        }
        changed = true;
      }
    }

    if (changed) {
      final down =
          held.contains(target) &&
          groups.every((group) => group.any(held.contains));
      if (down != watching) {
        watching = down;
        toApp.send([down ? 1 : 0, target]);
      }
    }
    nanosleep(nap, nap);
  }

  for (final fd in devices) {
    close(fd);
  }
  calloc.free(buffer);
  calloc.free(nap);
  fromApp.close();
}

const deviceDirectory = '/dev/input';
