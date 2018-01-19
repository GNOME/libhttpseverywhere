#********************************************************************+
# Copyright 2016-2018 Daniel 'grindhold' Brendle
#
# This file is part of libhttpseverywhere.
#
# libhttpseverywhere is free software: you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation, either
# version 3 of the License, or (at your option) any later
# version.
#
# libhttpseverywhere is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with libhttpseverywhere.
# If not, see http://www.gnu.org/licenses/.
#*********************************************************************


httpseverywhere_lib_source = [
    'context.vala',
    'ruleset.vala',
    'update.vala'
]

valagir = 'HTTPSEverywhere-' + api + '.gir'

httpseverywhere_lib = shared_library('httpseverywhere-'+api, httpseverywhere_lib_source,
                                     dependencies: [glib, gobject, json_glib, soup, gio, gee, archive],
                                     vala_gir: valagir,
                                     vala_header: 'httpseverywhere.h',
                                     install: true,
                                     version: libhttpseverywhere_version)

g_ir_compiler = find_program('g-ir-compiler')
custom_target('httpseverywhere-typelib',
               command: [g_ir_compiler, '--output', '@OUTPUT@', 'src/'+valagir, '--shared-library', 'libhttpseverywhere-' + api + '.so'],
               output: 'HTTPSEverywhere-' + api + '.typelib',
               depends: httpseverywhere_lib,
               install: true,
               install_dir: get_option('libdir') + '/girepository-1.0')

if get_option('enable_valadoc')
	valadoc = find_program('valadoc')
	custom_target('apidocs',
                   input: httpseverywhere_lib_source,
                   command: [valadoc, '-o', 'devhelp/httpseverywhere-'+api, '--doclet', 'devhelp', '@INPUT@',
                   '--force', '--pkg', 'gee-0.8', '--pkg', 'json-glib-1.0', '--pkg', 'libarchive', '--pkg', 'libsoup-2.4'],
                   output: 'devhelp',
                   build_by_default: true)
  install_subdir(meson.current_build_dir()+'/../devhelp/httpseverywhere-'+api+'/httpseverywhere-'+api,
                 install_dir: get_option('datadir')+'/devhelp/books')
endif

# Create an empty httpseverywhere.h file in the build dir to satisfy
# install_headers that the file exists. Remove when this PR is merged:
# https://github.com/mesonbuild/meson/pull/1469
httpseverywhere_h = meson.current_build_dir()+'/httpseverywhere.h'
run_command ('touch', httpseverywhere_h)
install_headers(httpseverywhere_h, subdir: 'httpseverywhere-'+api)

# Create an empty httpseverywhere.vapi file in the build dir to satisfy
# install_data that the file exists. Remove when this PR is merged:
# https://github.com/mesonbuild/meson/pull/1469
httpseverywhere_vapi = meson.current_build_dir()+'/httpseverywhere-'+api+'.vapi'
run_command ('touch', httpseverywhere_vapi)
install_data(httpseverywhere_vapi, install_dir: get_option('datadir') + '/vala/vapi')

