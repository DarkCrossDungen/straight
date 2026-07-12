#!/bin/bash
# Build native libraries for STRAIGHT
# Usage: ./build.sh [Release|Debug]

set -e

BUILD_TYPE="${1:-Release}"

echo "Building whisper.cpp..."
cmake -S whisper.cpp -B whisper.cpp/build \
  -G "Visual Studio 17 2022" -A x64 \
  -DWHISPER_SHARED_LIB=ON \
  -DWHISPER_BUILD_TESTS=OFF \
  -DWHISPER_BUILD_EXAMPLES=OFF
cmake --build whisper.cpp/build --config "$BUILD_TYPE" --target whisper

mkdir -p prebuilt
cp "whisper.cpp/build/bin/$BUILD_TYPE/whisper.dll" prebuilt/
echo "whisper.dll built and copied to prebuilt/"

echo "Building whisper_wrapper..."
cmake -S whisper_wrapper -B whisper_wrapper/build \
  -G "Visual Studio 17 2022" -A x64
cmake --build whisper_wrapper/build --config "$BUILD_TYPE"

cp "whisper_wrapper/build/$BUILD_TYPE/whisper_wrapper.dll" prebuilt/
echo "whisper_wrapper.dll built and copied to prebuilt/"

echo "Building llama.cpp..."
cmake -S llama.cpp -B llama.cpp/build \
  -G "Visual Studio 17 2022" -A x64 \
  -DBUILD_SHARED_LIBS=ON \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_SERVER=OFF
cmake --build llama.cpp/build --config "$BUILD_TYPE"

cp "llama.cpp/build/bin/$BUILD_TYPE/llama.dll" prebuilt/
cp "llama.cpp/build/bin/$BUILD_TYPE/ggml.dll" prebuilt/
cp "llama.cpp/build/bin/$BUILD_TYPE/ggml-base.dll" prebuilt/
cp "llama.cpp/build/bin/$BUILD_TYPE/ggml-cpu.dll" prebuilt/
echo "llama.cpp DLLs built and copied to prebuilt/"

echo "Building qwen_wrapper..."
cmake -S qwen_wrapper -B qwen_wrapper/build \
  -G "Visual Studio 17 2022" -A x64
cmake --build qwen_wrapper/build --config "$BUILD_TYPE"

cp "qwen_wrapper/build/$BUILD_TYPE/qwen_wrapper.dll" prebuilt/
echo "qwen_wrapper.dll built and copied to prebuilt/"

echo "Building qwen_asr_wrapper..."
cmake -S qwen_asr_wrapper -B qwen_asr_wrapper/build \
  -G "Visual Studio 17 2022" -A x64
cmake --build qwen_asr_wrapper/build --config "$BUILD_TYPE"

cp "qwen_asr_wrapper/build/$BUILD_TYPE/qwen_asr_wrapper.dll" prebuilt/
echo "qwen_asr_wrapper.dll built and copied to prebuilt/"

echo ""
echo "=== Build Complete ==="
echo "All DLLs are in native/prebuilt/"
ls -la prebuilt/*.dll 2>/dev/null || dir prebuilt\\*.dll 2>/dev/null
