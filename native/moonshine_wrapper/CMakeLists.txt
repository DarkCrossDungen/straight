cmake_minimum_required(VERSION 3.21)
project(moonshine_wrapper LANGUAGES CXX)

set(MOONSHINE_RUNTIME_DIR "${CMAKE_CURRENT_LIST_DIR}/../moonshine/runtime-v0.0.69/moonshine-voice-windows-x86_64")

add_library(moonshine_wrapper SHARED moonshine_wrapper.cpp)
target_compile_features(moonshine_wrapper PRIVATE cxx_std_17)
target_include_directories(moonshine_wrapper PRIVATE "${MOONSHINE_RUNTIME_DIR}/include")
target_link_directories(moonshine_wrapper PRIVATE "${MOONSHINE_RUNTIME_DIR}/lib")
target_link_libraries(moonshine_wrapper PRIVATE
  moonshine
  moonshine-utils
  ort-utils
  bin-tokenizer
  onnxruntime
)
