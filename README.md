libhttpseverywhere
==================

In the near future this library will enable you to leverage the power of 
[HTTPSEverywhere](https://www.eff.org/https-everywhere) to any desktop-application you want

HTTPSEverywhere is a browser plugin that comes with a set of rules that you can use to ensure that
you use HTTP instead of HTTPS only when this is absolutely not circumventable.
With libhttpseverywhere you will get a C-library you can link/bind against in almost all languages

libhttpseverywhere is being written to be used in [Rainbow Lollipop](http://rainbow-lollipop.de)

As a library written in Vala, libhttpseverywhere will support GObject-Introspection. This means
that you can use the lib in many popular languages like e.g. Ruby, Python or Javascript.

Current Status
--------------

There are still problems with complexer regexes, but I will fix them ASAP.

Dependencies
------------

The following libraries have to be present for libhttpseverywhere to run:

  * glib-2.0
  * json-glib-1.0
  * libxml-2.0
  * libsoup-2.4
  * gee-0.8
  * libarchive

Building
--------

[Meson](http://mesonbuild.com) is used as the buildsystem for libhttpseverywhere. The build dependencies
are the following:

  * valac - Vala compiler
  * valadoc - Vala documentation tool
  * g-ir-compiler - GObject introspection compiler
  * json-glib-dev - Dev headers for json-glib
  * libgirepository1.0-dev - Dev headers for gobject introspection

Clone and build the library as follows:

```
$ git clone https://github.com/grindhold/libhttpseverywhere
$ cd libhttpseverywhere
$ mkdir build
$ cd build
$ meson ..
$ ninja
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
