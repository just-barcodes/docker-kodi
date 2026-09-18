.PHONY: help
help:
	@echo "Possible targets"
	@echo "	- build"
	@echo "	- run"

# localhost/ so that the container runtime never tries to pull this name from a registry
IMAGE ?= localhost/just-barcodes/kodi
# --pull=always so that a rebuild picks up the current Ubuntu base image
PODMAN_BUILD_FLAGS ?= --cgroup-manager=cgroupfs --pull=always
KODI_HOME ?= $(HOME)/Videos/kodi

.PHONY: build
build:
	podman build $(PODMAN_BUILD_FLAGS) . -t "$(IMAGE)"

.PHONY: run
run:
	x11docker --wayland --backend=podman --pipewire --gpu --home="$(KODI_HOME)" --network "$(IMAGE)"
