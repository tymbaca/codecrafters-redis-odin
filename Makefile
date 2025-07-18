run:

build:
	odin build src -out:main.bin -collection:src=src
	./main.bin
