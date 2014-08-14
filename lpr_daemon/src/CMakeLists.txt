set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/lpr_daemon")
set (GETTEXT_PACKAGE "lpr_daemon")
set (CMAKE_C_FLAGS "-g -O3")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")

configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
add_definitions (${DEPS_CFLAGS})
link_libraries ( ${DEPS_LIBRARIES} )
link_directories ( ${DEPS_LIBRARY_DIRS} )
find_package (Vala REQUIRED)
include( UseVala )

set (LPR_DAEMON_SOURCES ${LPR_DAEMON_SOURCES} lpr_daemon.vala)

vala_precompile(LPR_DAEMON_VALA_C
  ${LPR_DAEMON_SOURCES}
PACKAGES
  ${VALA_PACKAGES}
GENERATE_VAPI
  ${LPR_DAEMON_NAME}
CUSTOM_VAPIS
  ${CUSTOM_VAPIS_LIST}
GENERATE_HEADER
  lpr_daemon
OPTIONS
  ${VALA_ARGS}
)

add_library(
  ${LPR_DAEMON_NAME} SHARED
  ${LPR_DAEMON_VALA_C}
)

# CREATE PKGCONFIG FILES
if(NOT DEFINED CMAKE_INSTALL_LIBDIR)
  set(CMAKE_INSTALL_LIBDIR lib)
endif(NOT DEFINED CMAKE_INSTALL_LIBDIR)
set(prefix       ${CMAKE_INSTALL_PREFIX})
set(exec_prefix ${CMAKE_INSTALL_PREFIX})
set(libdir       ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR})
set(includedir  ${CMAKE_INSTALL_PREFIX}/include)
set(LIBS         "")
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/liblpr_daemon.pc.in
  ${CMAKE_CURRENT_BINARY_DIR}/${LPR_DAEMON_NAME}.pc @ONLY)

ADD_DEPENDENCIES( ${LPR_DAEMON_NAME} lpr_daemon_preprocessed )
ADD_CUSTOM_TARGET( lpr_daemon_preprocessed DEPENDS lpr_daemon.vala )
ADD_CUSTOM_COMMAND(
    SOURCE src/lpr_daemon.vala
    OUTPUT src/lpr_daemon.vala
    COMMAND perl ../../../../dm_logger/src/preprocess_logger.pl ${CMAKE_SOURCE_DIR}/src/ ../log/messages.mdb
)

# Install shared object
install(
TARGETS
 ${LPR_DAEMON_NAME}
LIBRARY ARCHIVE DESTINATION
  lib/
)

# Install header files
install(
FILES
  ${CMAKE_CURRENT_BINARY_DIR}/lpr_daemon.h
DESTINATION
  include/${LPR_DAEMON_NAME}/
)

# Install vapi files
install(
FILES
  ${CMAKE_CURRENT_BINARY_DIR}/${LPR_DAEMON_NAME}.vapi
DESTINATION
  ${CMAKE_INSTALL_PREFIX}/share/vala/vapi/
)

# Install pkg-config file...
install( FILES
  ${CMAKE_CURRENT_BINARY_DIR}/${LPR_DAEMON_NAME}.pc
DESTINATION
  ${CMAKE_INSTALL_LIBDIR}/pkgconfig
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
