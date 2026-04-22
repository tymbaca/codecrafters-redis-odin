BUILD_FLAGS := "-collection:src=src -collection:lib=lib -debug"
OUT := "bin/debug"

run: build
    @./{{OUT}}

test: build-test
    @./{{OUT}}

build:
    @mkdir bin 2> /dev/null || true
    @odin build src -out:{{OUT}} {{BUILD_FLAGS}}

build-test:
    @mkdir bin 2> /dev/null || true
    @odin build tests -out:{{OUT}} {{BUILD_FLAGS}} -build-mode:test -all-packages -define:ODIN_TEST_FANCY=false
