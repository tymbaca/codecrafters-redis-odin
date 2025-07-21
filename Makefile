run: build
	./main.bin

build:
	odin build src -out:main.bin -collection:src=src
