set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/lpr_daemon")
set (GETTEXT_PACKAGE "lpr_daemon")
set (CMAKE_C_FLAGS "")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")

configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
include_directories( ${CMAKE_SOURCE_DIR}/src )
add_definitions (${DEPS_CFLAGS})
link_libraries ( ${DEPS_LIBRARIES} ${LPR_DAEMON_NAME} )
link_directories ( ${DEPS_LIBRARY_DIRS} )
find_package (Vala REQUIRED)
include( UseVala )

set (TEST_LPR_DAEMON_SOURCES ${TEST_LPR_DAEMON_SOURCES} test_lpr_daemon.vala)

vala_precompile(TEST_LPR_DAEMON_VALA_C
  ${TEST_LPR_DAEMON_SOURCES}
PACKAGES
  ${VALA_PACKAGES} ${LPR_DAEMON_NAME}
OPTIONS
${VALA_ARGS} --vapidir=${CMAKE_SOURCE_DIR}/src
CUSTOM_VAPIS
  ${CUSTOM_VAPIS_LIST}
)

add_executable(
  test_lpr_daemon
  ${TEST_LPR_DAEMON_VALA_C}
)

ADD_DEPENDENCIES( test_lpr_daemon test_lpr_daemon_preprocessed )
ADD_CUSTOM_TARGET( test_lpr_daemon_preprocessed DEPENDS test_lpr_daemon.vala )
ADD_CUSTOM_COMMAND(
    SOURCE tests/test_lpr_daemon.vala
    OUTPUT tests/test_lpr_daemon.vala
    COMMAND perl ../../../../dm_logger/src/preprocess_logger.pl ${CMAKE_SOURCE_DIR}/tests/ ../log/messages.mdb
)

install(TARGETS
  test_lpr_daemon
RUNTIME DESTINATION
  bin/
)

if(HAVE_VALADOC)
  valadoc(lpr_daemon
    ${CMAKE_BINARY_DIR}/valadoc/lpr_daemon
    ${APP_SOURCES}
  PACKAGES
    ${VALA_PACKAGES}
  CUSTOM_VAPIS
    ${CUSTOM_VAPIS_LIST}
  )
  install(DIRECTORY
    ${CMAKE_BINARY_DIR}/valadoc
  DESTINATION
    share/doc/lpr_daemon
  )
endif()
