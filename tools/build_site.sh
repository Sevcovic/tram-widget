#!/bin/sh
# Prepare site/public for deploy: copy the Scriptable script and pack the source zip.
set -e
cd "$(dirname "$0")/.."
cp scriptable/TramWidget.js site/public/TramWidget.js
git archive --format=zip --prefix=tram-widget/ HEAD -o site/public/tram-widget-source.zip
echo "site/public ready: $(ls site/public | tr '\n' ' ')"
