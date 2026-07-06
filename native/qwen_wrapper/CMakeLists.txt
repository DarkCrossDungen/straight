cmake_minimum_required(VERSION 3.16)
project(qwen_wrapper C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

add_library(qwen_wrapper SHARED qwen_wrapper.c)

target_include_directories(qwen_wrapper PRIVATE
    "${CMAKE_SOURCE_DIR}/../llama.cpp/include"
    "${CMAKE_SOURCE_DIR}/../llama.cpp/ggml/include"
)

target_compile_definitions(qwen_wrapper PRIVATE
    $<$<CONFIG:Debug>:_DEBUG>
    $<$<CONFIG:Release>:NDEBUG>
)

if(WIN32)
    set_target_properties(qwen_wrapper PROPERTIES
        WINDOWS_EXPORT_ALL_SYMBOLS ON
    )
endif()

set_target_properties(qwen_wrapper PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../prebuilt"
)

if(MSVC)
    target_compile_options(qwen_wrapper PRIVATE /W3)
elseif(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|MinGW")
    target_compile_options(qwen_wrapper PRIVATE -Wall -Wextra -O2)
endif()
