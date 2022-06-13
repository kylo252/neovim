add_subdirectory(includes)

# TODO: specify *all* the luarocks requirements for tests

#################################
########## test specs ###########
#################################

set(ENV{LC_ALL} "en_US.UTF-8")

if(POLICY CMP0012)
  # Handle CI=true, without dev warnings.
  cmake_policy(SET CMP0012 NEW)
endif()

file(MAKE_DIRECTORY "${PROJECT_BINARY_DIR}/test/Xtest_xdg/cache")
file(MAKE_DIRECTORY "${PROJECT_BINARY_DIR}/test/Xtest_xdg/config")
file(MAKE_DIRECTORY "${PROJECT_BINARY_DIR}/test/Xtest_xdg/share")
file(MAKE_DIRECTORY "${PROJECT_BINARY_DIR}/test/Xtest_tmpdir/share")

# TODO: this currently doesn't work for test/unit because test/unit/helper.lua is loading all the tests instead
add_custom_target(
  generate-test-runners
  DEPENDS ${UNITTEST_PREREQS} ${FUNCTIONALTEST_PREREQS}
  SOURCES ${PROJECT_SOURCE_DIR}/test/functional/api/autocmd_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/buffer_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/buffer_updates_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/command_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/extmark_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/highlight_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/keymap_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/menu_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/proc_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/server_notifications_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/server_requests_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/tabpage_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/ui_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/version_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/vim_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/window_spec.lua
)

include(LuaBusted)

set(NVIM_PRG $<TARGET_FILE:nvim>)

set(NVIM_TEST_TMPDIR ${PROJECT_BINARY_DIR}/test/Xtest_tmpdir)

set(test_env)
list(
  APPEND test_env
  "LC_ALL=en_US.UTF-8"
  "NVIM_PRG=${NVIM_PRG}"
  "NEOVIM_BUILD_DIR=${PROJECT_BINARY_DIR}"
  "NEOVIM_SOURCE_DIR=${PROJECT_SOURCE_DIR}"
  "VIMRUNTIME=${PROJECT_SOURCE_DIR}/runtime"
  "NVIM_RPLUGIN_MANIFEST=${PROJECT_BINARY_DIR}/test/Xtest_rplugin_manifest"
  "XDG_CACHE_HOME=${PROJECT_BINARY_DIR}/test/Xtest_xdg/cache"
  "XDG_CONFIG_HOME=${PROJECT_BINARY_DIR}/test/Xtest_xdg/config"
  "XDG_DATA_HOME=${PROJECT_BINARY_DIR}/test/Xtest_xdg/share"
  "TMPDIR=${PROJECT_BINARY_DIR}/test/Xtest_tmpdir"
  "NVIM_TEST_TMPDIR=${NVIM_TEST_TMPDIR}"
)

busted_discover_tests(
  generate-test-runners
  BUSTED_PRG ${BUSTED_PRG}
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  LUA_PRG ${LUA_PRG}
  BUILD_DIR ${PROJECT_BINARY_DIR}
  EXTRA_ARGS -Xhelper IS_FUNCTIONAL_TEST
  TEST_ENVIRONMENT ${test_env}
)

configure_file(CTestCustom.in ${CMAKE_BINARY_DIR}/CTestCustom.cmake)
