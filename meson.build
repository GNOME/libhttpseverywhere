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

project('httpseverywhere', 'vala', 'c', meson_version : '>=0.39.1', license: 'LGPL')

pkgconfig = import('pkgconfig')

api = '0.8'

# This isn't libtool. To keep things simple, we can use the same version
# number for the soname as our actual version. But it requires that we
# generally follow libtool semantics: bump the first version whenever
# breaking ABI, bump the second version whenever adding new API, bump
# the third version for every release.
libhttpseverywhere_version = '0.8.3'

glib = dependency('glib-2.0')
gobject = dependency('gobject-2.0')
json_glib = dependency('json-glib-1.0')
soup = dependency('libsoup-2.4')
gio = dependency('gio-2.0')
gee = dependency('gee-0.8')
archive = dependency('libarchive')

subdir('src')
subdir('test')

pkgconfig.generate(libraries : httpseverywhere_lib,
                   version : libhttpseverywhere_version,
                   name : 'libhttpseverywhere',
                   filebase : meson.current_build_dir()+'/httpseverywhere-'+api,
                   requires : 'glib-2.0 gobject-2.0 gio-2.0 json-glib-1.0 libsoup-2.4 gee-0.8 libarchive',
                   subdirs: 'httpseverywhere-'+api,
                   description : 'A library to rewrite HTTP URLs to HTTPS URLs.',
                   install: true)

install_data('data/default.rulesets', install_dir: get_option('datadir') + '/libhttpseverywhere')
install_data('httpseverywhere-'+api+'.deps', install_dir: get_option('datadir') + '/vala/vapi')
