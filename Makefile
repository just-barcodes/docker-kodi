.PHONY: help
help:
	@echo "Possible targets"
	@echo "	- build"
	@echo "	- run"

.PHONY: build
build:
	podman build . -t just-barcodes/kodi

.PHONY: run
run:
	x11docker --wayland --backend=podman --pulseaudio=host --gpu --home=~/Videos/kodi --network just-barcodes/kodi

