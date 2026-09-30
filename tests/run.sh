#!/bin/sh
# Runs every test: the QML ones under Qt 6's qmltestrunner (offscreen, no
# compositor needed) and the file-tree checks under unittest.
#
#     tests/run.sh
set -e
cd "$(dirname "$0")"

export QT_QPA_PLATFORM=offscreen

# Distros put the Qt 6 runner in different places, and plain `qmltestrunner`
# is often Qt 5's (which cannot read these files), so look for the Qt 6 one.
RUNNER=""
for c in qmltestrunner6 /usr/lib/qt6/bin/qmltestrunner /usr/lib64/qt6/bin/qmltestrunner /usr/lib/x86_64-linux-gnu/qt6/bin/qmltestrunner; do
    if command -v "$c" >/dev/null 2>&1; then
        RUNNER=$(command -v "$c")
        break
    fi
done
if [ -z "$RUNNER" ] && command -v qtpaths6 >/dev/null 2>&1; then
    c="$(qtpaths6 --binaries-dir)/qmltestrunner"
    [ -x "$c" ] && RUNNER="$c"
fi

if [ -z "$RUNNER" ]; then
    echo "Qt 6 qmltestrunner not found (it ships with qt6-declarative); skipping the QML tests" >&2
else
    "$RUNNER" -input . -platform offscreen
fi

python3 -m unittest -v test_files test_install test_bind test_usage_scripts
python3 check_site.py
