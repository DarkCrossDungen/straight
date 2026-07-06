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

#include "../../llama.cpp/include/llama.h"

struct qwen_ctx {
    struct llama_model   * model;
    struct llama_context * ctx;
    struct llama_sampler * sampler;
    const struct llama_vocab * vocab;
    int n_ctx;
};

static struct {
    struct llama_model * (*model_load_from_file)(const char *, struct llama_model_params);
    void (*model_free)(struct llama_model *);
    struct llama_context * (*new_context_with_model)(struct llama_model *, struct llama_context_params);
    void (*free)(struct llama_context *);
    const struct llama_vocab * (*model_get_vocab)(const struct llama_model *);
    struct llama_model_params (*model_default_params)(void);
    struct llama_context_params (*context_default_params)(void);
    int32_t (*tokenize)(const struct llama_vocab *, const char *, int32_t, llama_token *, int32_t, bool, bool);
    int32_t (*token_to_piece)(const struct llama_vocab *, llama_token, char *, int32_t, int32_t, bool);
    int32_t (*decode)(struct llama_context *, struct llama_batch);
    struct llama_batch (*batch_get_one)(llama_token *, int32_t);
    void (*batch_free)(struct llama_batch);
    float * (*get_logits_ith)(struct llama_context *, int32_t);
    int32_t (*n_vocab)(const struct llama_vocab *);
    int32_t (*n_ctx)(const struct llama_context *);
    uint32_t (*vocab_n_tokens)(const struct llama_vocab *);
    struct llama_sampler * (*sampler_init_greedy)(void);
    struct llama_sampler * (*sampler_chain_init)(struct llama_sampler_chain_params);
    void (*sampler_chain_add)(struct llama_sampler *, struct llama_sampler *);
    struct llama_sampler_chain_params (*sampler_chain_default_params)(void);
    llama_token (*sampler_sample)(struct llama_sampler *, struct llama_context *, int32_t);
    void (*sampler_free)(struct llama_sampler *);
    int loaded;
} _l = {0};

static int _load_llama(void) {
#ifdef _WIN32
    HMODULE mod = LoadLibraryW(L"llama.dll");
    if (!mod) return 0;
#define LOAD(name) _l. name = (void*)GetProcAddress(mod, "llama_" #name); if (!_l. name) return 0
#else
    void* mod = dlopen("libllama.so", RTLD_NOW | RTLD_GLOBAL);
    if (!mod) return 0;
#define LOAD(name) _l. name = (void*)dlsym(mod, "llama_" #name); if (!_l. name) return 0
#endif
    LOAD(model_load_from_file);
    LOAD(model_free);
    LOAD(new_context_with_model);
    LOAD(free);
    LOAD(model_get_vocab);
    LOAD(model_default_params);
    LOAD(context_default_params);
    LOAD(tokenize);
    LOAD(token_to_piece);
    LOAD(decode);
    LOAD(batch_get_one);
    LOAD(batch_free);
    LOAD(get_logits_ith);
    LOAD(n_vocab);
    LOAD(n_ctx);
    LOAD(vocab_n_tokens);
    LOAD(sampler_init_greedy);
    LOAD(sampler_chain_init);
    LOAD(sampler_chain_add);
    LOAD(sampler_chain_default_params);
    LOAD(sampler_sample);
    LOAD(sampler_free);
    return 1;
}

QWEN_WRAPPER_API struct qwen_ctx *
qwen_wrapper_init(const char * model_path) {
    if (!_l.loaded) { _l.loaded = _load_llama(); }
    if (!_l.loaded) return NULL;

    struct qwen_ctx * q = (struct qwen_ctx *)calloc(1, sizeof(struct qwen_ctx));
    if (!q) return NULL;

    struct llama_model_params mparams = _l.model_default_params();
    q->model = _l.model_load_from_file(model_path, mparams);
    if (!q->model) { free(q); return NULL; }

    q->vocab = _l.model_get_vocab(q->model);

    struct llama_context_params cparams = _l.context_default_params();
    cparams.n_ctx = 2048;
    cparams.n_batch = 512;
    cparams.n_threads = 4;
    cparams.n_threads_batch = 4;
    q->ctx = _l.new_context_with_model(q->model, cparams);
    if (!q->ctx) { _l.model_free(q->model); free(q); return NULL; }

    q->n_ctx = _l.n_ctx(q->ctx);

    q->sampler = _l.sampler_init_greedy();
    if (!q->sampler) {
        _l.free(q->ctx);
        _l.model_free(q->model);
        free(q);
        return NULL;
    }

    return q;
}

QWEN_WRAPPER_API char *
qwen_wrapper_complete(struct qwen_ctx * q, const char * prompt, int max_tokens) {
    if (!q || !q->ctx || !q->model) return NULL;

    int n_prompt = _l.tokenize(q->vocab, prompt, -1, NULL, 0, true, false);
    if (n_prompt <= 0) return NULL;

    llama_token * tokens = (llama_token *)malloc(n_prompt * sizeof(llama_token));
    if (!tokens) return NULL;

    _l.tokenize(q->vocab, prompt, -1, tokens, n_prompt, true, false);

    struct llama_batch batch = _l.batch_get_one(tokens, n_prompt);
    int ret = _l.decode(q->ctx, batch);
    _l.batch_free(batch);
    free(tokens);

    if (ret < 0) return NULL;

    int buf_size = max_tokens * 16 + 1;
    char * result = (char *)calloc(buf_size, 1);
    if (!result) return NULL;
    int pos = 0;

    int n_len = 0;
    llama_token prev_token = 0;
    llama_token eos_token = _l.vocab_n_tokens(q->vocab) - 1;

    while (n_len < max_tokens) {
        llama_token id = _l.sampler_sample(q->sampler, q->ctx, -1);
        if (id == eos_token) break;

        char piece[16];
        int n_piece = _l.token_to_piece(q->vocab, id, piece, sizeof(piece), 0, false);
        if (n_piece > 0) {
            if (pos + n_piece >= buf_size - 1) break;
            memcpy(result + pos, piece, n_piece);
            pos += n_piece;
        }

        prev_token = id;
        n_len++;

        struct llama_batch next = _l.batch_get_one(&id, 1);
        int r = _l.decode(q->ctx, next);
        _l.batch_free(next);
        if (r < 0) break;
    }

    result[pos] = '\0';
    return result;
}

QWEN_WRAPPER_API void
qwen_wrapper_free(struct qwen_ctx * q) {
    if (!q) return;
    if (q->sampler) _l.sampler_free(q->sampler);
    if (q->ctx) _l.free(q->ctx);
    if (q->model) _l.model_free(q->model);
    free(q);
}

QWEN_WRAPPER_API void
qwen_wrapper_free_string(char * s) {
    free(s);
}
