# Advanced Topics

This page details available features that most users won't likely need.

* [Custom add-ons](#custom-add-ons)
* [Image Variants](#image-variants)
* [Custom Startup Behavior](#custom-startup-behavior)
* [Command-Line Shutdown](#command-line-shutdown)

---

## Custom add-ons

In an effort to control the size of this image, some optional Kodi add-ons (e.g. PVRs, audio formats, screensavers, games, and visualizations) are not bundled by default. If we included each add-on, the image would grow to over 1 GB in size and continue to expand over time.

Since this image is based on Linux, add-ons will [need to be installed manually](https://kodi.wiki/view/Ubuntu_binary_add-ons). So how can you install the add-ons you need? Easily build your own custom image using the `KODI_EXTRA_PACKAGES` [build argument](https://docs.docker.com/engine/reference/commandline/build/#set-build-time-variables---build-arg). Its value is a space-separated list of additional packages that you'd like to install into the image.

As an example, let's say that you want to run Kodi using this image, but you also want the [IPTV Simple PVR add-on](https://kodi.wiki/view/Add-on:IPTV_Simple_PVR) and a [Libretro core](https://kodi.wiki/view/Libretro) for SNES. You could build a custom image using the command:

```shell script
podman build .                                                                    \
         --build-arg KODI_EXTRA_PACKAGES="kodi-pvr-iptvsimple kodi-game-libretro-bsnes-mercury-performance" \
         -t just-barcodes/kodi:custom
```

Add-on package names can be discovered with `apt-cache search '^kodi-'` inside an Ubuntu 24.04 environment, and you can install *any* Ubuntu package that you'd like.

## Image Variants

This fork currently tracks the Kodi packages shipped by Ubuntu 24.04.

| Image | Kodi |
|-------|------|
| `just-barcodes/kodi` | v20 "Nexus" package stream from Ubuntu 24.04 |

## Custom Startup Behavior

By default, the container will invoke `kodi-standalone` upon startup. This will boot Kodi and should work 
well for most installations. If you would like to customize this behavior, you can utilize the environment variable 
`KODI_COMMAND` to call additional scripts or processes before starting Kodi. For example, to reduce the priority of the 
Kodi process:

    $ x11docker ... -- '--cap-add SYS_NICE --env KODI_COMMAND="nice kodi-standalone"' just-barcodes/kodi
    
## Command-Line Shutdown

There are two ways to stop the running Kodi container from the command line:

1. **(Preferred) Send `SIGHUP` or `SIGTERM` to the `x11docker` process.** 

       $ kill -SIGTERM <pid>

   **WARNING**: If you run `x11docker` from a terminal, **do not use `Ctrl-C`**  to end the process as this will cause 
   Kodi to crash spectacularly. Instead, open another shell and use `kill`.
   
1. **Use `podman stop`**
   
       $ podman stop <containerid>
       
When the container receives a signal to terminate, from either of the two means above, it will ask Kodi to shut down 
gracefully and wait for up to 10 seconds before timing out and allowing the container runtime to forcefully terminate the container. 
Usually Kodi only takes a few seconds to shut down, so 10 seconds should be plenty of time. However if you would like to
extend this timeout for any reason, you can utilize the environment variable `KODI_QUIT_TIMEOUT`. For example, to wait 
120 seconds before timing out:

    $ x11docker ... -- '--env KODI_QUIT_TIMEOUT=120' just-barcodes/kodi
    
Note that if you increase this timeout, you should *only* stop Kodi with `podman stop` *and* use its `--time` option to 
match your desired timeout. e.g.

    $ podman stop --time=120 <containerid>
    
Unless you really need more than 10 seconds, and for simplicity's sake, it's better to signal `x11docker` instead of 
using `podman stop`.
