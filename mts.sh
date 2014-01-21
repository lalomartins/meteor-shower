#! /bin/sh

if which nodejs > /dev/null; then
    nodejs -e 'require("coffee-script"); require("meteor-shower").main()'
else if which node > /dev/null; then
    nodejs -e 'require("coffee-script"); require("meteor-shower").main()'
else
    echo "you kind of need node to run this"
fi fi
