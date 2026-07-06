#ifdef _WIN32
#define WHISPER_WRAPPER_API __declspec(dllexport)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#else
#define WHISPER_WRAPPER_API
#include <dlfcn.h>
#endif

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

struct whisper_context;
struct whisper_full_params;

enum whisper_sampling_strategy {
    WHISPER_SAMPLING_GREEDY,
    WHISPER_SAMPLING_BEAM_SEARCH,
};

static struct {
    struct whisper_context* (*init_from_file)(const char*);
    void (*free)(struct whisper_context*);
    struct whisper_full_params* (*default_params_by_ref)(int);
    int (*full)(struct whisper_context*, struct whisper_full_params, const float*, int);
    int (*full_n_segments)(struct whisper_context*);
    const char* (*full_get_segment_text)(struct whisper_context*, int);
    const char* (*print_system_info)(void);
    void (*free_params)(struct whisper_full_params*);
    int loaded;
} _w = {0};

static int _load_whisper(void) {
#ifdef _WIN32
    HMODULE mod = LoadLibraryW(L"whisper.dll");
    if (!mod) return 0;
#define LOAD(name) _w. name = (void*)GetProcAddress(mod, "whisper_" #name); if (!_w. name) return 0
#else
    void* mod = dlopen("libwhisper.so", RTLD_NOW | RTLD_GLOBAL);
    if (!mod) return 0;
#define LOAD(name) _w. name = (void*)dlsym(mod, "whisper_" #name); if (!_w. name) return 0
#endif
    LOAD(init_from_file);
    LOAD(free);
    LOAD(default_params_by_ref);
    LOAD(full);
    LOAD(full_n_segments);
    LOAD(full_get_segment_text);
    LOAD(print_system_info);
    LOAD(free_params);
    return 1;
}

WHISPER_WRAPPER_API struct whisper_context*
whisper_wrapper_init(const char* path_model) {
    if (!_w.loaded) { _w.loaded = _load_whisper(); }
    if (!_w.loaded) return NULL;
    return _w.init_from_file(path_model);
}

WHISPER_WRAPPER_API void
whisper_wrapper_free(struct whisper_context* ctx) {
    if (_w.loaded) _w.free(ctx);
}

WHISPER_WRAPPER_API struct whisper_full_params*
whisper_wrapper_default_params(int strategy) {
    if (!_w.loaded) { _w.loaded = _load_whisper(); }
    if (!_w.loaded) return NULL;
    return _w.default_params_by_ref(strategy);
}

WHISPER_WRAPPER_API void
whisper_wrapper_free_params(struct whisper_full_params* params) {
    if (_w.loaded) _w.free_params(params);
}

WHISPER_WRAPPER_API int
whisper_wrapper_full(struct whisper_context* ctx,
                     struct whisper_full_params* params,
                     const float* samples,
                     int n_samples) {
    if (!_w.loaded) return -1;
    return _w.full(ctx, *params, samples, n_samples);
}

WHISPER_WRAPPER_API int
whisper_wrapper_n_segments(struct whisper_context* ctx) {
    if (!_w.loaded) return -1;
    return _w.full_n_segments(ctx);
}

WHISPER_WRAPPER_API const char*
whisper_wrapper_segment_text(struct whisper_context* ctx, int i_segment) {
    if (!_w.loaded) return NULL;
    return _w.full_get_segment_text(ctx, i_segment);
}

WHISPER_WRAPPER_API const char*
whisper_wrapper_system_info(void) {
    if (!_w.loaded) { _w.loaded = _load_whisper(); }
    if (!_w.loaded) return NULL;
    return _w.print_system_info();
}
