// Cross-platform wrapper around the Moonshine v0.1.5 C API
// (moonshine-voice-linux-x86_64 / moonshine-voice-windows-x86_64,
// MOONSHINE_HEADER_VERSION 30000).
//
// Export style mirrors native/whisper_wrapper/whisper_wrapper.c:
//   _WIN32 -> __declspec(dllexport), otherwise visibility("default").
//
// The Dart side (lib/core/stt/moonshine_engine.dart) calls exactly:
//   moonshine_wrapper_init(model_path) -> void* ctx (nullptr on failure)
//   moonshine_wrapper_transcribe(ctx, float* samples, int count) -> char*
//       (malloc'd NUL-terminated UTF-8; release via free_string)
//   moonshine_wrapper_last_error() -> const char*
//   moonshine_wrapper_free_string(char*)
//   moonshine_wrapper_free(void* ctx)
//
// v0.1.5 removed the old per-frame transcribe path used by earlier builds of
// this wrapper, so a whole-buffer transcription is implemented on top of the
// streaming API: create_stream -> start_stream -> add_audio_to_stream ->
// stop_stream -> transcribe_stream(FORCE_UPDATE) to drain, then join all
// non-empty lines with single spaces (same output shape as before).

#ifdef _WIN32
#define MOONSHINE_WRAPPER_API __declspec(dllexport)
#else
#define MOONSHINE_WRAPPER_API __attribute__((visibility("default")))
#endif

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <sstream>
#include <string>

#include "moonshine-c-api.h"

namespace {

std::mutex g_mutex;
std::string g_last_error;

void set_error(const std::string& message) {
  g_last_error = message;
}

const char* error_text(int32_t error) {
  const char* message = moonshine_error_to_string(error);
  return message == nullptr ? "unknown Moonshine error" : message;
}

// Moonshine handles are int32_t; Dart sees an opaque void*. Encode as
// (handle + 1) so handle 0 never maps to nullptr.
void* wrap_handle(int32_t handle) {
  return reinterpret_cast<void*>(static_cast<intptr_t>(handle + 1));
}

int32_t unwrap_handle(void* context) {
  return static_cast<int32_t>(
      reinterpret_cast<intptr_t>(context) - 1);
}

std::string join_lines(const transcript_t* transcript) {
  std::ostringstream output;
  for (uint64_t index = 0; index < transcript->line_count; ++index) {
    const char* text = transcript->lines[index].text;
    if (text == nullptr || text[0] == '\0') continue;
    if (output.tellp() > 0) output << ' ';
    output << text;
  }
  return output.str();
}

}  // namespace

extern "C" {

MOONSHINE_WRAPPER_API void* moonshine_wrapper_init(const char* model_path) {
  std::lock_guard<std::mutex> lock(g_mutex);
  g_last_error.clear();

  if (model_path == nullptr || std::strlen(model_path) == 0) {
    set_error("Moonshine model path is empty");
    return nullptr;
  }

  const int32_t handle = moonshine_load_transcriber_from_files(
      model_path,
      MOONSHINE_MODEL_ARCH_SMALL_STREAMING,
      nullptr,
      0,
      MOONSHINE_HEADER_VERSION);
  if (handle < 0) {
    set_error(error_text(handle));
    return nullptr;
  }

  return wrap_handle(handle);
}

MOONSHINE_WRAPPER_API const char* moonshine_wrapper_last_error() {
  std::lock_guard<std::mutex> lock(g_mutex);
  return g_last_error.c_str();
}

MOONSHINE_WRAPPER_API char* moonshine_wrapper_transcribe(
    void* context,
    const float* samples,
    int sample_count) {
  std::lock_guard<std::mutex> lock(g_mutex);
  g_last_error.clear();

  if (context == nullptr || samples == nullptr || sample_count <= 0) {
    set_error("Moonshine received invalid audio data");
    return nullptr;
  }

  const int32_t transcriber = unwrap_handle(context);

  int32_t stream = moonshine_create_stream(transcriber, 0);
  if (stream < 0) {
    set_error(error_text(stream));
    return nullptr;
  }

  int32_t error = moonshine_start_stream(transcriber, stream);
  if (error != MOONSHINE_ERROR_NONE) {
    set_error(error_text(error));
    moonshine_free_stream(transcriber, stream);
    return nullptr;
  }

  error = moonshine_transcribe_add_audio_to_stream(
      transcriber,
      stream,
      samples,
      static_cast<uint64_t>(sample_count),
      16000,
      0);
  if (error != MOONSHINE_ERROR_NONE) {
    set_error(error_text(error));
    moonshine_free_stream(transcriber, stream);
    return nullptr;
  }

  // Close the utterance; the following transcribe_stream call drains any
  // leftover audio and marks every line complete.
  error = moonshine_stop_stream(transcriber, stream);
  if (error != MOONSHINE_ERROR_NONE) {
    set_error(error_text(error));
    moonshine_free_stream(transcriber, stream);
    return nullptr;
  }

  transcript_t* transcript = nullptr;
  error = moonshine_transcribe_stream(
      transcriber, stream, MOONSHINE_FLAG_FORCE_UPDATE, &transcript);
  if (error != MOONSHINE_ERROR_NONE || transcript == nullptr) {
    set_error(error_text(error));
    moonshine_free_stream(transcriber, stream);
    return nullptr;
  }

  const std::string text = join_lines(transcript);

  // Transcript lines are owned by the transcriber/stream; copying the joined
  // text above and then releasing the stream is safe.
  error = moonshine_free_stream(transcriber, stream);
  if (error != MOONSHINE_ERROR_NONE) {
    set_error(error_text(error));
    // Text was produced successfully; still return it.
  }

  char* copy = static_cast<char*>(std::malloc(text.size() + 1));
  if (copy == nullptr) {
    set_error("Unable to allocate Moonshine result");
    return nullptr;
  }
  std::memcpy(copy, text.c_str(), text.size() + 1);
  return copy;
}

MOONSHINE_WRAPPER_API void moonshine_wrapper_free_string(char* text) {
  std::free(text);
}

MOONSHINE_WRAPPER_API void moonshine_wrapper_free(void* context) {
  if (context == nullptr) return;
  const int32_t handle = unwrap_handle(context);
  moonshine_free_transcriber(handle);
}

}  // extern "C"
