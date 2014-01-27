#! /bin/sh

LIBDIR="$(dirname $(dirname $0))/lib/node_modules"
if ! echo "$NODE_PATH" | grep -q "$LIBDIR"; then
    if test -z "$NODE_PATH"; then
        NODE_PATH="$LIBDIR"
    else
        NODE_PATH="$NODE_PATH:$LIBDIR"
    fi
    export NODE_PATH
fi

if [ "$#" -gt 0 ]; then
    command="$1"
    shift
fi

if which nodejs > /dev/null; then
    nodejs -e "require('meteor-shower').main('$command', '$*')"
else if which node > /dev/null; then
    node -e "require('meteor-shower').main('$command', '$*')"
else
    echo "you kind of need node to run this"
fi fi
