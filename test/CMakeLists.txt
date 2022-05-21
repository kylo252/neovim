add_subdirectory(includes)

add_test(
  NAME TestBustedConfig
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  COMMAND sh -c "${BUSTED_PRG} --run=providerFunc --list"
)

add_test(
  NAME TestProviderFunctional
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  COMMAND sh -c "${BUSTED_PRG} --run=providerFunc"
)
