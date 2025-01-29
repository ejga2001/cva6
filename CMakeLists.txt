cmake_minimum_required(VERSION 3.10)

# Project name
project(cva6)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Recursively gather all .cpp and .h files from work-ver and core-apu directories
# file(GLOB_RECURSE WORK_VER_SOURCES "${CMAKE_SOURCE_DIR}/work-ver/*.cpp" "${CMAKE_SOURCE_DIR}/work-ver/*.h")
# file(GLOB_RECURSE CORE_APU_SOURCES "${CMAKE_SOURCE_DIR}/coreapu/tb/*.cpp" "${CMAKE_SOURCE_DIR}/core-pu/tb/*.h")

# Combine all source and header files from work-ver and core-apu
set(ALL_FILES ${WORK_VER_SOURCES} ${CORE_APU_SOURCES})

# Add executable or library (adjust based on your needs)
add_executable(${PROJECT_NAME} ${ALL_FILES})

# Include directories (if needed)
include_directories("${CMAKE_SOURCE_DIR}/work-ver" "${CMAKE_SOURCE_DIR}/coreapu")
