cmake_minimum_required (VERSION 2.6)
project(libhttpseverywhere C)

list(APPEND CMAKE_MODULE_PATH
    ${CMAKE_SOURCE_DIR}/cmake/vala
)

include(ValaPrecompile)
include(ValaVersion)

find_package(Vala REQUIRED)
ensure_vala_version("0.26" MINIMUM)

find_package(PkgConfig)

pkg_check_modules(GLIB REQUIRED glib-2.0)
add_definitions(${GLIB_CFLAGS} ${GLIB_CFLAGS_OTHER})
link_libraries(${GLIB_LIBRARIES})
link_directories(${GLIB_LIBRARY_DIRS})

pkg_check_modules(LIBXML2 REQUIRED libxml-2.0)
add_definitions(${LIBXML2_CFLAGS} ${LIBXML2_CFLAGS_OTHER})
link_libraries(${LIBXML2_LIBRARIES})
link_directories(${LIBXML2_LIBRARY_DIRS})

pkg_check_modules(GEE gee-0.8)
if (NOT GEE_FOUND)
    pkg_check_modules(GEE REQUIRED gee-1.0)
    SET(GEE10 TRUE)
endif()
add_definitions(${GEE_CFLAGS} ${GEE_CFLAGS_OTHER})
link_libraries(${GEE_LIBRARIES})
link_directories(${GEE_LIBRARY_DIRS})

if (GEE10)
    vala_precompile(VALA_LIB_C
        "src/dummy.vala"
        "src/https_everywhere.vala"
        "src/ruleset.vala"
    PACKAGES
        libxml-2.0
        gee-1.0
    OPTIONS
        --thread
        --library=httpseverywhere
        -H httpseverywhere.h
    )
else()
    vala_precompile(VALA_LIB_C
        "src/dummy.vala"
        "src/https_everywhere.vala"
        "src/ruleset.vala"
    PACKAGES
        libxml-2.0
        gee-0.8
    OPTIONS
        --thread
        --library=httpseverywhere
        -H httpseverywhere.h
    )
endif()

add_definitions(-fstack-protector-all -D_FORTIFY_SOURCE=2)

add_library("httpseverywhere" SHARED ${VALA_LIB_C})  
    
