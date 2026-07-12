/*
 * qwen_asr_wrapper.c - Thin C ABI adapter for Dart FFI
 *
 * Dynamically loads the antirez/qwen-asr library at runtime and wraps
 * pointer-based signatures for Dart FFI consumption.
 *
 * Build: cmake .. && cmake --build . --config Release
 * Output: qwen_asr_wrapper.dll (placed in native/prebuilt/)
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
    HMODULE mod = LoadLibraryW(L"qwen_asr.dll");
    if (!mod) return 0;
#define LOAD(name) _q. name = (void*)GetProcAddress(mod, "qwen_" #name); if (!_q. name) return 0
#else
    void *mod = dlopen("libqwen_asr.so", RTLD_NOW | RTLD_GLOBAL);
    if (!mod) return 0;
#define LOAD(name) _q. name = (void*)dlsym(mod, "qwen_" #name); if (!_q. name) return 0
#endif
    LOAD(load);
    LOAD(free);
    LOAD(transcribe_audio);
    LOAD(transcribe);
    LOAD(set_token_callback);
    LOAD(set_prompt);
    LOAD(set_force_language);
    return 1;
#undef LOAD
}

/*
 * qwen_asr_wrapper_init: Load model from directory
 * Returns: opaque context pointer, or NULL on failure
 */
QWEN_WRAPPER_API qwen_ctx_t*
qwen_asr_wrapper_init(const char *model_dir) {
    if (!_q.loaded) { _q.loaded = _load_qwen_asr(); }
    if (!_q.loaded) return NULL;
    return _q.load(model_dir);
}

/*
 * qwen_asr_wrapper_free: Release all resources
 */
QWEN_WRAPPER_API void
qwen_asr_wrapper_free(qwen_ctx_t *ctx) {
    if (_q.loaded && ctx) _q.free(ctx);
}

/*
 * qwen_asr_wrapper_transcribe: Transcribe raw audio samples
 * samples: mono float32 array at 16kHz
 * n_samples: number of samples
 * Returns: allocated UTF-8 string (caller must free with qwen_asr_wrapper_free_string)
 */
QWEN_WRAPPER_API char*
qwen_asr_wrapper_transcribe(qwen_ctx_t *ctx, const float *samples, int n_samples) {
    if (!_q.loaded || !ctx) return NULL;
    return _q.transcribe_audio(ctx, samples, n_samples);
}

/*
 * qwen_asr_wrapper_transcribe_file: Transcribe a WAV file
 * Returns: allocated UTF-8 string (caller must free)
 */
QWEN_WRAPPER_API char*
qwen_asr_wrapper_transcribe_file(qwen_ctx_t *ctx, const char *wav_path) {
    if (!_q.loaded || !ctx) return NULL;
    return _q.transcribe(ctx, wav_path);
}

/*
 * qwen_asr_wrapper_free_string: Free a string returned by transcribe functions
 */
QWEN_WRAPPER_API void
qwen_asr_wrapper_free_string(char *str) {
    if (str) free(str);
}

/*
 * qwen_asr_wrapper_set_prompt: Set optional system prompt for biasing
 * Returns: 0 on success, -1 on error
 */
QWEN_WRAPPER_API int
qwen_asr_wrapper_set_prompt(qwen_ctx_t *ctx, const char *prompt) {
    if (!_q.loaded || !ctx) return -1;
    return _q.set_prompt(ctx, prompt);
}

/*
 * qwen_asr_wrapper_set_language: Set forced output language
 * Returns: 0 on success, -1 on error
 */
QWEN_WRAPPER_API int
qwen_asr_wrapper_set_language(qwen_ctx_t *ctx, const char *language) {
    if (!_q.loaded || !ctx) return -1;
    return _q.set_force_language(ctx, language);
}

/*
 * qwen_asr_wrapper_supported_languages: Get comma-separated list of supported languages
 */
QWEN_WRAPPER_API const char*
qwen_asr_wrapper_supported_languages(void) {
    /* This function is not in the dynamic loader, return a static string */
    return "Chinese,English,Cantonese,Arabic,German,French,Spanish,Portuguese,"
           "Indonesian,Italian,Korean,Russian,Thai,Vietnamese,Japanese,Turkish,"
           "Hindi,Malay,Dutch,Swedish,Danish,Finnish,Polish,Czech,Filipino,"
           "Persian,Greek,Hungarian,Macedonian,Romanian";
}
