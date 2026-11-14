/*
 * ktype - type text through a temporary kernel virtual keyboard.
 *
 * XTEST only reaches X11 and XWayland clients, and AT-SPI needs the target app
 * to expose an editable accessible object. Apps that are neither - GTK4 apps
 * and native-Wayland Chromium builds - can still be typed into at the kernel
 * level: the compositor sees a real keyboard, so it dispatches to whatever
 * window has focus.
 *
 * Needs write access to /dev/uinput. Prints NOPERM and exits 1 when the device
 * is not usable, so the caller can tell the user what to grant instead of
 * silently dropping the transcript.
 *
 * Usage: ktype TEXT      prints TYPED <n>, MISSING <U+...,  or NOPERM
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <linux/input.h>
#include <linux/uinput.h>

static int fd = -1;

static void emit(int type, int code, int value) {
  struct input_event ev;
  memset(&ev, 0, sizeof(ev));
  ev.type = type;
  ev.code = code;
  ev.value = value;
  if (write(fd, &ev, sizeof(ev)) < 0) {
    /* keep going: a dropped event only loses a key press */
  }
}

static void key(int code, int value) {
  emit(EV_KEY, code, value);
  emit(EV_SYN, SYN_REPORT, 0);
}

static void tap(int code, int shift) {
  if (shift) key(KEY_LEFTSHIFT, 1);
  key(code, 1);
  key(code, 0);
  if (shift) key(KEY_LEFTSHIFT, 0);
}

/* Lowercase ASCII plus the punctuation that sits on a shifted US key. */
static int keycode_for(unsigned int cp, int *shift) {
  *shift = 0;
  if (cp >= 'a' && cp <= 'z') return KEY_A + (int)(cp - 'a');
  if (cp >= 'A' && cp <= 'Z') {
    *shift = 1;
    return KEY_A + (int)(cp - 'A');
  }
  if (cp >= '1' && cp <= '9') return KEY_1 + (int)(cp - '1');
  if (cp == '0') return KEY_0;
  switch (cp) {
    case ' ': return KEY_SPACE;
    case '\n':
    case '\r': return KEY_ENTER;
    case '-': return KEY_MINUS;
    case '=': return KEY_EQUAL;
    case '[': return KEY_LEFTBRACE;
    case ']': return KEY_RIGHTBRACE;
    case '\\': return KEY_BACKSLASH;
    case ';': return KEY_SEMICOLON;
    case '\'': return KEY_APOSTROPHE;
    case '`': return KEY_GRAVE;
    case ',': return KEY_COMMA;
    case '.': return KEY_DOT;
    case '/': return KEY_SLASH;
    case '\t': return KEY_TAB;
    case 8:
    case 127: return KEY_BACKSPACE;
    /* shifted symbols */
    case '!': *shift = 1; return KEY_1;
    case '@': *shift = 1; return KEY_2;
    case '#': *shift = 1; return KEY_3;
    case '$': *shift = 1; return KEY_4;
    case '%': *shift = 1; return KEY_5;
    case '^': *shift = 1; return KEY_6;
    case '&': *shift = 1; return KEY_7;
    case '*': *shift = 1; return KEY_8;
    case '(': *shift = 1; return KEY_9;
    case ')': *shift = 1; return KEY_0;
    case '_': *shift = 1; return KEY_MINUS;
    case '+': *shift = 1; return KEY_EQUAL;
    case '{': *shift = 1; return KEY_LEFTBRACE;
    case '}': *shift = 1; return KEY_RIGHTBRACE;
    case '|': *shift = 1; return KEY_BACKSLASH;
    case ':': *shift = 1; return KEY_SEMICOLON;
    case '"': *shift = 1; return KEY_APOSTROPHE;
    case '~': *shift = 1; return KEY_GRAVE;
    case '<': *shift = 1; return KEY_COMMA;
    case '>': *shift = 1; return KEY_DOT;
    case '?': *shift = 1; return KEY_SLASH;
    default: return -1;
  }
}

int main(int argc, char **argv) {
  const char *text = argc > 1 ? argv[1] : NULL;
  if (!text) {
    fprintf(stderr, "usage: ktype TEXT\n");
    return 1;
  }

  fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
  if (fd < 0) {
    printf("NOPERM\n");
    return 1;
  }

  ioctl(fd, UI_SET_EVBIT, EV_KEY);
  ioctl(fd, UI_SET_EVBIT, EV_SYN);
  for (int c = KEY_ESC; c <= KEY_MAX; c++) ioctl(fd, UI_SET_KEYBIT, c);
  ioctl(fd, UI_SET_KEYBIT, KEY_LEFTSHIFT);

  struct uinput_setup setup;
  memset(&setup, 0, sizeof(setup));
  snprintf(setup.name, sizeof(setup.name), "Straight virtual keyboard");
  setup.id.bustype = BUS_USB;
  setup.id.vendor = 0x1d6b;
  setup.id.product = 0x0001;
  setup.id.version = 1;
  if (ioctl(fd, UI_DEV_SETUP, &setup) < 0 || ioctl(fd, UI_DEV_CREATE) < 0) {
    printf("NOPERM\n");
    close(fd);
    return 1;
  }
  /* the device needs a moment before the compositor will route to it */
  usleep(150000);

  size_t len = strlen(text);
  int typed = 0;
  for (size_t i = 0; i < len;) {
    unsigned int cp;
    int adv;
    unsigned char c = (unsigned char)text[i];
    if (c < 0x80) {
      cp = c;
      adv = 1;
    } else if ((c & 0xE0) == 0xC0 && i + 1 < len) {
      cp = ((c & 0x1F) << 6) | (text[i + 1] & 0x3F);
      adv = 2;
    } else if ((c & 0xF0) == 0xE0 && i + 2 < len) {
      cp = ((c & 0x0F) << 12) | ((text[i + 1] & 0x3F) << 6) | (text[i + 2] & 0x3F);
      adv = 3;
    } else if ((c & 0xF8) == 0xF0 && i + 3 < len) {
      cp = ((c & 0x07) << 18) | ((text[i + 1] & 0x3F) << 12) |
           ((text[i + 2] & 0x3F) << 6) | (text[i + 3] & 0x3F);
      adv = 4;
    } else {
      break;
    }
    int shift = 0;
    int code = keycode_for(cp, &shift);
    if (code < 0) {
      printf("MISSING %d U+%04X\n", typed, cp);
      ioctl(fd, UI_DEV_DESTROY);
      close(fd);
      return 1;
    }
    tap(code, shift);
    usleep(6000);
    typed++;
    i += (size_t)adv;
  }
  ioctl(fd, UI_DEV_DESTROY);
  close(fd);
  printf("TYPED %d\n", typed);
  return 0;
}
