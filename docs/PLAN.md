# Plan

Goal: replace the CPU compositor with the Adreno 509, through a Metal-compatible driver, on the
ios-whyred port. Success is measured, not assumed: `backboardd` CPU and presented fps at the idle lock
screen, and whether wallpapers that need Metal (Astronomy) run.

Each stage is testable on its own and ends with a number or a log line, not a feeling.

## Hardware map

- [x] Register map from the whyred DTS: GPU block `0x05000000`, GPUCC `0x05065000`, GDSCs, kgsl SMMU
      `0x05040000`, IRQ SPI 300, zap pas-id 13 (`docs/HARDWARE-A509.md`).
- [x] Chip identity from Linux and Mesa: `0x05000900`, `a530_pm4.fw` / `a530_pfp.fw`, `a512_zap.mdt`,
      no GPMU, GMEM 256 KiB + 16 KiB, `GPUId(509)`.
- [x] hakios split: the IOKit service is chip independent; only the chip driver is rewritten
      (`docs/ARCHITECTURE.md`).
- [ ] Extract the whyred `vendor.img` firmware and record sizes + SHA256 (`tools/extract-gpu-fw.sh`).
- [ ] Read `qcom,gpu-pwrlevels-*` from the whyred DTS and record the exact frequency/corner table.
- [ ] Confirm which SCM PAS convention whyred TrustZone accepts (the modem driver is the reference).

Result: every resource and where it comes from is listed before the first register write.

## Power and identify

- XNU driver `whyred_gpu.c` behind `whyredgpu=N`, off by default.
- Enable the GPU clocks and the CX/GX GDSCs, map the register block, read chip id / CP version / RBBM
  status. Read-only first.
- Done when: the live log prints chip id `0x05000900` from the real hardware, with no hang and no change
  to boot time.

## Ring, microcode, fence

- Load the zap shader through SCM, set up the kgsl SMMU stage-1 identity table, load PM4/PFP, start the
  CP, send `ME_INIT`, leave secure mode.
- A command stream that makes the CP write a value to memory (the fence), polled from the CPU.
- Done when: a CP-written word is read back, repeatably, and a deliberate hang is recovered with a GPU
  reset without a reboot.

## A5xx layer and compute

- `a5xx` register and PM4 packet layer generated from Mesa's `a5xx.xml`, checked against it.
- Fake CP / GPU interpreter and host tests, so most work does not need a flash.
- Compute dispatch from the fd5/computerator sequence; one real kernel compared to a host reference.
- Done when: a kernel's output on the phone is identical to the host reference.

## Render and panel

- 2D blit (`CP_BLIT`), RGBA8 rectangle copy, sysmem 3D draw, texture sampling, interpolated texture
  coordinates, colour blending.
- Copy the GPU-rendered target into the real scanout (stride 4320 is not a multiple of 64, so the RB
  renders into an aligned buffer and the CPU copies it up).
- Done when: the GPU's output is visible on the whyred panel with the expected channel order.

## IOKit service

- `WhyredGPU` service and `WhyredGPUUserClient`: info / buffer new / buffer free / submit.
- Submit is synchronous: PM4 stream, cache flush, fence; the call returns when the GPU reaches the fence.
- Done when: a userland client opens the service, allocates a buffer, submits a stream and reads the
  fence on whyred.

## Plug-in Metal

- `MTLDevice` plug-in over the IOKit service; CoreAnimation over Metal.
- Done when: `MTLCreateSystemDefaultDevice()` returns a device, the idle lock screen costs a fraction of
  today's CPU, and Astronomy renders.

## Risks (ordered)

1. Zap shader / secure world: the GPU may stay in secure mode without it. Needs an SCM path from XNU.
2. GX power domain on SDM636 (CPR, `gfx_ldo`): wrong sequencing can hang the SoC.
3. SMMU: the GPU context bank must coexist with whatever the port already set up.
4. A5xx has no turnip witness: sequences come from Gallium fd5 and must be validated on hardware.
5. iOS side: which Metal entry points CoreAnimation actually needs.

## Rules of work

- Every driver feature is behind a boot-arg and off by default; the stock shim keeps booting.
- One variable per flash; keep the log ring and live log on.
- Prefer the fake GPU and host tests; flash only to answer a question the host cannot.
