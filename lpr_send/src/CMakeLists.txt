set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/lpr_send")
set (GETTEXT_PACKAGE "lpr_send")
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

set (LPR_SEND_SOURCES ${LPR_SEND_SOURCES} lpr_send.vala)

vala_precompile(LPR_SEND_VALA_C
  ${LPR_SEND_SOURCES}
PACKAGES
  ${VALA_PACKAGES}
GENERATE_VAPI
  ${LPR_SEND_NAME}
CUSTOM_VAPIS
  ${CUSTOM_VAPIS_LIST}
GENERATE_HEADER
  lpr_send
OPTIONS
  ${VALA_ARGS}
)

add_library(
  ${LPR_SEND_NAME} SHARED
  ${LPR_SEND_VALA_C}
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
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/liblpr_send.pc.in
  ${CMAKE_CURRENT_BINARY_DIR}/${LPR_SEND_NAME}.pc @ONLY)

ADD_DEPENDENCIES( ${LPR_SEND_NAME} lpr_send_preprocessed )
ADD_CUSTOM_TARGET( lpr_send_preprocessed DEPENDS lpr_send.vala )
ADD_CUSTOM_COMMAND(
    SOURCE src/lpr_send.vala
    OUTPUT src/lpr_send.vala
    COMMAND perl ../../../../dm_logger/src/preprocess_logger.pl ${CMAKE_SOURCE_DIR}/src/ ../log/messages.mdb
)

if(${CMAKE_SYSTEM_NAME} STREQUAL Windows)
# Install shared object
install(
TARGETS
  ${LPR_SEND_NAME}
LIBRARY ARCHIVE DESTINATION
lib/ 
)
else()
# Install shared object
install(
TARGETS
  ${LPR_SEND_NAME}
LIBRARY DESTINATION
lib/
)
endif( )

# Install header files
install(
FILES
  ${CMAKE_CURRENT_BINARY_DIR}/lpr_send.h
DESTINATION
  include/${LPR_SEND_NAME}/
)

# Install vapi files
install(
FILES
  ${CMAKE_CURRENT_BINARY_DIR}/${LPR_SEND_NAME}.vapi
DESTINATION
  ${CMAKE_INSTALL_PREFIX}/share/vala/vapi/
)

# Install pkg-config file...
install( FILES
  ${CMAKE_CURRENT_BINARY_DIR}/${LPR_SEND_NAME}.pc
DESTINATION
  ${CMAKE_INSTALL_LIBDIR}/pkgconfig
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
