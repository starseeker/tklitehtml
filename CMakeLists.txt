cmake_minimum_required(VERSION 3.18)

project(tklitehtml VERSION 0.1.0 LANGUAGES C CXX)

include(CTest)
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

option(TKLITEHTML_USE_BUNDLED_LITEHTML
  "Build the litehtml submodule instead of using an installed package" ON
)

if(TKLITEHTML_USE_BUNDLED_LITEHTML)
  set(LITEHTML_BUILD_TESTING OFF CACHE BOOL "" FORCE)
  set(LITEHTML_ENABLE_LINT OFF CACHE BOOL "" FORCE)
  add_subdirectory(external/litehtml EXCLUDE_FROM_ALL)
else()
  find_package(litehtml CONFIG REQUIRED)
endif()

find_package(TCL 8.6 REQUIRED)

set(TK_PLATFORM_INCLUDE_PATH "" CACHE PATH
  "Directory containing platform headers required by the selected Tk build"
)

if(NOT TCL_STUB_LIBRARY OR NOT TK_STUB_LIBRARY)
  message(FATAL_ERROR "Tcl and Tk stub libraries are required")
endif()

add_library(tklitehtml SHARED
  src/init.cpp
  src/widget.cpp
  src/widget.h
)

target_compile_features(tklitehtml PRIVATE cxx_std_17)
target_compile_definitions(tklitehtml PRIVATE USE_TCL_STUBS USE_TK_STUBS)
if(MSVC)
  target_compile_options(tklitehtml PRIVATE /W4)
else()
  target_compile_options(tklitehtml PRIVATE -Wall -Wextra -Wpedantic)
endif()
target_include_directories(tklitehtml PRIVATE
  ${TCL_INCLUDE_PATH}
  ${TK_INCLUDE_PATH}
  ${TK_PLATFORM_INCLUDE_PATH}
)
target_link_libraries(tklitehtml PRIVATE
  litehtml
  ${TCL_STUB_LIBRARY}
  ${TK_STUB_LIBRARY}
)
set_target_properties(tklitehtml PROPERTIES
  CXX_EXTENSIONS OFF
  PREFIX ""
  OUTPUT_NAME "tklitehtml"
)

configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/library/tklitehtml.tcl.in"
  "${CMAKE_CURRENT_BINARY_DIR}/tklitehtml.tcl"
  @ONLY
)
file(GENERATE
  OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/pkgIndex.tcl"
  CONTENT "package ifneeded tklitehtml ${PROJECT_VERSION} [list source [file join \$dir tklitehtml.tcl]]\n"
)

install(TARGETS tklitehtml
  EXPORT tklitehtmlTargets
  LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/tklitehtml${PROJECT_VERSION}"
  RUNTIME DESTINATION "${CMAKE_INSTALL_LIBDIR}/tklitehtml${PROJECT_VERSION}"
)
install(FILES
  "${CMAKE_CURRENT_BINARY_DIR}/pkgIndex.tcl"
  "${CMAKE_CURRENT_BINARY_DIR}/tklitehtml.tcl"
  DESTINATION "${CMAKE_INSTALL_LIBDIR}/tklitehtml${PROJECT_VERSION}"
)

set(TKLITEHTML_CMAKE_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/cmake/tklitehtml")
configure_package_config_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake/tklitehtmlConfig.cmake.in"
  "${CMAKE_CURRENT_BINARY_DIR}/tklitehtmlConfig.cmake"
  INSTALL_DESTINATION "${TKLITEHTML_CMAKE_INSTALL_DIR}"
)
write_basic_package_version_file(
  "${CMAKE_CURRENT_BINARY_DIR}/tklitehtmlConfigVersion.cmake"
  VERSION "${PROJECT_VERSION}"
  COMPATIBILITY SameMajorVersion
)
install(EXPORT tklitehtmlTargets
  FILE tklitehtmlTargets.cmake
  DESTINATION "${TKLITEHTML_CMAKE_INSTALL_DIR}"
)
install(FILES
  "${CMAKE_CURRENT_BINARY_DIR}/tklitehtmlConfig.cmake"
  "${CMAKE_CURRENT_BINARY_DIR}/tklitehtmlConfigVersion.cmake"
  DESTINATION "${TKLITEHTML_CMAKE_INSTALL_DIR}"
)

if(BUILD_TESTING)
  add_test(
    NAME tklitehtml-tests
    COMMAND ${TCL_TCLSH} "${CMAKE_CURRENT_SOURCE_DIR}/tests/all.tcl"
      -packagepath "${CMAKE_CURRENT_BINARY_DIR}"
  )
  set_tests_properties(tklitehtml-tests PROPERTIES SKIP_RETURN_CODE 77)
endif()
