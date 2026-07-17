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

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

struct whisper_context;
struct whisper_state;
struct whisper_full_params;

typedef int32_t whisper_pos;
typedef int32_t whisper_token;
typedef int32_t whisper_seq_id;

enum whisper_sampling_strategy {
    WHISPER_SAMPLING_GREEDY,
    WHISPER_SAMPLING_BEAM_SEARCH,
};

enum whisper_gretype {
    WHISPER_GRETYPE_END = 0,
    WHISPER_GRETYPE_ALT = 1,
    WHISPER_GRETYPE_RULE_REF = 2,
    WHISPER_GRETYPE_CHAR = 3,
    WHISPER_GRETYPE_CHAR_NOT = 4,
    WHISPER_GRETYPE_CHAR_RNG_UPPER = 5,
    WHISPER_GRETYPE_CHAR_ALT = 6,
};

typedef struct whisper_grammar_element {
    enum whisper_gretype type;
    uint32_t value;
} whisper_grammar_element;

typedef struct whisper_token_data {
    whisper_token id;
    whisper_token tid;
    float p;
    float plog;
    float pt;
    float ptsum;
    int64_t t0;
    int64_t t1;
    int64_t t_dtw;
    float vlen;
} whisper_token_data;

typedef struct whisper_vad_params {
    float threshold;
    int min_speech_duration_ms;
    int min_silence_duration_ms;
    float max_speech_duration_s;
    int speech_pad_ms;
    float samples_overlap;
} whisper_vad_params;

typedef void (*whisper_new_segment_callback)(struct whisper_context *, struct whisper_state *, int, void *);
typedef void (*whisper_progress_callback)(struct whisper_context *, struct whisper_state *, int, void *);
typedef bool (*whisper_encoder_begin_callback)(struct whisper_context *, struct whisper_state *, void *);
typedef bool (*ggml_abort_callback)(void *);
typedef void (*whisper_logits_filter_callback)(
    struct whisper_context *, struct whisper_state *, const whisper_token_data *, int, float *, void *);

struct whisper_full_params {
    enum whisper_sampling_strategy strategy;
    int n_threads;
    int n_max_text_ctx;
    int offset_ms;
    int duration_ms;

    bool translate;
    bool no_context;
    bool no_timestamps;
    bool single_segment;
    bool print_special;
    bool print_progress;
    bool print_realtime;
    bool print_timestamps;

    bool token_timestamps;
    float thold_pt;
    float thold_ptsum;
    int max_len;
    bool split_on_word;
    int max_tokens;

    bool debug_mode;
    int audio_ctx;
    bool tdrz_enable;

    const char * suppress_regex;
    const char * initial_prompt;
    bool carry_initial_prompt;
    const whisper_token * prompt_tokens;
    int prompt_n_tokens;

    const char * language;
    bool detect_language;

    bool suppress_blank;
    bool suppress_nst;

    float temperature;
    float max_initial_ts;
    float length_penalty;

    float temperature_inc;
    float entropy_thold;
    float logprob_thold;
    float no_speech_thold;

    struct { int best_of; } greedy;
    struct { int beam_size; float patience; } beam_search;

    whisper_new_segment_callback new_segment_callback;
    void * new_segment_callback_user_data;

    whisper_progress_callback progress_callback;
    void * progress_callback_user_data;

    whisper_encoder_begin_callback encoder_begin_callback;
    void * encoder_begin_callback_user_data;

    ggml_abort_callback abort_callback;
    void * abort_callback_user_data;

    whisper_logits_filter_callback logits_filter_callback;
    void * logits_filter_callback_user_data;

    const whisper_grammar_element ** grammar_rules;
    size_t n_grammar_rules;
    size_t i_start_rule;
    float grammar_penalty;

    bool vad;
    const char * vad_model_path;
    whisper_vad_params vad_params;
};

static char _last_error[512] = "";
static char _initial_prompt[4096] = "";

static void _set_error(const char *message) {
    snprintf(_last_error, sizeof(_last_error), "%s", message ? message : "unknown error");
}

#ifdef _WIN32
static void _set_windows_error(const char *prefix) {
    DWORD err = GetLastError();
    snprintf(_last_error, sizeof(_last_error), "%s (GetLastError=%lu)", prefix, (unsigned long)err);
}
#endif

static struct {
    struct whisper_context* (*init_from_file)(const char*);
    void (*free)(struct whisper_context*);
    struct whisper_full_params* (*full_default_params_by_ref)(int);
    int (*full)(struct whisper_context*, struct whisper_full_params, const float*, int);
    int (*full_n_segments)(struct whisper_context*);
    const char* (*full_get_segment_text)(struct whisper_context*, int);
    const char* (*print_system_info)(void);
    void (*free_params)(struct whisper_full_params*);
    int loaded;
} _w = {0};

