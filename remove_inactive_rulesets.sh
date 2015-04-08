#!/bin/sh

grep -ri "default_off=\"" | cut -f 1 | sed -e 's/\.xml:.*$/.xml/' | grep .xml$ | xargs -I{} rm {}

grep -ri "default_off=\'" | cut -f 1 | sed -e 's/\.xml:.*$/.xml/' | grep .xml$ | xargs -I{} rm {}
