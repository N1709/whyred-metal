# References

| What | Where | License | Used for |
| --- | --- | --- | --- |
| hakios-xnu-kernel | https://github.com/oosexgang/hakios-xnu-kernel (commit `63fc2b4`, 2026-11-06) | `hakios-metal/` MIT; `drivers/gpu/`, `xnu/files/` APSL 2.0 | Architecture: Metal driver on Adreno A6xx, IOKit GPU service, AIR -> NIR -> ir3 front end, fake GPU, probe |
| lavender-metal | https://github.com/aLpHa-Git-69/lavender-metal (commit `cc5b8db`) | MIT (Copyright (c) 2025-2026 the HakiOS authors) | `userland/plugin/`: the Metal plug-in, A5xx PM4 builders, compiler wrapper and iOS Mesa build recipe, adapted and renamed for whyred |
| Mesa freedreno | https://gitlab.freedesktop.org/mesa/mesa (`src/freedreno/`) | MIT | `a5xx.xml`, `adreno_pm4.xml`, ir3 compiler, Gallium `fd5` (A5xx sequences), `freedreno_devices.py` |
| Linux msm DRM / a5xx | linux `drivers/gpu/drm/msm/adreno/a5xx_*.c` | GPL-2.0 | Behaviour reference only (bring-up order, firmware names); no code copied |
| whyred hardware map | `ios-whyred/drivers/gpu/hw.md`, `ios-whyred/drivers/gpu/adreno/native/GpuRegs.h` | n/a (project data) | GPU node, GPUCC, GDSCs, SMMU, IRQ, zap pas-id |
| whyred Android DTS | vendor kernel `arch/arm64/boot/dts/qcom/` (not committed) | n/a (device data) | pwrlevels, clocks, regulators |
| ios-whyred | https://github.com/N1709/ios-whyred | see repo | The port this driver plugs into |

## hakios reference tree

```sh
git clone --depth 1 --filter=blob:none --sparse https://github.com/oosexgang/hakios-xnu-kernel.git refs/hakios
cd refs/hakios
git sparse-checkout set --no-cone hakios-metal drivers/gpu docs/reference/metal.md \
    docs/driver-review/gpu-display.md /LICENSE /LICENSE.APSL /NOTICE /THIRD_PARTY_LICENSES.md xnu/files/iokit/Kernel
```

Files from it that are copied or adapted into this repository must keep their license header and be listed here.

## Reviewed and not adopted

| What | Where | License | Verdict |
| --- | --- | --- | --- |
| ASoftware iOS for Android | https://github.com/alpersamur3/asoft-ios-android | MIT | Runs iOS in QEMU inside an Android app; iOS 16 there also draws on the CPU. Its GPU path is for iOS 26 in Apple's research VM, over Vulkan on Mesa Turnip (Adreno 6xx and newer only). Not usable on a bare-metal A5xx. Only the fps reports in its `DEVICES.md` are useful as a yardstick (iOS 16 on the CPU: 3-51 fps depending on the phone). |
| metal2vulkan (upstream steelbrain/metal2vulkan; fork alpersamur3/metal2vulkan) | https://github.com/steelbrain/metal2vulkan | GPL-2.0-or-later OR LGPL-3.0-or-later | Rust: AIR/metallib -> SPIR-V plus "the Metal API on Vulkan" (`metal2vulkan-runtime`, needs a Vulkan 1.2 device). Adreno 509 has no Vulkan 1.2 driver here (Turnip has no A5xx), so it cannot be the backend. Worth reading as a second AIR front end (`metal2vulkan-air`) next to hakios's; copyleft, so nothing is copied into kernel or MIT code. |
| reims-vgpu | https://github.com/alpersamur3/reims-vgpu | NOASSERTION | Virtual GPU for VM guests; irrelevant to real hardware. |
| Chlorophyll (Bergamota iOS Metal driver) | https://github.com/ry-diffusion/Chlorophyll (commit `d3cb665`) | MIT (AIR front end from hackios-xnu-userland) | Metal over Mesa freedreno Gallium / Turnip on iOS, target Poco F1 (Adreno 630, A6xx). Nothing on SCM, GDSC, clocks or A5xx. Useful as a second reference for AIR -> NIR -> ir3 and the Darwin fixes in `patches/turnip-ios.patch` (no `CTR_EL0` at EL0), and for the kernel-side user-client idea (`SweetAdrenoUserClient`, lives in another repo). Related: UniXNU (Adreno 740), Snapintosh (A8xx, partly GPL: do not copy). Kernel bring-up for A5xx stays ours. |
