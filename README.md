libhttpseverywhere
==================

[![Packaging status](https://repology.org/badge/vertical-allrepos/libhttpseverywhere.svg)](https://repology.org/metapackage/libhttpseverywhere)

This library enables you to leverage the power of
[HTTPSEverywhere](https://www.eff.org/https-everywhere) to any desktop-application you want

HTTPSEverywhere is a browser plugin that comes with a set of rules that you can use to ensure that
you use HTTP instead of HTTPS only when this is absolutely not circumventable.
With libhttpseverywhere you will get a C-bindable, GLib-based library you can
link/bind against in almost all languages

As a library written in Vala, libhttpseverywhere will support GObject-Introspection. This means
that you can use the lib in many popular languages like e.g. Ruby, Python or Javascript.

Current Users
-------------

  * [Rainbow Lollipop](http://rainbow-lollipop.de) - An experimental visual history browser.
  * [GNOME Web](https://wiki.gnome.org/Apps/Web) - The default Browser of the GNOME Desktop

Documentation
-------------

You can either generate the documentation as a devhelp-book for yourself (see Building-section)

Dependencies
------------

The following libraries have to be present for libhttpseverywhere to run:

  * glib-2.0
  * gee-0.8
  * json-glib-1.0
  * libsoup-2.4
  * libarchive

The library names are in pkg-config notation

Building
--------

[Meson](http://mesonbuild.com) is used as the buildsystem for libhttpseverywhere. The build dependencies
are the following:

  * c-compiler of your choice
  * _valac_ - Vala compiler
  * _valadoc_ - Vala documentation tool
  * _gobject-introspection_ - GObject introspection compiler
  * _libgirepository1.0-dev_ - Dev headers for gobject introspection
  * _libjson-glib-dev_ - Dev headers for json-glib
  * _libsoup2.4-dev_ - Dev headers for libsoup-2.4
  * _libarchive-dev_ - Dev headers for libarchive

Italics are valid debian package names.

Clone and build the library as follows:

```
$ git clone https://git.gnome.org/browse/libhttpseverywhere
$ cd libhttpseverywhere
$ meson build && cd build
$ ninja
```

If you want to build the documentation, make sure you have valadoc available
on your system and call meson like this:

```
meson -Denable_valadoc=true build && cd build
```

If you desire to install the library, execute:

```
# ninja install
```


Running GI
----------

libhttpseverywhere supports GObject-Introspection which means you can consume it in various
popular languages including but not limited to: Python, Perl, Lua, JS, PHP.

Feel free to add examples for your favorite language in an example folder.

Note: If you installed the library in /usr/local, you have to export the following
environment variables for the examples to work:

```
$ export LD_LIBRARY_PATH=/usr/local/lib/x86_64-linux-gnu
$ export GI_TYPELIB_PATH=/usr/local/lib/x86_64-linux-gnu/girepository-1.0/
```
You will also have to adapt the multiarch-string `x86_64-linux-gnu` if you built the
software for another architecture.
