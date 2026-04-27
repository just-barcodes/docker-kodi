.PHONY: help
help:
	@echo "Possible targets"
	@echo "	- build"
	@echo "	- run"

IMAGE ?= just-barcodes/kodi
PODMAN_BUILD_FLAGS ?= --cgroup-manager=cgroupfs
KODI_HOME ?= $(HOME)/Videos/kodi

.PHONY: build
build:
	podman build $(PODMAN_BUILD_FLAGS) . -t $(IMAGE)

.PHONY: run
run:
	x11docker --wayland --backend=podman --pulseaudio=host --gpu --home=$(KODI_HOME) --network $(IMAGE)
