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

}  // namespace

extern "C" {

__declspec(dllexport) void* moonshine_wrapper_init(const char* model_path) {
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

  return reinterpret_cast<void*>(static_cast<intptr_t>(handle + 1));
}

__declspec(dllexport) const char* moonshine_wrapper_last_error() {
  std::lock_guard<std::mutex> lock(g_mutex);
  return g_last_error.c_str();
}

__declspec(dllexport) char* moonshine_wrapper_transcribe(
    void* context,
    const float* samples,
    int sample_count) {
  std::lock_guard<std::mutex> lock(g_mutex);
  g_last_error.clear();

  if (context == nullptr || samples == nullptr || sample_count <= 0) {
    set_error("Moonshine received invalid audio data");
    return nullptr;
  }

  const int32_t handle = static_cast<int32_t>(
      reinterpret_cast<intptr_t>(context) - 1);
  transcript_t* transcript = nullptr;
  const int32_t error = moonshine_transcribe_without_streaming(
      handle,
      const_cast<float*>(samples),
      static_cast<uint64_t>(sample_count),
      16000,
      0,
      &transcript);
  if (error != MOONSHINE_ERROR_NONE || transcript == nullptr) {
    set_error(error_text(error));
    return nullptr;
  }

  std::ostringstream output;
  for (uint64_t index = 0; index < transcript->line_count; ++index) {
    const char* text = transcript->lines[index].text;
    if (text == nullptr || text[0] == '\0') continue;
    if (output.tellp() > 0) output << ' ';
    output << text;
  }

  const std::string text = output.str();
  char* copy = static_cast<char*>(std::malloc(text.size() + 1));
  if (copy == nullptr) {
    set_error("Unable to allocate Moonshine result");
    return nullptr;
  }
  std::memcpy(copy, text.c_str(), text.size() + 1);
  return copy;
}

__declspec(dllexport) void moonshine_wrapper_free_string(char* text) {
  std::free(text);
}

__declspec(dllexport) void moonshine_wrapper_free(void* context) {
  if (context == nullptr) return;
  const int32_t handle = static_cast<int32_t>(
      reinterpret_cast<intptr_t>(context) - 1);
  moonshine_free_transcriber(handle);
}

}  // extern "C"
