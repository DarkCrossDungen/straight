cmake_minimum_required(VERSION 3.16)
project(whisper_wrapper C)

# ==============================================================================
# Whisper Wrapper CMakeLists.txt
#
# Builds whisper_wrapper.dll, a thin ABI adapter that exposes pointer-based
# signatures for Dart FFI consumption.  It links against native/prebuilt/whisper.dll
# which is expected to already be on the system search path (same directory
# at runtime, or PATH).
#
# Usage:
#   mkdir build && cd build
#   cmake .. -DCMAKE_BUILD_TYPE=Release
#   cmake --build . --config Release
# ==============================================================================

set(CMAKE_C_STANDARD   11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# --- Source files -----------------------------------------------------------
add_library(whisper_wrapper SHARED whisper_wrapper.c)

# --- Compile definitions ----------------------------------------------------
target_compile_definitions(whisper_wrapper PRIVATE
    $<$<CONFIG:Debug>:_DEBUG>
    $<$<CONFIG:Release>:NDEBUG>
)

# --- Windows-specific settings -----------------------------------------------
if(WIN32)
    # Export every symbol automatically (no .def file needed for the wrapper)
    set_target_properties(whisper_wrapper PROPERTIES
        WINDOWS_EXPORT_ALL_SYMBOLS ON
    )
endif()

# --- Link against whisper.dll ------------------------------------------------
# whisper.dll is loaded at runtime.  We tell the linker it will be
# available, but it does NOT need to resolve symbols at build time.
# On Windows this means we omit any target_link_libraries() for the
# external DLL.  The OS loader will resolve whisper.dll symbols when
# our wrapper DLL is loaded, provided whisper.dll is in the same
# directory or on PATH.
target_link_libraries(whisper_wrapper PRIVATE)

# --- Output directory ---------------------------------------------------------
set_target_properties(whisper_wrapper PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../prebuilt"
)

# --- Platform-specific compilation flags -------------------------------------
if(MSVC)
    target_compile_options(whisper_wrapper PRIVATE /W3 /MT)
elseif(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|MinGW")
    target_compile_options(whisper_wrapper PRIVATE -Wall -Wextra -O2)
endif()
