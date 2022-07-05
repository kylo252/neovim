add_subdirectory(includes)
add_subdirectory(functional/fixtures)

# TODO:
# - specify *all* the luarocks requirements for tests (what about ffi?)
# - use impatient to make up for the (sizeable) overhead when running each test independently

#################################
########## test specs ###########
#################################

if(POLICY CMP0012)
  # Handle CI=true, without dev warnings.
  cmake_policy(SET CMP0012 NEW)
endif()

find_program(NVIM_PRG nvim)
if(NOT NVIM_PRG)
  set(NVIM_PRG $<TARGET_FILE:nvim>)
endif()

set(test_env)
list(
  APPEND test_env
  "LC_ALL=en_US.UTF-8"
)

add_test(
  NAME lintcommit
  COMMAND ${NVIM_PRG} --headless --clean -es -c [==[lua require('scripts.lintcommit').main({trace=false})]==]
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

get_target_property(LINT_SOURCES nvim_sources INTERFACE_SOURCES)
get_target_property(LINT_HEADERS nvim_headers INTERFACE_SOURCES)

list(APPEND LINT_TARGETS ${LINT_SOURCES} ${LINT_HEADERS})

find_program(GIT_EXECUTABLE git)

find_program(LUACHECK_PRG luacheck)
find_program(STYLUA_PRG stylua)
find_program(FLAKE8_PRG flake8)
find_program(UNCRUSTIFY_PRG uncrustify)
find_program(SHELLCHECK_PRG shellcheck)

# used for detecting changed files
if(DEFINED ENV{NVIM_GIT_BASEREF})
  set(NVIM_GIT_BASEREF "$ENV{NVIM_GIT_BASEREF}")
else()
  set(NVIM_GIT_BASEREF "HEAD^1")
endif()

execute_process(
  COMMAND ${GIT_EXECUTABLE} diff --name-only ${NVIM_GIT_BASEREF}
  WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
  OUTPUT_VARIABLE output
  ERROR_VARIABLE err
  RESULT_VARIABLE result
)

string(REPLACE "\n" ";" changed_files "${output}")

# this one is used to populate lint-changed-only
# could also be used as part of a REQUIRED_FIXTURES
add_test(
  NAME check_changed_files
  COMMAND ${CMAKE_COMMAND} -E echo "${changed_files}"
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

set_tests_properties(
  check_changed_files PROPERTIES
  LABELS lint-changed-only
)

# add a seprate test for each file for easier invocation
# e.g. `ctest --test-dir build -R lintuncrustify-src-nvim-window-h`
foreach(f ${LINT_TARGETS})
  file(RELATIVE_PATH rfile ${PROJECT_SOURCE_DIR} ${f})
  string(REGEX REPLACE "[/.]" "-" testname ${rfile})
  set(guarded_testname lintuncrustify-${testname})
  add_test(
    NAME ${guarded_testname}
    COMMAND ${UNCRUSTIFY_PRG} -c "${PROJECT_SOURCE_DIR}/src/uncrustify.cfg" -q --check ${rfile}
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  )
  set_tests_properties(
    ${guarded_testname} PROPERTIES
    LABELS lint-all
    REQUIRED_FILES ${f}
  )
  if(rfile IN_LIST changed_files)
    set_tests_properties(
      ${guarded_testname} PROPERTIES
      LABELS "lint-changed-only;lintuncrustify-changed-only"
    )
  else()
    list(APPEND ignored_tests ${guarded_testname})
  endif()
endforeach()

add_test(
  NAME lintlua-luacheck
  COMMAND ${LUACHECK_PRG} -q --no-color runtime/ scripts/ src/ test/
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

add_test(
  NAME lintlua-stylua
  COMMAND ${STYLUA_PRG} runtime/
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

add_test(
  NAME lintpy
  COMMAND ${FLAKE8_PRG} contrib scripts src test
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

add_test(
  NAME lintsh
  COMMAND ${SHELLCHECK_PRG} scripts/vim-patch.sh
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

set_tests_properties(
  lintcommit lintlua-stylua lintlua-luacheck lintpy lintsh PROPERTIES
  LABELS lint-all
)
