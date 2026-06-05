cmake_minimum_required(VERSION 3.24)

project(DictatorMDWindows LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if (NOT WIN32)
  message(FATAL_ERROR "The Windows prototype must be built on Windows.")
endif()

add_executable(DictatorMDWindows WIN32
  src/App.cpp
  src/AudioCapture.cpp
  src/DictationPipeline.cpp
  src/FocusTracker.cpp
  src/HotkeyManager.cpp
  src/TextInjector.cpp
  src/TrayIcon.cpp
  src/main.cpp
)

target_include_directories(DictatorMDWindows PRIVATE src)

set_target_properties(DictatorMDWindows PROPERTIES
  OUTPUT_NAME "Dictator-md"
)

target_compile_definitions(DictatorMDWindows PRIVATE
  UNICODE
  _UNICODE
  WIN32_LEAN_AND_MEAN
  NOMINMAX
)

target_link_libraries(DictatorMDWindows PRIVATE
  user32
  shell32
  ole32
  uuid
)
