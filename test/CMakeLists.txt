add_subdirectory(includes)
add_subdirectory(functional/fixtures)

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
  COMMAND ${NVIM_PRG} -u NONE --headless -es -c [==[lua require('scripts.lintcommit').main({trace=false})]==]
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

get_target_property(NVIM_SOURCES nvim_sources INTERFACE_SOURCES)
get_target_property(NVIM_HEADERS nvim_headers INTERFACE_SOURCES)

list(APPEND LINT_NVIM_C_FILES ${NVIM_SOURCES} ${NVIM_HEADERS})

find_program(GIT_EXECUTABLE git)

find_program(LUACHECK_PRG luacheck)
find_program(STYLUA_PRG stylua)
find_program(FLAKE8_PRG flake8)
find_program(UNCRUSTIFY_PRG uncrustify)
find_program(SHELLCHECK_PRG shellcheck)
set(CLINT_PRG ${PROJECT_SOURCE_DIR}/src/clint.py)
set(CLINT_SUPPRESSIONS_DIR ${PROJECT_BINARY_DIR}/errors)

# used for detecting changed files
if(DEFINED ENV{NVIM_GIT_BASEREF})
  set(NVIM_GIT_BASEREF "$ENV{NVIM_GIT_BASEREF}")
else()
  set(NVIM_GIT_BASEREF "HEAD^1")
endif()

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

include(FetchErrorSuppressions)
FetchErrorSuppressions(
  TARGET clint-reports
  DOWNLOAD_DIR ${CLINT_SUPPRESSIONS_DIR}
)

add_dependencies(nvim clint-reports)

if(CI_BUILD)
  set(CLINT_OUTPUT_FORMAT gh_action)
else()
  set(CLINT_OUTPUT_FORMAT vs7)
endif()

# add a seprate test for each file for easier invocation
# e.g. `ctest --test-dir build -R lintuncrustify-src-nvim-window-h`
foreach(f ${LINT_NVIM_C_FILES})
  file(RELATIVE_PATH rfile ${PROJECT_SOURCE_DIR} ${f})
  file(RELATIVE_PATH testname "${PROJECT_SOURCE_DIR}/src/nvim" ${f})
  string(REGEX REPLACE "[/.]" "-" testname ${testname})
  set(unc_testname lintuncrustify-${testname})
  set(clint_testname lintc-${testname})
  # FIXME(kylo252): this should probably be replaced with a FIXTURES_SETUP
  if(UNCRUSTIFY_PRG)
    add_test(
      NAME ${unc_testname}
      COMMAND ${UNCRUSTIFY_PRG} -c ${PROJECT_SOURCE_DIR}/src/uncrustify.cfg -q --check ${rfile}
      WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    )
    set_tests_properties(
      ${unc_testname} PROPERTIES
      LABELS "lint-all;lintcfull"
      REQUIRED_FILES ${f}
    )
  endif()
  add_test(
    NAME ${clint_testname}
    COMMAND ${CLINT_PRG} --suppress-errors ${CLINT_SUPPRESSIONS_DIR}/${testname}.json --output ${CLINT_OUTPUT_FORMAT} ${rfile}
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  )
  set_tests_properties(
    ${clint_testname} PROPERTIES
    LABELS "lint-all;lintcfull"
    REQUIRED_FILES ${f}
  )
endforeach()

add_test(
  NAME lintlua-luacheck
  COMMAND ${LUACHECK_PRG} -q runtime/ scripts/ src/ test/
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

add_test(
  NAME lintlua-stylua
  COMMAND ${STYLUA_PRG} --color=always --check runtime/
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

add_test(
  NAME lintpy
  COMMAND ${FLAKE8_PRG} --max-line-length 88 contrib scripts src test
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

add_custom_target(lintc-changed-only)
add_custom_command(TARGET lintc-changed-only
  COMMAND bash -c [==[git diff --name-only --relative=src/nvim HEAD | sed 's@[/.]@-@g' | xargs -n1 ctest --test-dir build -L 'lintc' -R]==]
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  USES_TERMINAL
  VERBATIM
)

add_test(NAME lintc-changed-only 
  COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target lintc-changed-only 
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)
