cmake_minimum_required (VERSION 2.6)
project(libhttpseverywhere C)

SET(VERSION "0.1")

list(APPEND CMAKE_MODULE_PATH
    ${CMAKE_SOURCE_DIR}/cmake/vala
)

include(ValaPrecompile)
include(ValaVersion)

find_package(Vala REQUIRED)
ensure_vala_version("0.26" MINIMUM)
find_program(VALADOC_EXEC valadoc)

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
        --target-glib 2.32
        --library=httpseverywhere
        -H include/httpseverywhere.h
        --gir=HTTPSEverywhere-${VERSION}.gir
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
        --target-glib 2.32
        --library=httpseverywhere
        -H include/httpseverywhere.h
        --gir=HTTPSEverywhere-${VERSION}.gir
    )
endif()

if (GEE10)
    add_custom_target(docs
        COMMAND
            ${VALADOC_EXEC} -o doc --package-name=httpseverywhere --pkg libxml-2.0 --pkg gee-1.0
                src/https_everywhere.vala
                src/ruleset.vala
        COMMENT
            "Generating documentation"
    )
else()
    add_custom_target(docs
        COMMAND
            ${VALADOC_EXEC} -o doc --package-name=httpseverywhere --pkg libxml-2.0 --pkg gee-0.8
                src/https_everywhere.vala
                src/ruleset.vala
        COMMENT
            "Generating documentation"
    )
endif()

add_definitions(-fstack-protector-all -D_FORTIFY_SOURCE=2 -fPIC)
add_definitions(-w)

add_library("httpseverywhere" SHARED ${VALA_LIB_C})  

add_custom_target(rulesets ALL
    COMMAND
        git submodule init
    COMMAND
        git submodule update
    COMMAND
        sh remove_inactive_rulesets.sh
    COMMENT
        "Fetching Rulesets"
)    
        

add_custom_target(typelib ALL
    COMMAND
        g-ir-compiler --shared-library=libhttpseverywhere.so HTTPSEverywhere-${VERSION}.gir
                      -o HTTPSEverywhere-${VERSION}.typelib
    DEPENDS
        "httpseverywhere"
    COMMENT
        "Creating typelib"
)

install(DIRECTORY "https-everywhere/src/chrome/content/rules" DESTINATION share/${PROJECT_NAME})
install(FILES "include/httpseverywhere.h" DESTINATION include )
install(FILES HTTPSEverywhere-${VERSION}.typelib DESTINATION lib/girepository-1.0)
install(TARGETS "httpseverywhere"
    LIBRARY DESTINATION lib
)

