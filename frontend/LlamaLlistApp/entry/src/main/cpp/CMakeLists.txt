cmake_minimum_required(VERSION 3.4.1)
project(keyword_napi)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

include_directories(${NATIVERENDER_ROOT_PATH})

add_library(keyword_napi SHARED keyword_napi.cpp)

find_library(libace_napi.z.so ace_napi.z)
find_library(libhilog_ndk.z.so hilog_ndk.z)

set_target_properties(keyword_napi PROPERTIES
  CXX_STANDARD 17
  CXX_STANDARD_REQUIRED ON
)

target_link_libraries(keyword_napi PUBLIC ${libace_napi.z.so} ${libhilog_ndk.z.so})