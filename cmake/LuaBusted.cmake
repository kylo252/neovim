# Distributed under the OSI-approved BSD 3-Clause License.
# See https://cmake.org/licensing for details.

#[=======================================================================[.rst:
Busted
-----
#]=======================================================================]

#------------------------------------------------------------------------------
function(busted_discover_tests TARGET)
  cmake_parse_arguments(
    ""
    ""
    "BUSTED_PRG;LUA_PRG;TEST_PREFIX;TEST_SUFFIX;WORKING_DIRECTORY;BUILD_DIR;TEST_LIST"
    "EXTRA_ARGS;PROPERTIES"
    ${ARGN}
  )

  if(NOT _WORKING_DIRECTORY)
    set(_WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}")
  endif()
  if(NOT _TEST_LIST)
    set(_TEST_LIST ${TARGET}_TESTS)
  endif()

  # TODO(kylo252): figure out if we can use a generator expression instead
  get_target_property(SPEC_FILES ${TARGET} SOURCES)

  foreach(SPEC_FILE ${SPEC_FILES})
    get_filename_component(ctest_file_base ${SPEC_FILE} NAME_WLE CACHE)
    set(ctest_include_file "${CMAKE_CURRENT_BINARY_DIR}/${ctest_file_base}_include.cmake")
    set(ctest_tests_file "${CMAKE_CURRENT_BINARY_DIR}/${ctest_file_base}_tests.cmake")

    # message("got ${ctest_file_base} ${ctest_file_dir} ${spec_file_relative}")

    add_custom_command(
      TARGET ${TARGET} PRE_BUILD
      BYPRODUCTS "${ctest_tests_file}"
      COMMAND "${CMAKE_COMMAND}"
      -D "TEST_TARGET=${TARGET}"
      -D "BUSTED_PRG=${_BUSTED_PRG}"
      -D "SPEC_FILE=${SPEC_FILE}"
      -D "LUA_PRG=${_LUA_PRG}"
      -D "WORKING_DIR=${_WORKING_DIRECTORY}"
      -D "BUILD_DIR=${_BUILD_DIR}"
      -D "TEST_EXTRA_ARGS=${_EXTRA_ARGS}"
      -D "TEST_PROPERTIES=${_PROPERTIES}"
      -D "TEST_PREFIX=${_TEST_PREFIX}"
      -D "TEST_SUFFIX=${_TEST_SUFFIX}"
      -D "TEST_LIST=${_TEST_LIST}"
      -D "CTEST_FILE=${ctest_tests_file}"
      -P "${_BUSTED_DISCOVER_TESTS_SCRIPT}"
      VERBATIM
    )

    file(
      WRITE "${ctest_include_file}"
      "if(EXISTS \"${ctest_tests_file}\")\n"
      "  include(\"${ctest_tests_file}\")\n"
      "else()\n"
      "  add_test(${TARGET}_NOT_BUILT ${TARGET}_NOT_BUILT)\n"
      "endif()\n"
    )

    if(NOT ${CMAKE_VERSION} VERSION_LESS "3.10.0")
      # Add discovered tests to directory TEST_INCLUDE_FILES
      set_property(
        DIRECTORY
        APPEND PROPERTY TEST_INCLUDE_FILES "${ctest_include_file}"
      )
    else()
      # Add discovered tests as directory TEST_INCLUDE_FILE if possible
      get_property(test_include_file_set DIRECTORY PROPERTY TEST_INCLUDE_FILE SET)
      if(NOT ${test_include_file_set})
        set_property(
          DIRECTORY
          PROPERTY TEST_INCLUDE_FILE "${ctest_include_file}"
        )
      else()
        message(
          FATAL_ERROR
          "Cannot set more than one TEST_INCLUDE_FILE"
        )
      endif()
    endif()
  endforeach()

endfunction()

###############################################################################

set(
  _BUSTED_DISCOVER_TESTS_SCRIPT
  ${CMAKE_CURRENT_LIST_DIR}/BustedAddTests.cmake
  CACHE INTERNAL "busted full path to BustedAddTests.cmake helper file"
)
