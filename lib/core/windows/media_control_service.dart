import 'dart:io';

import 'package:flutter/services.dart';

/// Controls the Windows system media session. The native side remembers
/// whether Straight performed the pause, so resume never starts unrelated
/// paused media.
class MediaControlService {
  static const _channel = MethodChannel('straight/media_control');

  Future<bool> pauseIfPlaying() async {
    if (!Platform.isWindows) return false;
    try {
      return await _channel.invokeMethod<bool>('pauseIfPlaying') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> resumeIfPausedByStraight() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod<void>('resumeIfPausedByStraight');
    } on PlatformException {
      // Dictation must not fail if an app closes its media session mid-speech.
    }
  }
}
