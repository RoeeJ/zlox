#!/bin/bash
npx nodemon -w src -w ./test.lox -w ./test_parser.lox -w ./build.zig -e '*' --exec "reset && zig build test --summary all || exit 1"
