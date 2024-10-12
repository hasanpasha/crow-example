include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(crow_example_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(crow_example_setup_options)
  option(crow_example_ENABLE_HARDENING "Enable hardening" ON)
  option(crow_example_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    crow_example_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    crow_example_ENABLE_HARDENING
    OFF)

  crow_example_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR crow_example_PACKAGING_MAINTAINER_MODE)
    option(crow_example_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(crow_example_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(crow_example_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(crow_example_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(crow_example_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(crow_example_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(crow_example_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(crow_example_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(crow_example_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(crow_example_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(crow_example_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(crow_example_ENABLE_PCH "Enable precompiled headers" OFF)
    option(crow_example_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(crow_example_ENABLE_IPO "Enable IPO/LTO" ON)
    option(crow_example_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(crow_example_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(crow_example_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(crow_example_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(crow_example_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(crow_example_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(crow_example_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(crow_example_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(crow_example_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(crow_example_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(crow_example_ENABLE_PCH "Enable precompiled headers" OFF)
    option(crow_example_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      crow_example_ENABLE_IPO
      crow_example_WARNINGS_AS_ERRORS
      crow_example_ENABLE_USER_LINKER
      crow_example_ENABLE_SANITIZER_ADDRESS
      crow_example_ENABLE_SANITIZER_LEAK
      crow_example_ENABLE_SANITIZER_UNDEFINED
      crow_example_ENABLE_SANITIZER_THREAD
      crow_example_ENABLE_SANITIZER_MEMORY
      crow_example_ENABLE_UNITY_BUILD
      crow_example_ENABLE_CLANG_TIDY
      crow_example_ENABLE_CPPCHECK
      crow_example_ENABLE_COVERAGE
      crow_example_ENABLE_PCH
      crow_example_ENABLE_CACHE)
  endif()

  crow_example_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (crow_example_ENABLE_SANITIZER_ADDRESS OR crow_example_ENABLE_SANITIZER_THREAD OR crow_example_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(crow_example_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(crow_example_global_options)
  if(crow_example_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    crow_example_enable_ipo()
  endif()

  crow_example_supports_sanitizers()

  if(crow_example_ENABLE_HARDENING AND crow_example_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR crow_example_ENABLE_SANITIZER_UNDEFINED
       OR crow_example_ENABLE_SANITIZER_ADDRESS
       OR crow_example_ENABLE_SANITIZER_THREAD
       OR crow_example_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${crow_example_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${crow_example_ENABLE_SANITIZER_UNDEFINED}")
    crow_example_enable_hardening(crow_example_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(crow_example_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(crow_example_warnings INTERFACE)
  add_library(crow_example_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  crow_example_set_project_warnings(
    crow_example_warnings
    ${crow_example_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(crow_example_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    crow_example_configure_linker(crow_example_options)
  endif()

  include(cmake/Sanitizers.cmake)
  crow_example_enable_sanitizers(
    crow_example_options
    ${crow_example_ENABLE_SANITIZER_ADDRESS}
    ${crow_example_ENABLE_SANITIZER_LEAK}
    ${crow_example_ENABLE_SANITIZER_UNDEFINED}
    ${crow_example_ENABLE_SANITIZER_THREAD}
    ${crow_example_ENABLE_SANITIZER_MEMORY})

  set_target_properties(crow_example_options PROPERTIES UNITY_BUILD ${crow_example_ENABLE_UNITY_BUILD})

  if(crow_example_ENABLE_PCH)
    target_precompile_headers(
      crow_example_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(crow_example_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    crow_example_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(crow_example_ENABLE_CLANG_TIDY)
    crow_example_enable_clang_tidy(crow_example_options ${crow_example_WARNINGS_AS_ERRORS})
  endif()

  if(crow_example_ENABLE_CPPCHECK)
    crow_example_enable_cppcheck(${crow_example_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(crow_example_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    crow_example_enable_coverage(crow_example_options)
  endif()

  if(crow_example_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(crow_example_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(crow_example_ENABLE_HARDENING AND NOT crow_example_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR crow_example_ENABLE_SANITIZER_UNDEFINED
       OR crow_example_ENABLE_SANITIZER_ADDRESS
       OR crow_example_ENABLE_SANITIZER_THREAD
       OR crow_example_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    crow_example_enable_hardening(crow_example_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
