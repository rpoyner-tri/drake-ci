# Report build configuration
message("
  ------------------------------------------------------------------------------
  APPLE                               = ${DASHBOARD_APPLE}
  UNIX                                = ${DASHBOARD_UNIX}
  ------------------------------------------------------------------------------
  CMAKE_VERSION                       = ${CMAKE_VERSION}
  ------------------------------------------------------------------------------
  CTEST_BUILD_NAME                    = ${DASHBOARD_BUILD_NAME}
  CTEST_CHANGE_ID                     = ${CTEST_CHANGE_ID}
  CTEST_BUILD_FLAGS                   = ${CTEST_BUILD_FLAGS}
  CTEST_CMAKE_GENERATOR               = ${CTEST_CMAKE_GENERATOR}
  CTEST_CONFIGURATION_TYPE            = ${CTEST_CONFIGURATION_TYPE}
  CTEST_CONFIGURE_COMMAND             = ${CTEST_CONFIGURE_COMMAND}
  CTEST_GIT_COMMAND                   = ${CTEST_GIT_COMMAND}
  CTEST_SITE                          = ${CTEST_SITE}
  CTEST_UPDATE_COMMAND                = ${CTEST_UPDATE_COMMAND}
  CTEST_UPDATE_VERSION_ONLY           = ${CTEST_UPDATE_VERSION_ONLY}
  CTEST_USE_LAUNCHERS                 = ${CTEST_USE_LAUNCHERS}
  ------------------------------------------------------------------------------
  ")

set(DASHBOARD_CDASH_SERVER "drake-cdash.csail.mit.edu")
set(DASHBOARD_NIGHTLY_START_TIME "00:00:00 EST")

###############################################################################

#BEGIN superbuild

set(DASHBOARD_SUPERBUILD_FAILURE OFF)

set(DASHBOARD_SUPERBUILD_PROJECT_NAME "drake-superbuild")

set(CTEST_BUILD_NAME "${DASHBOARD_BUILD_NAME}")
set(CTEST_PROJECT_NAME "${DASHBOARD_SUPERBUILD_PROJECT_NAME}")
set(CTEST_NIGHTLY_START_TIME "${DASHBOARD_NIGHTLY_START_TIME}")
set(CTEST_DROP_METHOD "https")
set(CTEST_DROP_SITE "${DASHBOARD_CDASH_SERVER}")
set(CTEST_DROP_LOCATION
  "/submit.php?project=${DASHBOARD_SUPERBUILD_PROJECT_NAME}")
set(CTEST_DROP_SITE_CDASH ON)

set(DASHBOARD_SUPERBUILD_START_MESSAGE
  "*** CTest Status: DOWNLOADING GOOGLE_STYLEGUIDE")

message("
  ------------------------------------------------------------------------------
  ${DASHBOARD_SUPERBUILD_START_MESSAGE}
  ------------------------------------------------------------------------------
  ")

ctest_start("${DASHBOARD_MODEL}" TRACK "${DASHBOARD_TRACK}" QUIET)
ctest_update(SOURCE "${CTEST_SOURCE_DIRECTORY}"
  RETURN_VALUE DASHBOARD_SUPERBUILD_UPDATE_RETURN_VALUE QUIET)

# Configure superbuild
ctest_configure(BUILD "${CTEST_BINARY_DIRECTORY}"
  SOURCE "${CTEST_SOURCE_DIRECTORY}"
  RETURN_VALUE DASHBOARD_SUPERBUILD_CONFIGURE_RETURN_VALUE QUIET)
if(NOT DASHBOARD_SUPERBUILD_CONFIGURE_RETURN_VALUE EQUAL 0)
  set(DASHBOARD_FAILURE ON)
  list(APPEND DASHBOARD_FAILURES "CONFIGURE SUPERBUILD")
endif()

# Download google_styleguide (superbuild "build" step)
ctest_build(BUILD "${CTEST_BINARY_DIRECTORY}" APPEND
  TARGET "google_styleguide-update"
  RETURN_VALUE DASHBOARD_SUPERBUILD_DOWNLOAD_RETURN_VALUE QUIET)
if(NOT DASHBOARD_SUPERBUILD_DOWNLOAD_RETURN_VALUE EQUAL 0)
  set(DASHBOARD_FAILURE ON)
  list(APPEND DASHBOARD_FAILURES "DOWNLOAD SUPERBUILD")
endif()
ctest_submit(RETRY_COUNT 4 RETRY_DELAY 15
  RETURN_VALUE DASHBOARD_SUPERBUILD_SUBMIT_RETURN_VALUE QUIET)

# Submit results of superbuild
set(DASHBOARD_BUILD_URL_FILE
  "${CTEST_BINARY_DIRECTORY}/${DASHBOARD_BUILD_NAME}.url")
file(WRITE "${DASHBOARD_BUILD_URL_FILE}" "$ENV{BUILD_URL}")
ctest_upload(FILES "${DASHBOARD_BUILD_URL_FILE}" QUIET)

ctest_submit(RETRY_COUNT 4 RETRY_DELAY 15
  RETURN_VALUE DASHBOARD_SUPERBUILD_SUBMIT_RETURN_VALUE QUIET)

set(DASHBOARD_SUPERBUILD_FAILURE ${DASHBOARD_FAILURE})

#END superbuild

###############################################################################

#BEGIN drake

set(DASHBOARD_STEPS "")
list(APPEND DASHBOARD_STEPS "BUILDING")
string(REPLACE ";" " / " DASHBOARD_STEPS_STRING "${DASHBOARD_STEPS}")

if(DASHBOARD_SUPERBUILD_FAILURE)
  set(DASHBOARD_START_MESSAGE "*** CTest Status: NOT CONTINUING BECAUSE SUPERBUILD (PRE-DRAKE) WAS NOT SUCCESSFUL")
else()
  set(DASHBOARD_PROJECT_NAME "Drake")

  # now start the actual drake build
  set(CTEST_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}/drake")
  set(CTEST_BINARY_DIRECTORY "${DASHBOARD_WORKSPACE}/build/drake")

  # switch the dashboard to the drake only dashboard
  set(CTEST_BUILD_NAME "${DASHBOARD_BUILD_NAME}-drake")
  set(CTEST_PROJECT_NAME "${DASHBOARD_PROJECT_NAME}")
  set(CTEST_NIGHTLY_START_TIME "${DASHBOARD_NIGHTLY_START_TIME}")
  set(CTEST_DROP_METHOD "https")
  set(CTEST_DROP_SITE "${DASHBOARD_CDASH_SERVER}")
  set(CTEST_DROP_LOCATION "/submit.php?project=${DASHBOARD_PROJECT_NAME}")
  set(CTEST_DROP_SITE_CDASH ON)

  if(COMPILER MATCHES "^scan-build")
    file(REMOVE_RECURSE "${DASHBOARD_CCC_ANALYZER_HTML}")
    file(MAKE_DIRECTORY "${DASHBOARD_CCC_ANALYZER_HTML}")
  endif()

  set(DASHBOARD_START_MESSAGE "*** CTest Status: ${DASHBOARD_STEPS_STRING} DRAKE")
endif()

message("
  ------------------------------------------------------------------------------
  ${DASHBOARD_START_MESSAGE}
  ------------------------------------------------------------------------------
  ")

if(NOT DASHBOARD_SUPERBUILD_FAILURE)
  ctest_start("${DASHBOARD_MODEL}" TRACK "${DASHBOARD_TRACK}" QUIET)
  ctest_update(SOURCE "${CTEST_SOURCE_DIRECTORY}"
    RETURN_VALUE DASHBOARD_UPDATE_RETURN_VALUE QUIET)

  ctest_read_custom_files("${CTEST_BINARY_DIRECTORY}")

  set(CTEST_BUILD_COMMAND
    "${DASHBOARD_WORKSPACE}/drake/common/test/cpplint_wrapper.py")

  set(CTEST_CUSTOM_MAXIMUM_NUMBER_OF_ERRORS 1000)
  set(CTEST_CUSTOM_MAXIMUM_NUMBER_OF_WARNINGS 1000)

  set(CTEST_CUSTOM_ERROR_MATCH
    "TOTAL [0-9]+ files checked, found [1-9][0-9]* warnings"
    ${CTEST_CUSTOM_ERROR_MATCH}
  )

  ctest_build(APPEND NUMBER_ERRORS DASHBOARD_NUMBER_BUILD_ERRORS
    NUMBER_WARNINGS DASHBOARD_NUMBER_BUILD_WARNINGS QUIET)
  if(DASHBOARD_NUMBER_BUILD_ERRORS GREATER 0)
    set(DASHBOARD_FAILURE ON)
    list(APPEND DASHBOARD_FAILURES "BUILD")
  endif()

  # Submit the results of cpplint
  set(DASHBOARD_BUILD_URL_FILE
    "${CTEST_BINARY_DIRECTORY}/${DASHBOARD_BUILD_NAME}.url")
  file(WRITE "${DASHBOARD_BUILD_URL_FILE}" "$ENV{BUILD_URL}")
  ctest_upload(FILES "${DASHBOARD_BUILD_URL_FILE}" QUIET)

  ctest_submit(RETRY_COUNT 4 RETRY_DELAY 15
    RETURN_VALUE DASHBOARD_SUBMIT_RETURN_VALUE QUIET)
endif()

#END drake

###############################################################################

#BEGIN reporting

set(DASHBOARD_WARNING OFF)

if(DASHBOARD_FAILURE)
  string(REPLACE ";" " / " DASHBOARD_FAILURES_STRING "${DASHBOARD_FAILURES}")
  set(DASHBOARD_MESSAGE "FAILURE DURING ${DASHBOARD_FAILURES_STRING}")
  file(WRITE "${DASHBOARD_WORKSPACE}/FAILURE")
else()
  if(DASHBOARD_NUMBER_BUILD_WARNINGS EQUAL 1)
    set(DASHBOARD_WARNING ON)
    set(DASHBOARD_MESSAGE "SUCCESS BUT WITH 1 BUILD WARNING")
  elseif(DASHBOARD_NUMBER_BUILD_WARNINGS GREATER 1)
    set(DASHBOARD_WARNING ON)
    set(DASHBOARD_MESSAGE "SUCCESS BUT WITH ${DASHBOARD_NUMBER_BUILD_WARNINGS} BUILD WARNINGS")
  else()
    set(DASHBOARD_MESSAGE "SUCCESS")
  endif()

  set(DASHBOARD_UNSTABLE OFF)
  set(DASHBOARD_UNSTABLES "")

  if(DASHBOARD_UNSTABLE)
    string(REPLACE ";" " / " DASHBOARD_UNSTABLES_STRING "${DASHBOARD_UNSTABLES}")
    set(DASHBOARD_MESSAGE
      "UNSTABLE DUE TO ${DASHBOARD_UNSTABLES_STRING} FAILURES")
    file(WRITE "${DASHBOARD_WORKSPACE}/UNSTABLE")
  else()
    file(WRITE "${DASHBOARD_WORKSPACE}/SUCCESS")
  endif()
endif()

set(DASHBOARD_MESSAGE "*** CTest Result: ${DASHBOARD_MESSAGE}")

if(DASHBOARD_LABEL)
  set(DASHBOARD_CDASH_SUPERBUILD_URL_MESSAGE
    "*** CDash Superbuild URL: https://${DASHBOARD_CDASH_SERVER}/index.php?project=${DASHBOARD_SUPERBUILD_PROJECT_NAME}&showfilters=1&filtercount=2&showfilters=1&filtercombine=and&field1=label&compare1=61&value1=${DASHBOARD_LABEL}&field2=buildstarttime&compare2=84&value2=now")
else()
  set(DASHBOARD_CDASH_SUPERBUILD_URL_MESSAGE "*** CDash Superbuild URL:")
endif()

if(NOT DASHBOARD_SUPERBUILD_FAILURE AND DASHBOARD_LABEL)
  set(DASHBOARD_CDASH_URL_MESSAGE
    "*** CDash URL: https://${DASHBOARD_CDASH_SERVER}/index.php?project=${DASHBOARD_PROJECT_NAME}&showfilters=1&filtercount=2&showfilters=1&filtercombine=and&field1=label&compare1=61&value1=${DASHBOARD_LABEL}&field2=buildstarttime&compare2=84&value2=now")
else()
  set(DASHBOARD_CDASH_URL_MESSAGE "*** CDash URL:")
endif()

# Report build result and CDash links
message("
  ------------------------------------------------------------------------------
  ${DASHBOARD_MESSAGE}
  ------------------------------------------------------------------------------
  ${DASHBOARD_CDASH_SUPERBUILD_URL_MESSAGE}
  ------------------------------------------------------------------------------
  ${DASHBOARD_CDASH_URL_MESSAGE}
  ------------------------------------------------------------------------------
  ")

#END reporting
