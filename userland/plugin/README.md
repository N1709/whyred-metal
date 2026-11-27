# WhyredMetal.bundle

The Metal plug-in. Metal's own device registration matches `IOAcceleratorES`,
reads `MetalPluginName` / `MetalPluginClassName` from it, loads
`/System/Library/Extensions/WhyredMetal.bundle` and sends the device class
`-initWithAcceleratorPort:`. The kernel side is patch `0240`: it publishes
those properties only when a client asks with `whyredmetal=1`.

## Source

| File | What |
| --- | --- |
| `WhyredMetal.m` | the `MTLDevice` and the objects it makes: buffers, command queue, command buffer, blit and compute encoders. Built without ARC; the private `_MTL*` bases are made at load time. |
| `why5.c`, `why5.h` | the A5xx compute dispatch as PM4 |
| `why5r.c` | one render pass of one draw as PM4 |
| `whycc.cpp`, `whycc.h` | a `.metallib`'s functions compiled for the Adreno 509 |
| `hk/` | hakios-metal's AIR -> NIR -> ir3 compiler and command model (MIT) |
| `a5xx/` | Mesa's generated A5xx register headers (MIT) |
| `kernels/whyk.metallib` | the test compute library used by `whyredmetal_test` |

The service interface is the one in `kernel/WhyredGPU.cpp`: selectors 0-5,
same struct layouts as the kernel's `whyred_*`. The plug-in opens
`"WhyredGPU"` and keeps a 64 KiB stream buffer mapped.

## What was changed for whyred

The plug-in is adapted from
[`aLpHa-Git-69/lavender-metal`](https://github.com/aLpHa-Git-69/lavender-metal)
(`userland/`, MIT, Copyright (c) 2025-2026 the HakiOS authors) at `cc5b8db`:

- service `LavenderGPU` -> `WhyredGPU`; the bundle, classes and log are
  `WhyredMetal*`, `/var/root/whyredmetal.log`
- the compiler is built for GPU id `509` (`-DWHYRED_GPU_ID=509`), not `512`
- the device name is `Whyred Adreno 509`

The command streams and the A5xx register values are shared by the whole
A5xx family; they have not been run on whyred yet.

## Build (macOS)

The plug-in links Mesa's ir3 and hakios's AIR front end, so it needs the iOS
Mesa archives first:

```sh
# 1. the hakios Mesa patch tree (MIT)
git clone --depth 1 --filter=blob:none --sparse \
    https://github.com/oosexgang/hakios-xnu-kernel.git hakios
git -C hakios sparse-checkout set --no-cone components/metal/plugin/tools/mesa

# 2. Mesa 25.0.7 for arm64 iOS 16 (Xcode + iPhoneOS SDK)
B=/tmp/mi tools/mesa-ios/build-mac.sh hakios/components/metal/plugin/tools/mesa

# 3. the bundle and the test program
cd userland/plugin
bash build-whyredmetal.sh
```

`build-mac.sh` needs Xcode, `meson`, `ninja`, `mako`, `pyyaml` and a newer
bison; it installs what it can under `$B` (default `/tmp/mi`). The result is
`userland/plugin/out/WhyredMetal.bundle` and `out/whyredmetal_test`.

The `whymetal` workflow (`.github/workflows/whymetal.yml`) runs the same two
steps on a macOS runner and uploads `WhyredMetal.bundle` and
`whyredmetal_test` as artifacts, so the bundle can be built without a local
Mac.

## Install and run

Copy the bundle into the iOS root at
`/System/Library/Extensions/WhyredMetal.bundle` (with the root-image builder,
not a partition write), then boot:

```
whyredgpu=30 whyredmetal=1
```

The kernel properties must be set by a client; `whyredmetal_test` does that
and then checks the device, a buffer, a queue and a blit. Run it from the
iOS root:

```
/var/root/whyredmetal_test
```

Its log and the plug-in's log are `/var/root/whyredmetal.log`.

## Status

Source added, **not built and not run on whyred**. The kernel ladder itself
has never run on the phone, so the first gate is `whyredgpu=4`, then `12`,
then `30/31`; see `../README.md` and `../docs/PLAN.md`.

## License

MIT. `LICENSE` is the lavender-metal/hakios MIT text; `hk/LICENSE` and
`hk/NOTICE` cover the hakios-metal sources. Mesa's register headers keep
Mesa's MIT notice in the generated files.
