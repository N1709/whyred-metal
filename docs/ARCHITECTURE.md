# Architecture and what is reused from hakios

```
 a Metal program / CoreAnimation
   |  MTLDevice plug-in (HakiosMetal.m style)               userland, MIT, adapted
   v
 hakios-metal core (command.hpp, compute.hpp, render.hpp)   userland, MIT: Metal model -> packets
   |  a5xx register/packet layer  (REWRITE: a6xx.hpp -> a5xx)
   |  AIR -> NIR -> ir3 (Mesa, chip table already has 509)  userland, reused as is
   v
 gpu.hpp   GEM buffers, submit, fences  = the msm DRM requests                  userland, reused
   |  IOKit user client calls (selector = DRM request number)
   v
 WhyredGPU service (WhyredGPU.cpp)                           kernel, APSL, adapted (chip independent)
   |  four selectors: info / buffer new / buffer free / submit
   v
 chip driver (whyred_gpu.c for the Adreno 509)               kernel, REWRITE for A5xx
   |  clocks, GDSC, SMMU, ring, microcode, zap (SCM), CP start, submit, fence
   v
 Adreno 509 (A5xx, no GMU)
```

## The seam

`WhyredGPU.cpp` (the IOKit service and user client) never touches a register. It calls the chip driver
through a small C interface (`whyred_gpu_service_ready`, `whyred_gpu_service_submit`) and exposes four
selectors to userland:

| Selector | Direction | Meaning |
| --- | --- | --- |
| 0 `kWhyredInfo` | out | version, ready, submit count, last fence |
| 1 `kWhyredBufNew` | in/out | allocate a physically contiguous, zeroed, mappable buffer; return its GPU address |
| 2 `kWhyredBufFree` | in | release a buffer handle |
| 3 `kWhyredSubmit` | in/out | PM4 words, then a cache flush and a fence; returns when the GPU reaches the fence |

The long-term Metal path replaces these four selectors with the msm DRM request numbers used by
`hakios.gpu.cpp` (`DRM_MSM_GET_PARAM`, `GEM_NEW`, `GEM_SUBMIT`, `WAIT_FENCE`, ...). The four-selector
service is the bring-up interface: one trusted client, no security boundary.

## What changes for A5xx (the chip driver)

| hakios (A6xx, 642L) | Adreno 509 |
| --- | --- |
| GMU: firmware load, HFI queues, power requests | **absent.** The core is powered by the GX GDSC plus clock/rail votes; the GPMU is only for the 530 |
| SQE microcode (`a660_sqe.fw`) | PM4 + PFP microcode (`a530_pm4.fw`, `a530_pfp.fw`), loaded into the CP's instruction memory by register writes |
| zap shader through SCM PAS, then "out of secure mode" | the same idea (pas-id 13, `a512_zap`), same SCM sequence |
| SMMU: Qualcomm hypervisor mediates | kgsl SMMU at `0x05040000`, no hypervisor in the way expected on SDM636 (to confirm) |
| ring/CP start (`step_core_start`) | A5xx `hw_init`: `CP_ME_INIT`, `CP_SET_PROTECTED_MODE`, `RBBM` setup; different register set |
| fence/timestamps | `CP_EVENT_WRITE` / `CP_MEM_WRITE` fence; A5xx layout |

The step-ladder method of hakios stays: every step behind a boot-arg (`whyredgpu=N`), reads before
writes, one line saying what it is about to touch and what it found, and stop at the first step that
does not find what it expects. A wrong access on a Qualcomm SoC often ends the run silently, so the log
ring must flush before each risky access.

The ladder in this repository runs through the panel copy and the IOKit service. The ios-whyred port
currently carries the power/ring/compute/render subset in `xnu/patches/0211-whyred-gpu-driver.patch`;
the panel copy and the service are not merged there yet.

## What changes for userland

`a6xx.hpp` (374 KB, checked against Mesa's `a6xx.xml.h`) is replaced by an `a5xx.hpp` generated from
Mesa's `a5xx.xml` and checked the same way (`tools/gen_a5xx.py`). `compute.hpp` and `render.hpp` are
rewritten against Gallium's `fd5` sequences (`fd5_compute.c`, `fd5_emit.c`, `fd5_gmem.c`) because turnip
never supported A5xx. The fake GPU (an interpreter as strict as the command processor) is kept: most of
the A5xx work is validated on the host. The ir3 compiler path needs no chip port (Mesa carries
`GPUId(509)`); only the compile target is selected.

## Licensing split

| Part | License | Origin |
| --- | --- | --- |
| Kernel service and chip driver | APSL 2.0 (derivative of XNU) | adapted from hakios `drivers/gpu/` |
| Userland Metal layer, a5xx tables | MIT | adapted from `hakios-metal/`, Mesa (MIT) |
| Firmware | not distributed | read from the user's own stock ROM |

GPL code (Linux msm, metal2vulkan) is used only as reading material, never copied. The bring-up order is
derived from the Linux msm `a5xx` driver and Mesa freedreno for this device; every whyred register value
comes from the whyred DTS or the Adreno 509 entry in Linux `a5xx_catalog.c`.
