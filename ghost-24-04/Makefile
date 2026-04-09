all: build

# Paths assume this Makefile lives in ghost-24-04/; run `make` from this directory.
build:
	cd .. && packer build ghost-24-04/template.json

validate:
	cd .. && packer validate ghost-24-04/template.json
