#********************************************************************+
# Copyright 2016 Daniel 'grindhold' Brendle
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

project ('httpseverywhere', 'vala','c')

pkgconfig = import('pkgconfig')

api = '0.2'

glib = dependency('glib-2.0')
gobject = dependency('gobject-2.0')
json_glib = dependency('json-glib-1.0')
libxml = dependency('libxml-2.0')
soup = dependency('libsoup-2.4')
gio = dependency('gio-2.0')
gee = dependency('gee-0.8')
archive = dependency('libarchive')

httpseverywhere_lib_source = [
    'src/context.vala',
    'src/ruleset.vala',
    'src/update.vala'
]

httpseverywhere_test_source = [
    'test/main.vala'
]

add_global_arguments('-w', language:'c')

run_command ('mkdir', meson.current_build_dir()+'/httpseverywhere-'+api)

httpseverywhere_lib = library('httpseverywhere-'+api, httpseverywhere_lib_source,
                              dependencies: [glib, gobject, json_glib, libxml, soup, gio, gee, archive],
                              vala_args: ['--gir=' + '../HTTPSEverywhere-'+api+'.gir', '-H', 'httpseverywhere-'+api+'/httpseverywhere.h'],
                              install: true)

httpseverywhere_test = executable('httpseverywhere_test', httpseverywhere_test_source,
                                  dependencies: [glib, gobject, gio, gee, libxml],
                                  include_directories: include_directories('@0@/httpseverywhere-@1@'.format(meson.current_build_dir(), api)),
                                  link_with: httpseverywhere_lib)

g_ir_compiler = find_program('g-ir-compiler')
custom_target('httpseverywhere-typelib',
               command: [g_ir_compiler, '--output', '@OUTPUT@', 'HTTPSEverywhere-' + api + '.gir', '--shared-library', get_option('prefix') + '/' + get_option('libdir') + '/libhttpseverywhere-' + api + '.so'],
               output: 'HTTPSEverywhere-' + api + '.typelib',
               depends: httpseverywhere_lib,
               install: true,
               install_dir: get_option('libdir') + '/girepository-1.0')


valadoc = find_program('valadoc')
custom_target('apidocs',
               input: httpseverywhere_lib_source,
               command: [valadoc, '-o', 'devhelp/httpseverywhere-0.2', '--doclet', 'devhelp', '@INPUT@',
               '--force', '--pkg', 'gee-0.8', '--pkg', 'json-glib-1.0', '--pkg', 'libxml-2.0', '--pkg', 'libarchive', '--pkg', 'libsoup-2.4'],
               output: 'devhelp',
)

pkgconfig.generate(libraries : httpseverywhere_lib,
              version : api,
              name : 'libhttpseverywhere',
              filebase : meson.current_build_dir()+'/httpseverywhere-'+api,
              requires : 'glib-2.0 gobject-2.0 gio-2.0 json-glib-1.0 libxml-2.0 libsoup-2.4 gee-0.8 libarchive',
              subdirs: 'httpseverywhere-'+api,
              description : 'A library to rewrite HTTP URLs to HTTPS URLs.',
              install: true)

install_headers(meson.current_build_dir()+'/httpseverywhere-'+api+'/httpseverywhere.h', subdir: 'httpseverywhere-0.2')
install_subdir(meson.current_build_dir()+'/devhelp/httpseverywhere-'+api+'/httpseverywhere-'+api, install_dir: get_option('datadir')+'/devhelp/books')
install_data('httpseverywhere-'+api+'.deps', install_dir: get_option('datadir') + '/vala/vapi')
install_data(meson.current_build_dir()+'/httpseverywhere-'+api+'.vapi', install_dir: get_option('datadir') + '/vala/vapi')
install_data(meson.current_source_dir()+'/data/rulesets.json', install_dir: get_option('datadir') + '/libhttpseverywhere')
