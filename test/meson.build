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


httpseverywhere_test_source = [
    'main.vala'
]

httpseverywhere_test = executable('httpseverywhere_test', httpseverywhere_test_source,
                                  dependencies: [glib, gobject, gio, gee, json_glib],
                                  link_with: httpseverywhere_lib,
                                  include_directories: include_directories('../src'))
