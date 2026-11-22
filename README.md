# whyred-metal

GPU bring-up for the **Redmi Note 5 (whyred, Snapdragon 636, Adreno 509)** running iOS 16 through the
[ios-whyred](https://github.com/N1709/ios-whyred) port: an Adreno 509 kernel driver for XNU and a
Metal-compatible layer on top of it, so that iOS stops drawing everything on the CPU.

This repository is a **fresh rewrite for whyred**. The bring-up ladder was first assembled and proven on the
Redmi Note 7 (lavender, Adreno 512); no commit from that repository is carried here. The code, names, hardware
constants and documents below are being reworked for the Adreno 509. See `docs/REFERENCES.md` for provenance.

## Why

The port boots to the iOS 16 lock screen, but there is no GPU: `MTLCreateSystemDefaultDevice()` returns nil and
QuartzCore falls back to its software OpenGL renderer (`CA::OGL::SW`). The CPU compositor is the main cost on the
idle lock screen and the reason wallpapers that need Metal (Astronomy, ...) fail. See `ios-whyred/README.md`,
section *Performance*.

## Status

**No result in this table is a whyred device measurement yet.** The ladder and host tests exist; the first run on
whyred is still to be done.

| Area | Status | Notes |
| --- | --- | --- |
| Hardware map | Partial | GPU node, chip id, GPUCC, GDSCs, SMMU and zap pas-id are known from the whyred DTS (`drivers/gpu/hw.md` in ios-whyred). The whyred `vendor.img` firmware has not been extracted and hashed yet. |
| Power and identify | Code ready, not run | `whyredgpu=1..4`, off by default. Expected chip id `0x05000900`. |
| Ring, microcode, fence | Code ready, not run | Zap through SCM PAS 13, kgsl SMMU identity table, PM4/PFP, ring, `ME_INIT`, fence. |
| A5xx compute | Host tests pass, device pending | `userland/tests/cp_test.cpp` passes; no dispatch on whyred yet. |
| Render and panel | Code ready, device pending | 2D blit, textured 3D draw, blending, panel copy. |
| IOKit service | Code ready, device pending | `WhyredGPU` / `WhyredGPUUserClient`, four selectors, synchronous submit. |
| Metal plug-in | Not started | `MTLDevice` plug-in and CoreAnimation acceptance. |

The status of the **port** (display, touch, USB, audio, WLAN, modem, power) lives in
[ios-whyred](https://github.com/N1709/ios-whyred), not here. This repository is only the GPU.

## What is different from lavender

| | lavender (A512) | whyred (A509) |
| --- | --- | --- |
| SoC | SDM660 | SDM636 |
| GPU | Adreno 512, chip id `0x05010200` | Adreno 509, chip id `0x05000900` |
| GPU block | `0x05000000`, 256 KiB | `0x05000000`, 256 KiB |
| GPUCC | `0x05065000` | `0x05065000` |
| Zap | `a512_zap.mdt` | `a512_zap.mdt` (Linux: "Adreno 509 uses the same ZAP as 512") |
| PM4/PFP | `a530_pm4.fw`, `a530_pfp.fw` | same |
| GPMU | none | none |
| Panel | 1080x2340, stride 4320 | 1080x2160, stride 4320 |
| Board define | `ARM64_BOARD_CONFIG_LAVENDER` | `ARM64_BOARD_CONFIG_WHYRED` |
| Boot arg | `lavgpu=N` | `whyredgpu=N` |
| Firmware path | `/usr/share/firmware/lavender/gpu/` | `/usr/share/firmware/whyred/gpu/` |

The GPU frequency ladder is **not** copied from lavender. Read `qcom,gpu-pwrlevels-*` from the whyred DTS and
record it in `docs/HARDWARE-A509.md` before the first power-up run.

## Starting point

[`oosexgang/hakios-xnu-kernel`](https://github.com/oosexgang/hakios-xnu-kernel) (`hakios-metal/`, MIT, and the
kernel side in `drivers/gpu/`, APSL) is a working Metal driver for **Adreno A6xx** (Adreno 642L, GMU): the Metal
command model, compute, textures, render passes, an AIR -> NIR -> ir3 shader compiler built on Mesa, and the
`MTLDevice` plug-in. It is the architecture we follow, not code that runs on this GPU:

| | hakios (A6xx) | this device (A5xx) |
| --- | --- | --- |
| Power-up | GMU | no GMU: CP/PFP microcode, zap shader through TrustZone |
| Registers / packets | `a6xx.hpp`, `CP_LOAD_STATE6` | `a5xx.xml`, `CP_LOAD_STATE4` |
| Reference for sequences | turnip (Vulkan) | none (turnip never supported A5xx): Gallium `fd5` |
| SoC GPU rails | SC7280 | SDM636: `gpucc-sdm660`, CPR `gfx` corner, `gfx_ldo` |

The reference tree is kept (sparse, not committed) under `refs/hakios` at the commit recorded in
`docs/REFERENCES.md`.

## Roadmap

Details and "done when" criteria per milestone are in [`docs/PLAN.md`](docs/PLAN.md).

- **Hardware map:** register map done; whyred firmware extraction and pwrlevel table pending.
- **Power and identify:** power the GDSCs/clocks, read the chip id, confirm PAS 13. Not run on whyred.
- **Ring, microcode, fence:** load the zap through SCM, set up the kgsl SMMU, load PM4/PFP, start the CP,
  read a fence. Not run on whyred.
- **A5xx compute:** generated tables and fake CP pass on the host; one real dispatch pending.
- **Render and panel:** blit/draw/blend paths are written; panel output pending.
- **IOKit service:** service and user client are written; device registration pending.
- **Metal plug-in:** not started.

## Related repositories

- [N1709/ios-whyred](https://github.com/N1709/ios-whyred): the iOS 16 port for the Redmi Note 5 that this GPU
  work serves. The kernel ladder is built into the port as `drivers/gpu/whyred_gpu.c` (patch `0211`); the IOKit
  service in this repository is not merged there yet.
- [pcorezzola/lavender-metal](https://github.com/pcorezzola/lavender-metal): the Adreno 512 bring-up that proved
  the ladder on lavender. It is a reference for the sequence, not a source of commits for this repository.
- This repository: research, host-side tests and the plan; no firmware or Qualcomm blobs are committed.

## Layout

```
docs/       plan, hardware notes, references
refs/       reference trees (not committed; see docs/REFERENCES.md)
firmware/   GPU firmware taken from the phone's own ROM (not committed)
tools/      scripts (firmware extraction, DTB reading, table generation)
kernel/     XNU chip driver (whyred_gpu.c) and IOKit service (WhyredGPU.cpp)
userland/   A5xx register/packet layer, fake CP, host tests
notes/      working notes per milestone
```

## Legal

Apple binaries and the phone's firmware are not distributed. Firmware is read from the user's own stock ROM.
Kernel code derived from XNU stays under the APSL; user-space code is MIT. See `docs/REFERENCES.md` and
`NOTICE` for upstream licenses.
