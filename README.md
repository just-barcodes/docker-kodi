# just-barcodes/docker-kodi

Dockerized [Kodi](https://kodi.tv/) with audio and video.

## Features

* fully-functional [Kodi](https://kodi.tv/) installation in a container
* **audio** (PipeWire, PulseAudio or [ALSA](https://kodi.wiki/view/Linux_audio)) and **video** (with optional OpenGL
  hardware video acceleration) via [x11docker](https://github.com/mviereck/x11docker/)
* simple Ubuntu 26.04 LTS image using the Kodi packages available in the Ubuntu repositories
* clean shutdown of Kodi when its container is terminated
* runs as an unprivileged user, with no third-party package repositories
* `Makefile` helpers for local Podman build and `x11docker` execution

## Host Prerequisites

The host system will need the following:

1. **Linux** and [**Podman**](https://podman.io/)

   The `Makefile` helpers use rootless Podman. [Docker](https://www.docker.com) works too if you build the image and
   run `x11docker` by hand.
   
1. **A connected display and speaker(s)**

   If you're looking for a headless Kodi installation, look elsewhere!

1. **[X](https://www.x.org/) or [Wayland](https://wayland.freedesktop.org/)**

   `make run` attaches to your *running* Wayland session. If you use `x11docker --xorg` instead, only the X server
   packages need to be installed; `x11docker` starts a fresh X server itself.

1. **PipeWire** (for `make run`) or **PulseAudio**

   `make run` uses `x11docker --pipewire`, which needs `pw-container` from PipeWire on the host. On a PulseAudio host,
   run `x11docker` by hand with `--pulseaudio` as shown below.

1. **[x11docker](https://github.com/mviereck/x11docker/)**

   `x11docker` allows containerized applications to utilize X and/or Wayland on the host. Please follow the `x11docker` 
   [installation instructions](https://github.com/mviereck/x11docker#installation) and ensure that you have a 
   [working setup](https://github.com/mviereck/x11docker#examples) on the host.
       
## Usage

### Starting Kodi

The image is not published to a registry. Build it locally with Podman:

    $ make build

This tags the image as `localhost/just-barcodes/kodi`. The `localhost/` prefix means the container runtime will never
try to pull an image of that name from a registry.

Then use `x11docker` to start it. The quickest way is the Makefile helper, which starts Kodi in your running Wayland
session with PipeWire sound, hardware video acceleration, network access, and a persistent Kodi home directory in
`~/Videos/kodi` (override with `KODI_HOME=/some/path`):

    $ make run

Detailing the myriad of `x11docker` options is beyond the scope of this document; please consult the
[`x11docker` documentation](https://github.com/mviereck/x11docker/) to find the set of options that work for your
setup. Below is an example command (split into multiple lines for clarity) that starts Kodi with a fresh X.Org X server
with PulseAudio sound (use `--pipewire` on a PipeWire host), hardware video acceleration, a persistent Kodi home
directory, and a shared read-only mount for media files:

    $ x11docker --xorg                                 \
                --pulseaudio                           \
                --gpu                                  \
                --home=/host/path/to/kodi/home         \
                -- -v /host/path/to/media:/media:ro -- \
                localhost/just-barcodes/kodi
           
Note that the optional argument passed between a pair of `--` defines additional arguments to be passed to the container runtime.

### Stopping Kodi

You can shut down Kodi just as you normally would; i.e. by using the power menu from the Kodi home screen. 
Behind the scenes, the container and `x11docker` processes will terminate cleanly.

You can also [terminate the container from the command line](doc/advanced.md#command-line-shutdown).

### Example systemd Service Unit

Build the image with `make build` before enabling the unit. Do not add a `podman pull` step: nothing publishes this
image, so a pull would fetch whatever a registry happens to serve under that name.

Rootless Podman stores images per user, so the unit must run as the user who ran `make build`. Use `--xorg` here:
`x11docker` then starts its own X server from the console, and no desktop session is required.

    [Unit]
    Description=Dockerized Kodi
    After=network.target
    
    [Service]
    User=kodi-user
    ExecStart=/usr/bin/x11docker --xorg --pulseaudio --gpu --home=/home/kodi-user/kodi localhost/just-barcodes/kodi
    Restart=always
    KillMode=process
    
    [Install]
    WantedBy=multi-user.target

Replace `kodi-user` with that user and `--pulseaudio` with `--pipewire` on a PipeWire host.

## Security Notes

* `x11docker` runs the container as your own (unprivileged) host user, drops all capabilities, and disables network
  access unless `--network` is given. Run the image through `x11docker`; a plain `podman run` has no display and gets
  none of that hardening, although the image itself still starts Kodi as an unprivileged user.
* Any container with sound access can record the microphone and the audio of other applications. This is inherent
  to giving a media player sound. On a PipeWire host use `--pipewire`, which hands the container a restricted socket;
  on a PulseAudio host use plain `--pulseaudio` (a dedicated socket). `--pulseaudio=host` shares your session's
  primary socket and cookie and is the least isolated choice.
* Kodi needs outbound network access, and `--network` also makes the rest of your LAN reachable from the container.
  If you enable Kodi's web interface, set a password and do not publish its port.
* `--gpu` shares the host GPU devices with the container. That is required for hardware video acceleration.

## Advanced

The [advanced topics](doc/advanced.md) documentation describes a few more useful features and functionality:

 * [Custom add-ons](doc/advanced.md#custom-add-ons)
 * [Image Variants](doc/advanced.md#image-variants)
 * [Custom Startup Behavior](doc/advanced.md#custom-startup-behavior)
 * [Command-Line Shutdown](doc/advanced.md#command-line-shutdown)

## Help!

Something not working quite right? Are you stuck? Please
[open an issue](https://github.com/just-barcodes/docker-kodi/issues).

## Contributing

Constructive criticism and contributions are welcome! Please 
[submit an issue](https://github.com/just-barcodes/docker-kodi/issues/new) or 
[pull request](https://github.com/just-barcodes/docker-kodi/compare).

CI runs shellcheck, hadolint, an image build, and the integration tests in `tests/test-image.sh`. To run the same
checks locally:

    $ shellcheck -s bash entrypoint.sh tests/*.sh
    $ hadolint Dockerfile
    $ make build
    $ tests/test-image.sh
