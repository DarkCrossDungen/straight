cmake_minimum_required(VERSION 3.21)
project(moonshine_wrapper LANGUAGES CXX)

# v0.1.5 runtime (MOONSHINE_HEADER_VERSION 30000). The Linux copy of
# libmoonshine.so + libonnxruntime.so.1 is staged in ../prebuilt; the header
# lives in ./include (copied from the release tarball).
set(MOONSHINE_PREBUILT_DIR "${CMAKE_CURRENT_LIST_DIR}/../prebuilt")

add_library(moonshine_wrapper SHARED moonshine_wrapper.cpp)
target_compile_features(moonshine_wrapper PRIVATE cxx_std_20)
target_include_directories(moonshine_wrapper PRIVATE
  "${CMAKE_CURRENT_LIST_DIR}/include")

if(WIN32)
  # Windows staging keeps moonshine_wrapper.dll next to moonshine.dll /
  # onnxruntime.dll in ../prebuilt.
  target_link_directories(moonshine_wrapper PRIVATE "${MOONSHINE_PREBUILT_DIR}")
  target_link_libraries(moonshine_wrapper PRIVATE moonshine)
else()
  target_link_libraries(moonshine_wrapper PRIVATE
    "${MOONSHINE_PREBUILT_DIR}/libmoonshine.so")
  # Ubuntu's default --as-needed drops libmoonshine from NEEDED for -shared
  # outputs; force it so the $ORIGIN rpath actually loads it at runtime.
  target_link_options(moonshine_wrapper PRIVATE
    "LINKER:--no-as-needed"
    "LINKER:--as-needed"
    "LINKER:-rpath,\$ORIGIN")
endif()
