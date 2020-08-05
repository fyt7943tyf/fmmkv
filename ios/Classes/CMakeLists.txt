cmake_minimum_required(VERSION 3.4.1)

set(CMAKE_CXX_STANDARD 17)
include_directories(Core)

add_library(libmmkv STATIC IMPORTED)
set_target_properties(libmmkv PROPERTIES IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/android_static/${ANDROID_ABI}/libcore.a)

add_library(fmmkv SHARED fmmkv.cpp)
set_target_properties(fmmkv PROPERTIES CXX_STANDARD 17 CXX_EXTENSIONS OFF POSITION_INDEPENDENT_CODE ON)

find_library(log-lib log)
find_library(zlib z)

target_link_libraries(fmmkv ${log-lib} libmmkv ${zlib})