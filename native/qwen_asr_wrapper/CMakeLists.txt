cmake_minimum_required(VERSION 3.16)
project(qwen_asr_wrapper C)

# ==============================================================================
# Qwen ASR Wrapper CMakeLists.txt
#
# Builds qwen_asr_wrapper.dll, a thin ABI adapter that exposes pointer-based
# signatures for Dart FFI consumption. It dynamically loads qwen_asr.dll
# (from antirez/qwen-asr) at runtime.
#
# Prerequisites:
#   - Build antirez/qwen-asr first to get qwen_asr.dll
#   - Place qwen_asr.dll in native/prebuilt/ or on PATH
#
# Usage:
#   mkdir build && cd build
#   cmake .. -DCMAKE_BUILD_TYPE=Release
#   cmake --build . --config Release
# ==============================================================================

set(CMAKE_C_STANDARD   11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# --- Source files -----------------------------------------------------------
add_library(qwen_asr_wrapper SHARED qwen_asr_wrapper.c)

# --- Compile definitions ----------------------------------------------------
target_compile_definitions(qwen_asr_wrapper PRIVATE
    $<$<CONFIG:Debug>:_DEBUG>
    $<$<CONFIG:Release>:NDEBUG>
)

# --- Windows-specific settings -----------------------------------------------
if(WIN32)
    set_target_properties(qwen_asr_wrapper PROPERTIES
        WINDOWS_EXPORT_ALL_SYMBOLS ON
    )
endif()

# --- Link against qwen_asr.dll ----------------------------------------------
# qwen_asr.dll is loaded at runtime via LoadLibrary.
# We don't need to link at build time.
target_link_libraries(qwen_asr_wrapper PRIVATE)

# --- Output directory ---------------------------------------------------------
set_target_properties(qwen_asr_wrapper PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../prebuilt"
)

# --- Platform-specific compilation flags -------------------------------------
if(MSVC)
    target_compile_options(qwen_asr_wrapper PRIVATE /W3 /MT)
elseif(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|MinGW")
    target_compile_options(qwen_asr_wrapper PRIVATE -Wall -Wextra -O2)
endif()
