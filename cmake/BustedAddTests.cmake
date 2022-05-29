# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

set(prefix "${TEST_PREFIX}")
set(suffix "${TEST_SUFFIX}")
set(extra_args ${TEST_EXTRA_ARGS})
set(properties ${TEST_PROPERTIES})
set(script)
set(suite)
set(tests)

function(add_command NAME)
  set(_args "")
  # use ARGV* instead of ARGN, because ARGN splits arrays into multiple arguments
  math(EXPR _last_arg ${ARGC}-1)
  foreach(_n RANGE 1 ${_last_arg})
    set(_arg "${ARGV${_n}}")
    if(_arg MATCHES "[^-./:a-zA-Z0-9_]")
      set(_args "${_args} [==[${_arg}]==]") # form a bracket_argument
    else()
      set(_args "${_args} ${_arg}")
    endif()
  endforeach()
  set(script "${script}${NAME}(${_args})\n" PARENT_SCOPE)
endfunction()

# Run test executable to get list of available tests
if(NOT EXISTS "${SPEC_FILE}")
  message(
    FATAL_ERROR
    "Specified test file '${SPEC_FILE}' does not exist"
  )
endif()

execute_process(
  COMMAND ${BUSTED_PRG} ${SPEC_FILE} --list
  OUTPUT_VARIABLE output
  RESULT_VARIABLE result
  WORKING_DIRECTORY "${WORKING_DIR}"
)

if(NOT ${result} EQUAL 0)
  message(
    FATAL_ERROR
    "Error running test file '${SPEC_FILE}':\n"
    "  Result: ${result}\n"
    "  Output: ${output}\n"
  )
endif()

string(REPLACE "\n" ";" output "${output}")

# Parse output
foreach(line ${output})
  string(REGEX REPLACE "\\.( *#.*)?$" "" suite "${SPEC_FILE}")
  string(REGEX REPLACE ".*:[0-9]+: (.*)" "\\1" testname ${line})
  # Escape characters in test case names that would be parsed by Catch2
  foreach(char , [ ])
    string(REPLACE ${char} "\\${char}" testname ${testname})
  endforeach(char)
  string(REGEX REPLACE "[^A-Za-z0-9_.]" "_" testname_clean ${testname})
  set(guarded_testname "${prefix}${testname_clean}${suffix}")


  string(REGEX REPLACE "[^A-Za-z0-9]" "." test_filter ${testname_clean})

  set(extra_args "")
  if(BUSTED_ARGS)
    list(APPEND extra_args "--output=${OUTPUT_HANDLER}")
  endif()

  separate_arguments(extra_args)

  if(USE_RUNTESTS)
    add_command(
      add_test
      "${guarded_testname}"
      ${CMAKE_COMMAND}
      -DBUSTED_PRG=${BUSTED_PRG}
      -DLUA_PRG=${LUA_PRG}
      -DNVIM_PRG=$<TARGET_FILE:nvim>
      -DWORKING_DIR=${WORKING_DIR}
      -DTEST_DIR=${WORKING_DIR}/test
      -DBUILD_DIR=${BUILD_DIR}
      -DTEST_TYPE=functional
      -DTEST_FILTER=${test_filter}
      -DBUSTED_ARGS=${extra_args}
      -DTEST_PATH=${SPEC_FILE}
      -P ${WORKING_DIR}/cmake/RunTests.cmake
    )
  else()
    add_command(
      add_test
      "${guarded_testname}"
      ${BUSTED_PRG}
      ${SPEC_FILE}
      --filter=${test_filter}
      ${extra_args}
    )
  endif()

  add_command(
    set_tests_properties
    "${guarded_testname}"
    PROPERTIES
    WORKING_DIRECTORY "${WORKING_DIR}"
    ${TEST_PROPERTIES}
  )
  list(APPEND tests "${guarded_testname}")
endforeach()

# Create a list of all discovered tests, which users may use to e.g. set
# properties on the tests
add_command(set ${TEST_LIST} ${tests})

# Write CTest script
file(WRITE "${CTEST_FILE}" "${script}")
