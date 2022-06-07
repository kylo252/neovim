add_subdirectory(includes)

#################################
########## test specs ###########
#################################

# add_test(
#   NAME TestBustedConfig
#   WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
#   COMMAND sh -c "${BUSTED_PRG} --run=providerFunc --list"
# )
#
# add_test(
#   NAME TestBufferUnit
#   WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
#   COMMAND ${CMAKE_COMMAND}
#   -DBUSTED_PRG=${BUSTED_PRG}
#   -DLUA_PRG=${LUA_PRG}
#   -DWORKING_DIR=${PROJECT_SOURCE_DIR}
#   -DBUSTED_OUTPUT_TYPE=${BUSTED_OUTPUT_TYPE}
#   -DTEST_DIR=${PROJECT_SOURCE_DIR}/test
#   -DBUILD_DIR=${CMAKE_BINARY_DIR}
#   -DTEST_TYPE=unit
#   -DTEST_PATH=test/unit/buffer_spec.lua
#   -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
# )
#
# add_test(
#   NAME TestApiFunctional
#   COMMAND ${CMAKE_COMMAND}
#   -DBUSTED_PRG=${BUSTED_PRG}
#   -DLUA_PRG=${LUA_PRG}
#   -DNVIM_PRG=$<TARGET_FILE:nvim>
#   -DWORKING_DIR=${PROJECT_SOURCE_DIR}
#   -DBUSTED_OUTPUT_TYPE=${BUSTED_OUTPUT_TYPE}
#   -DTEST_DIR=${PROJECT_SOURCE_DIR}/test
#   -DBUILD_DIR=${CMAKE_BINARY_DIR}
#   -DTEST_TYPE=functional
#   -DTEST_PATH=test/functional/api/buffer_spec.lua
#   -P ${PROJECT_SOURCE_DIR}/cmake/RunTests.cmake
#   # -E env "TEST_FILE=test/functional/api/buffer_spec.lua" ## doesn't work
# )

# TODO: specify *all* the luarocks requirements for tests

add_custom_target(
  generate-test-runners
  DEPENDS ${UNITTEST_PREREQS} ${FUNCTIONALTEST_PREREQS}
  SOURCES ${PROJECT_SOURCE_DIR}/test/functional/plugin/lsp_spec.lua
)

include(LuaBusted)
busted_discover_tests(
  generate-test-runners
  BUSTED_PRG ${BUSTED_PRG}
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  LUA_PRG ${LUA_PRG}
  BUILD_DIR ${PROJECT_BINARY_DIR}
  USE_RUNTESTS OFF
  EXTRA_ARGS -Xhelper IS_FUNCTIONAL_TEST
)
