/*
 * xtype - type text into the focused window through XTEST.
 *
 * AT-SPI is the right path when the target app exposes an editable accessible
 * object, but GTK4 builds on this system link no AT-SPI bridge and Electron and
 * Chromium apps expose no web-content tree, so there is nothing to insert into.
 * Those apps are almost always X11 or XWayland clients, and the compositor
 * routes XTEST input as real key presses, so synthesising keys reaches them.
 *
 * Usage:
 *   xtype [--focus-pid N] TEXT    type TEXT into the focused window, giving X
 *                                 focus to the window owned by pid N first
 *   xtype --paste                 type Ctrl+V, for text the caller put on the
 *                                 clipboard
 *   xtype --can-type              exit 0 when a display and keymap are usable
 *
 * Prints one line and exits 0 only on success:
 *   TYPED <n>        n characters were sent
 *   PASTED           Ctrl+V was sent
 *   MISSING <n> U+X  codepoint n has no key on this keymap (caller should paste)
 *   NOFOCUS <pid>    no X window is owned by that pid (the app is Wayland-only)
 *   NODISPLAY        no reachable X display
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <X11/extensions/XTest.h>

static Display *dpy;

static void press(KeyCode code, int down) {
  XTestFakeKeyEvent(dpy, code, down, CurrentTime);
  XSync(dpy, False);
  usleep(4000);
}

static void tap(KeyCode code) {
  press(code, 1);
  press(code, 0);
}

/* Finds the keycode that produces keysym, and whether Shift is required. */
static int lookup(KeySym sym, KeyCode *code_out, int *shift_out) {
  int min_kc = 0, max_kc = 0, per = 0;
  XDisplayKeycodes(dpy, &min_kc, &max_kc);
  KeySym *table = XGetKeyboardMapping(dpy, min_kc, max_kc - min_kc + 1, &per);
  if (!table) return 0;
  if (per < 1) per = 1;
  int found = 0;
  for (int kc = min_kc; kc <= max_kc; kc++) {
    for (int col = 0; col < per; col++) {
      if (table[(kc - min_kc) * per + col] == sym) {
        *code_out = (KeyCode)kc;
        *shift_out = (col % 2) == 1;
        found = 1;
        break;
      }
    }
    if (found) break;
  }
  XFree(table);
  return found;
}

static Window window_for_pid(unsigned long pid) {
  unsigned char *prop = NULL;
  Atom type;
  unsigned long nitems = 0, after = 0;
  int format = 0;
  Atom client_list = XInternAtom(dpy, "_NET_CLIENT_LIST_STACKING", True);
  if (client_list == None) return 0;
  if (XGetWindowProperty(dpy, DefaultRootWindow(dpy), client_list, 0, 1024,
          False, XA_WINDOW, &type, &format, &nitems, &after, &prop) != Success ||
      !prop) {
    return 0;
  }
  Window *list = (Window *)prop;
  Window hit = 0;
  for (unsigned long i = 0; i < nitems && i < 1024; i++) {
    unsigned char *pp = NULL;
    unsigned long n = 0, a = 0;
    int f = 0;
    Atom t;
    if (XGetWindowProperty(dpy, list[i],
            XInternAtom(dpy, "_NET_WM_PID", True), 0, 1, False, XA_CARDINAL, &t,
            &f, &n, &a, &pp) == Success && pp) {
      if (*(unsigned long *)pp == pid) {
        hit = list[i];
        XFree(pp);
        break;
      }
      XFree(pp);
    }
  }
  XFree(prop);
  return hit;
}

static int type_utf8(const char *text, size_t len) {
  KeyCode shift_code = XKeysymToKeycode(dpy, XK_Shift_L);
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
      printf("MISSING %d 0x%02X\n", typed, c);
      return 1;
    }

    KeySym sym = (cp == '\n' || cp == '\r') ? XK_Return : (KeySym)cp;
    KeyCode code;
    int shift = 0;
    if (!lookup(sym, &code, &shift)) {
      printf("MISSING %d U+%04X\n", typed, cp);
      return 1;
    }
    if (shift && shift_code) press(shift_code, 1);
    tap(code);
    if (shift && shift_code) press(shift_code, 0);
    typed++;
    i += (size_t)adv;
  }
  printf("TYPED %d\n", typed);
  return 0;
}

static int paste(void) {
  KeyCode ctrl = XKeysymToKeycode(dpy, XK_Control_L);
  KeyCode v = XKeysymToKeycode(dpy, XK_v);
  if (!ctrl || !v) {
    printf("NODISPLAY\n");
    return 1;
  }
  press(ctrl, 1);
  tap(v);
  press(ctrl, 0);
  printf("PASTED\n");
  return 0;
}

int main(int argc, char **argv) {
  unsigned long focus_pid = 0;
  int want_paste = 0;
  int can_type = 0;
  const char *text = NULL;
  for (int i = 1; i < argc; i++) {
    if (!strcmp(argv[i], "--focus-pid") && i + 1 < argc) {
      focus_pid = strtoul(argv[++i], NULL, 10);
    } else if (!strcmp(argv[i], "--paste")) {
      want_paste = 1;
    } else if (!strcmp(argv[i], "--can-type")) {
      can_type = 1;
    } else {
      text = argv[i];
    }
  }
  if (!text && !want_paste && !can_type) {
    fprintf(stderr, "usage: xtype [--focus-pid N] TEXT | xtype --paste\n");
    return 1;
  }

  dpy = XOpenDisplay(NULL);
  if (!dpy) {
    printf("NODISPLAY\n");
    return 1;
  }
  if (can_type) {
    int min_kc = 0, max_kc = 0, per = 0;
    XDisplayKeycodes(dpy, &min_kc, &max_kc);
    XGetKeyboardMapping(dpy, min_kc, max_kc - min_kc + 1, &per);
    printf("OK\n");
    XCloseDisplay(dpy);
    return 0;
  }
  if (focus_pid) {
    Window w = window_for_pid(focus_pid);
    if (!w) {
      printf("NOFOCUS %lu\n", focus_pid);
      XCloseDisplay(dpy);
      return 1;
    }
    XSetInputFocus(dpy, w, RevertToParent, CurrentTime);
    XSync(dpy, False);
    usleep(80000);
  }
  int rc = want_paste ? paste() : type_utf8(text, strlen(text));
  XSync(dpy, False);
  XCloseDisplay(dpy);
  return rc;
}
