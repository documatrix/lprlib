set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/lpr_send")
set (GETTEXT_PACKAGE "lpr_send")
set (CMAKE_C_FLAGS "")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")

configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
include_directories( ${CMAKE_SOURCE_DIR}/src )
add_definitions (${DEPS_CFLAGS})
link_libraries ( ${DEPS_LIBRARIES} ${LPR_SEND_NAME} )
link_directories ( ${DEPS_LIBRARY_DIRS} )
find_package (Vala REQUIRED)
include( UseVala )

set (TEST_LPR_SEND_SOURCES ${TEST_LPR_SEND_SOURCES} test_lpr_send.vala)

vala_precompile(TEST_LPR_SEND_VALA_C
  ${TEST_LPR_SEND_SOURCES}
PACKAGES
  ${VALA_PACKAGES} ${LPR_SEND_NAME}
OPTIONS
${VALA_ARGS} --vapidir=${CMAKE_SOURCE_DIR}/src
CUSTOM_VAPIS
  ${CUSTOM_VAPIS_LIST}
)

add_executable(
  test_lpr_send
  ${TEST_LPR_SEND_VALA_C}
)

ADD_DEPENDENCIES( test_lpr_send test_lpr_send_preprocessed )
ADD_CUSTOM_TARGET( test_lpr_send_preprocessed DEPENDS test_lpr_send.vala )
ADD_CUSTOM_COMMAND(
    SOURCE tests/test_lpr_send.vala
    OUTPUT tests/test_lpr_send.vala
    COMMAND perl ../../../../dm_logger/src/preprocess_logger.pl ${CMAKE_SOURCE_DIR}/tests/ ../log/messages.mdb
)

install(TARGETS
  test_lpr_send
RUNTIME DESTINATION
  bin/
)

if(HAVE_VALADOC)
  valadoc(lpr_send
    ${CMAKE_BINARY_DIR}/valadoc/lpr_send
    ${APP_SOURCES}
  PACKAGES
    ${VALA_PACKAGES}
  CUSTOM_VAPIS
    ${CUSTOM_VAPIS_LIST}
  )
  install(DIRECTORY
    ${CMAKE_BINARY_DIR}/valadoc
  DESTINATION
    share/doc/lpr_send
  )
endif()
