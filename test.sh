#!/bin/bash
npx nodemon -w src -w ./test.lox -e '*' --exec "reset && zig test src/lox_test.zig || exit 1"
