/*
 * qwen_asr_wrapper.c - Thin C ABI adapter for Dart FFI
 *
 * Dynamically loads the antirez/qwen-asr library at runtime and wraps
 * pointer-based signatures for Dart FFI consumption.
 */

#ifdef _WIN32
#define QWEN_WRAPPER_API __declspec(dllexport)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#else
#define QWEN_WRAPPER_API
#include <dlfcn.h>
#endif

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* Forward declare the opaque context type */
typedef struct qwen_ctx qwen_ctx_t;

/* Token callback type from the original API */
typedef void (*qwen_token_cb)(const char *piece, void *userdata);

static char _last_error[512] = "";

static void _set_error(const char *message) {
    snprintf(_last_error, sizeof(_last_error), "%s", message ? message : "unknown error");
}
static char* _copy_result_string(const char *source) {
    if (!source) return NULL;
    size_t len = strlen(source);
    char *copy = (char*)malloc(len + 1);
    if (!copy) {
        _set_error("malloc failed while copying result string");
        return NULL;
    }
    memcpy(copy, source, len + 1);
    return copy;
}

#ifdef _WIN32
static void _set_windows_error(const char *prefix) {
    DWORD err = GetLastError();
    snprintf(_last_error, sizeof(_last_error), "%s (GetLastError=%lu)", prefix, (unsigned long)err);
}
#endif

/* Dynamically loaded function pointers */
static struct {
    qwen_ctx_t* (*load)(const char *model_dir);
    void (*free)(qwen_ctx_t *ctx);
    char* (*transcribe_audio)(qwen_ctx_t *ctx, const float *samples, int n_samples);
    char* (*transcribe)(qwen_ctx_t *ctx, const char *wav_path);
    void (*set_token_callback)(qwen_ctx_t *ctx, qwen_token_cb cb, void *userdata);
    int (*set_prompt)(qwen_ctx_t *ctx, const char *prompt);
    int (*set_force_language)(qwen_ctx_t *ctx, const char *language);
    int loaded;
} _q = {0};

static int _load_qwen_asr(void) {
#ifdef _WIN32
    HMODULE mod = NULL;
    HMODULE wrapper = NULL;
    wchar_t dll_path[MAX_PATH];

    if (GetModuleHandleExW(
            GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
            (LPCWSTR)&_load_qwen_asr,
            &wrapper)) {
        DWORD len = GetModuleFileNameW(wrapper, dll_path, MAX_PATH);
        if (len > 0 && len < MAX_PATH) {
            wchar_t *slash = wcsrchr(dll_path, L'\\');
            if (slash) {
                *(slash + 1) = L'\0';
                SetDllDirectoryW(dll_path);
                wcsncat_s(dll_path, MAX_PATH, L"qwen_asr.dll", _TRUNCATE);
                mod = LoadLibraryW(dll_path);
            }
        }
    }

    if (!mod) {
        mod = LoadLibraryW(L"qwen_asr.dll");
    }
    if (!mod) {
        _set_windows_error("LoadLibraryW(qwen_asr.dll) failed");
        return 0;
    }
#define LOAD(name) \
    _q.name = (void*)GetProcAddress(mod, "qwen_" #name); \
    if (!_q.name) { \
        snprintf(_last_error, sizeof(_last_error), "Missing export: qwen_%s", #name); \
        return 0; \
    }
#else
    void *mod = dlopen("libqwen_asr.so", RTLD_NOW | RTLD_GLOBAL);
    if (!mod) {
        _set_error(dlerror());
        return 0;
    }
#define LOAD(name) \
    _q.name = (void*)dlsym(mod, "qwen_" #name); \
    if (!_q.name) { \
        snprintf(_last_error, sizeof(_last_error), "Missing export: qwen_%s", #name); \
        return 0; \
    }
#endif
    LOAD(load);
    LOAD(free);
    LOAD(transcribe_audio);
    LOAD(transcribe);
    LOAD(set_token_callback);
    LOAD(set_prompt);
    LOAD(set_force_language);
    _set_error("");
    return 1;
#undef LOAD
}

QWEN_WRAPPER_API const char*
qwen_asr_wrapper_last_error(void) {
    return _last_error;
}

QWEN_WRAPPER_API qwen_ctx_t*
qwen_asr_wrapper_init(const char *model_dir) {
    if (!_q.loaded) { _q.loaded = _load_qwen_asr(); }
    if (!_q.loaded) return NULL;
    qwen_ctx_t *ctx = _q.load(model_dir);
    if (!ctx) {
        snprintf(_last_error, sizeof(_last_error), "qwen_load returned NULL for model dir: %s", model_dir ? model_dir : "(null)");
    }
    return ctx;
}

QWEN_WRAPPER_API void
qwen_asr_wrapper_free(qwen_ctx_t *ctx) {
    if (_q.loaded && ctx) _q.free(ctx);
}

QWEN_WRAPPER_API char*
qwen_asr_wrapper_transcribe(qwen_ctx_t *ctx, const float *samples, int n_samples) {
    if (!_q.loaded || !ctx) return NULL;
    return _copy_result_string(_q.transcribe_audio(ctx, samples, n_samples));
}

QWEN_WRAPPER_API char*
qwen_asr_wrapper_transcribe_file(qwen_ctx_t *ctx, const char *wav_path) {
    if (!_q.loaded || !ctx) return NULL;
    return _copy_result_string(_q.transcribe(ctx, wav_path));
}

QWEN_WRAPPER_API void
qwen_asr_wrapper_free_string(char *str) {
    if (str) free(str);
}

QWEN_WRAPPER_API int
qwen_asr_wrapper_set_prompt(qwen_ctx_t *ctx, const char *prompt) {
    if (!_q.loaded || !ctx) return -1;
    return _q.set_prompt(ctx, prompt);
}

QWEN_WRAPPER_API int
qwen_asr_wrapper_set_language(qwen_ctx_t *ctx, const char *language) {
    if (!_q.loaded || !ctx) return -1;
    return _q.set_force_language(ctx, language);
}

QWEN_WRAPPER_API const char*
qwen_asr_wrapper_supported_languages(void) {
    return "Chinese,English,Cantonese,Arabic,German,French,Spanish,Portuguese,"
           "Indonesian,Italian,Korean,Russian,Thai,Vietnamese,Japanese,Turkish,"
           "Hindi,Malay,Dutch,Swedish,Danish,Finnish,Polish,Czech,Filipino,"
           "Persian,Greek,Hungarian,Macedonian,Romanian";
}


