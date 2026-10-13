import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

enum AppCategory {
  code,     // VS Code, Cursor, Visual Studio, Terminal, IntelliJ
  chat,     // Slack, Teams, Discord, WhatsApp, Telegram
  browser,  // Chrome, Edge, Firefox, Brave, Arc
  document, // Word, Docs, Notepad, Obsidian, Notion
  general,
}

class ActiveWindowInfo {
  final int hwnd;
  final String title;
  final String processName;
  final AppCategory category;

  ActiveWindowInfo({
    required this.hwnd,
    required this.title,
    required this.processName,
    required this.category,
  });

  static AppCategory categorize(String processName) {
    final p = processName.toLowerCase();
    if (p.contains('code') ||
        p.contains('cursor') ||
        p.contains('idea') ||
        p.contains('devenv') ||
        p.contains('windowsterminal') ||
        p.contains('cmd') ||
        p.contains('powershell')) {
      return AppCategory.code;
    }
    if (p.contains('slack') ||
        p.contains('discord') ||
        p.contains('teams') ||
        p.contains('whatsapp') ||
        p.contains('telegram')) {
      return AppCategory.chat;
    }
    if (p.contains('chrome') ||
        p.contains('msedge') ||
        p.contains('firefox') ||
        p.contains('brave') ||
        p.contains('arc')) {
      return AppCategory.browser;
    }
    if (p.contains('winword') ||
        p.contains('notepad') ||
        p.contains('obsidian') ||
        p.contains('notion')) {
      return AppCategory.document;
    }
    return AppCategory.general;
  }
}

class WindowContext {
  /// Queries the current foreground window and identifies the active executable.
  static ActiveWindowInfo? getActiveWindow() {
    if (!Platform.isWindows) return null;

    try {
      final hwnd = GetForegroundWindow();
      if (hwnd == 0) return null;

      // 1. Get window title
      final titleBuffer = wsalloc(256);
      GetWindowText(hwnd, titleBuffer, 256);
      final title = titleBuffer.toDartString();
      free(titleBuffer);

      // 2. Get process ID
      final pidPtr = calloc<DWORD>();
      GetWindowThreadProcessId(hwnd, pidPtr);
      final pid = pidPtr.value;
      free(pidPtr);

      // 3. Query process image name
      String processName = '';
      final hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
      if (hProcess != NULL) {
        final pathBuffer = wsalloc(MAX_PATH);
        final sizePtr = calloc<DWORD>()..value = MAX_PATH;
        if (QueryFullProcessImageName(hProcess, 0, pathBuffer, sizePtr) != 0) {
          final fullPath = pathBuffer.toDartString();
          processName = fullPath.split(r'\').last.toLowerCase();
        }
        free(pathBuffer);
        free(sizePtr);
        CloseHandle(hProcess);
      }

      final category = ActiveWindowInfo.categorize(processName);
      return ActiveWindowInfo(
        hwnd: hwnd,
        title: title,
        processName: processName,
        category: category,
      );
    } catch (_) {
      return null;
    }
  }
}