static int _load_whisper(void) {
#ifdef _WIN32
    HMODULE mod = NULL;
    HMODULE wrapper = NULL;
    wchar_t dll_path[MAX_PATH];

    if (GetModuleHandleExW(
            GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
            (LPCWSTR)&_load_whisper,
            &wrapper)) {
        DWORD len = GetModuleFileNameW(wrapper, dll_path, MAX_PATH);
        if (len > 0 && len < MAX_PATH) {
            wchar_t *slash = wcsrchr(dll_path, L'\\');
            if (slash) {
                *(slash + 1) = L'\0';
                SetDllDirectoryW(dll_path);
                wcsncat_s(dll_path, MAX_PATH, L"whisper.dll", _TRUNCATE);
                mod = LoadLibraryW(dll_path);
            }
        }
    }

    if (!mod) mod = LoadLibraryW(L"whisper.dll");
    if (!mod) {
        _set_windows_error("LoadLibraryW(whisper.dll) failed");
        return 0;
    }
#define LOAD(name) \
    _w.name = (void*)GetProcAddress(mod, "whisper_" #name); \
    if (!_w.name) { \
        snprintf(_last_error, sizeof(_last_error), "Missing export: whisper_%s", #name); \
        return 0; \
    }
#else
    void* mod = dlopen("libwhisper.so", RTLD_NOW | RTLD_GLOBAL);
    if (!mod) {
        _set_error(dlerror());
        return 0;
    }
#define LOAD(name) \
    _w.name = (void*)dlsym(mod, "whisper_" #name); \
    if (!_w.name) { \
        snprintf(_last_error, sizeof(_last_error), "Missing export: whisper_%s", #name); \
        return 0; \
    }
#endif
    LOAD(init_from_file);
    LOAD(free);
    _w.full_default_params_by_ref = (void*)GetProcAddress(mod, "whisper_full_default_params_by_ref");
    if (!_w.full_default_params_by_ref) {
        snprintf(_last_error, sizeof(_last_error), "Missing export: whisper_full_default_params_by_ref");
        return 0;
    }
    LOAD(full);
    LOAD(full_n_segments);
    LOAD(full_get_segment_text);
    LOAD(print_system_info);
    LOAD(free_params);
    _set_error("");
    return 1;
#undef LOAD
}

WHISPER_WRAPPER_API const char*
whisper_wrapper_last_error(void) {
    return _last_error;
}

WHISPER_WRAPPER_API void
whisper_wrapper_set_initial_prompt(const char* prompt) {
    if (!prompt) {
        _initial_prompt[0] = '\0';
        return;
    }
    snprintf(_initial_prompt, sizeof(_initial_prompt), "%s", prompt);
}

WHISPER_WRAPPER_API struct whisper_context*
whisper_wrapper_init(const char* path_model) {
    if (!_w.loaded) { _w.loaded = _load_whisper(); }
    if (!_w.loaded) return NULL;
    struct whisper_context *ctx = _w.init_from_file(path_model);
    if (!ctx) {
        snprintf(_last_error, sizeof(_last_error), "whisper_init_from_file returned NULL for model: %s", path_model ? path_model : "(null)");
    }
    return ctx;
}

WHISPER_WRAPPER_API void
whisper_wrapper_free(struct whisper_context* ctx) {
    if (_w.loaded && ctx) _w.free(ctx);
}

WHISPER_WRAPPER_API struct whisper_full_params*
whisper_wrapper_default_params(int strategy) {
    if (!_w.loaded) { _w.loaded = _load_whisper(); }
    if (!_w.loaded) return NULL;

    struct whisper_full_params *source = _w.full_default_params_by_ref(strategy);
    if (!source) return NULL;

    struct whisper_full_params *params = (struct whisper_full_params*)malloc(sizeof(struct whisper_full_params));
    if (!params) {
        _set_error("malloc failed for whisper params");
        _w.free_params(source);
        return NULL;
    }

    memcpy(params, source, sizeof(struct whisper_full_params));
    _w.free_params(source);

    params->vad = false;
    params->vad_model_path = NULL;
    params->language = "en";
    params->detect_language = false;
    params->no_context = true;
    params->print_progress = false;
    params->print_realtime = false;
    params->print_timestamps = false;
    params->no_timestamps = true;
    params->suppress_blank = true;
    params->suppress_nst = true;
    params->temperature = 0.0f;
    params->no_speech_thold = 0.65f;
    params->logprob_thold = -0.80f;
    params->entropy_thold = 2.0f;
    params->max_tokens = 64;
    params->initial_prompt = _initial_prompt[0] ? _initial_prompt : NULL;

    return params;
}

WHISPER_WRAPPER_API void
whisper_wrapper_free_params(struct whisper_full_params* params) {
    if (params) free(params);
}

WHISPER_WRAPPER_API int
whisper_wrapper_full(struct whisper_context* ctx,
                     struct whisper_full_params* params,
                     const float* samples,
                     int n_samples) {
    if (!_w.loaded || !ctx || !params) return -1;
    return _w.full(ctx, *params, samples, n_samples);
}

WHISPER_WRAPPER_API int
whisper_wrapper_n_segments(struct whisper_context* ctx) {
    if (!_w.loaded || !ctx) return -1;
    return _w.full_n_segments(ctx);
}

WHISPER_WRAPPER_API const char*
whisper_wrapper_segment_text(struct whisper_context* ctx, int i_segment) {
    if (!_w.loaded || !ctx) return NULL;
    return _w.full_get_segment_text(ctx, i_segment);
}

WHISPER_WRAPPER_API const char*
whisper_wrapper_system_info(void) {
    if (!_w.loaded) { _w.loaded = _load_whisper(); }
    if (!_w.loaded) return NULL;
    return _w.print_system_info();
}
