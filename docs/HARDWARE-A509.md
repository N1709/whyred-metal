# Adreno 509 on the Redmi Note 5 (whyred, SDM636): what the hardware needs

Sources: the whyred Android device tree (the register map transcribed in
`ios-whyred/drivers/gpu/hw.md` and `ios-whyred/drivers/gpu/adreno/native/GpuRegs.h`), the Linux
`a5xx_catalog.c` entry for chip id `0x05000900`, and Mesa's `freedreno_devices.py`. The UEFI stub DTB in
`ios-whyred/resources/whyred_dtb.bin` has no GPU node; use the full Android DTS for the pwrlevel table.

**Nothing here is measured on the running whyred iOS port yet.** It is the map the first ladder run must
confirm. Values shared with other A5xx parts are marked as such; the frequency table is whyred's own.

## The GPU node (`/soc/qcom,kgsl-3d0@5000000`)

| Item | Value | Source / note |
| --- | --- | --- |
| compatible | `qcom,kgsl-3d0`, `qcom,kgsl-3d` | whyred DTS |
| Chip id | `0x05000900` (Adreno 5xx, **509**, rev 1.0) | whyred DTS; Linux `a5xx_catalog.c` |
| Registers | `0x05000000`, size `0x40000` | `kgsl_3d0_reg_memory` |
| Interrupt | SPI 300 (`interrupts = <0 0x12c 0>`, GIC intid 332) | whyred DTS |
| GPU clock controller | `0x05065000`, size `0x10000` | `gfx@5065000` / `clock-controller@5065000` |
| CX GDSC | `0x05066004` (`gdsc_gpu_cx`), status through hw-ctrl at `0x05066008` | `msm-gdsc-660.dtsi` |
| GX GDSC | `0x05066094` (`gdsc_gpu_gx`) | `msm-gdsc-660.dtsi` |
| GFX LDO | `0x0506e000`, size `0x34` (`qcom,sdm660-gfx-ldo`) | inside the GPUCC window at `+0x9000` |
| kgsl SMMU | `0x05040000`, size `0x10000`, `qcom,kgsl-smmu-v2` | whyred DTS |
| SMMU context bank | `gfx3d_user`, SID 0, `gpu-offset 0x48000` | whyred DTS |
| Zap pas-id | 13 (`qcom,pil-tz-generic`) | whyred DTS |
| Zap firmware | `a512_zap.mdt` | Linux: "Adreno 509 uses the same ZAP as 512" |
| CP / PFP microcode | `a530_pm4.fw`, `a530_pfp.fw` | Linux `a5xx_catalog.c` |
| GPMU firmware | **none** | only the 530 has one |
| GMEM | 256 KiB + 16 KiB (278528 bytes) | Linux `a5xx_catalog.c` |
| Idle period | 250 ms ("avoids bouncing the GDSC which appears to make it grumpy") | Linux `a5xx_catalog.c` |
| Quirk | `LMLOADKILL_DISABLE` | Linux; matches the DT `gpu-quirk-lmloadkill-disable` |

## Clocks

| Name | Provider | Note |
| --- | --- | --- |
| `core_clk` | `gpucc-sdm660` (`gfx@5065000`), index `0xd` | the GFX3D RCG |
| `iface_clk` | GCC (`clock-controller@100000`), index `0x42` | GPU AHB/interface |
| `rbbmtimer_clk` | `gpucc-sdm660`, index `0xe` | RBBM timer |
| `mem_clk` | GCC, index `0x40` | GPU memory path |
| `alt_mem_iface_clk` | GCC, index `0x20` | alternate memory interface |
| `rbcpr_clk` | `gpu-sdm660` (`clock-controller@5065000`), index `1` | CPR helper |

The driver talks to these blocks through raw MMIO, not a clock framework:

- GCC base `0x00100000`, size `0x94000`; GPU AHB gate at `+0x71004` (bit 0), GPU BIMC votes at
  `+0x71010` and `+0x7106c`.
- GPUCC base `0x05065000`; GFX3D branch `+0x1098` (bit 0), RCG command `+0x1070`, RBBM timer branch
  `+0x10d0`, RBCPR branch `+0x1054`, CX clock `+0x1020`.
- GDSC CX `+0x1004` / hw status `+0x1008`; GDSC GX `+0x1094`; GX clamp `+0x0130`; GX reset `+0x1090`.

## Frequencies

**Do not assume another A5xx frequency table.** The whyred DTS carries its own `qcom,gpu-pwrlevels-*`; read it
with `tools/dtb_dump.py` and record the exact frequencies, corners and initial level here before the
first power-up run.

What is already known:

- The speed-bin fuse is at `qfprom 0x00780000`, size `0x6220`; the DTS names the cell with
  `qcom,gpu-speed-bin = <0x41a0 0x1fe00000 0x15>`.
- The DTS picks an initial power level; start there, as Android does, instead of jumping to the maximum.
- `qcom,gfxfreq-corner` maps frequency to a CPR corner. Raising the clock without raising the corner
  first is the classic way to hang the SoC.

## Power rails

- `vddcx-supply` -> GDSC `gdsc_gpu_cx`.
- `vdd-supply` -> GDSC `gdsc_gpu_gx` (`domain-addr`, `sw-reset`, `retain-periph`).
- The GFX corner supplies (`vdd_gfx`, `vdd_dig_gfx`, `vdd_mx_gfx`) are RPM/CPR regulators. The GX GDSC's
  parent is `gfx_corner` (CPR4 `qcom,cpr4-sdm660-mmss-ldo-regulator`), whose `vdd-thread0-ldo-supply` is
  the `msm_gfx_ldo` block at `0x0506e000`.
- Also present: `qcom,gpu-cx-ipeak` (shared CX current limiter) and the `grp3d` bus votes (`gpubw`).

The port has no RPM/CPR regulator framework. The first ladder therefore asks a narrow question: is the
bootloader's rail/corner state enough to read the GPU block? Raising the frequency is a later step.

## IOMMU

- `qcom,kgsl-smmu-v2` at `0x05040000`, `qcom,micro-mmu-control`, `secure_align_mask 0xfff`, retention.
- Context banks: `gfx3d_user` (SID 0, `gpu-offset 0x48000`) and `gfx3d_secure` (SID 2). This is the GPU's
  own SMMU, separate from the system SMMU.
- The SMMU needs the same bus clocks as the core (`iface_clk`, `mem_clk`, `alt_mem_iface_clk`).

## Zap shader (secure world)

`/soc/qcom,kgsl-hyp` is `qcom,pil-tz-generic`, **`qcom,pas-id = 13`**, `qcom,firmware-name = "a512_zap"`.
The zap shader is loaded through TrustZone (SCM PAS calls) and switches the GPU out of secure mode so the
CP can run. The A509 uses the A512 zap image; this is stated in the Linux catalog and is not a whyred
guess.

The port already has an SCM PAS implementation in `xnu/patches/0113-topaz-modem-pas-boot.patch`
(`TopazModem.cpp`): `smc #0`, `0x42000000 | svc << 8 | cmd`, and the sequence
`IS_SUPPORTED -> INIT_IMAGE -> MEM_SETUP -> AUTH_RESET -> SHUTDOWN`. The open question is whether SDM636
TrustZone accepts that convention from our kernel. `IS_SUPPORTED` for PAS 13 is the first secure-world
check.

## Firmware

`tools/extract-gpu-fw.sh` pulls these from the user's own `vendor.img` into `firmware/` (not committed).
Record the whyred sizes and SHA256; the sizes below are the A5xx family expectations, not a whyred
measurement.

| Role | File | Used by a509? |
| --- | --- | --- |
| CP micro-engine (PM4) microcode | `a530_pm4.fw` | **yes** |
| Prefetch parser microcode | `a530_pfp.fw` | **yes** |
| Zap shader, split PIL form | `a512_zap.mdt` + `.b00/.b01/.b02` (`.elf` is the same image) | **yes** |
| GPMU firmware | `a530v3_gpmu.fw2`, `a530_gpmu.fw2` | **no** |
| GPMU sequencer data | `a530v2_seq.fw2`, `a530v3_seq.fw2` | **no** |

Other facts from the Linux entry: GMEM 256 KiB + 16 KiB, `inactive_period` 250 ms, quirk
`LMLOADKILL_DISABLE`. `a508_zap.*` and `a540_gpmu.fw2` belong to other chips.

## What Mesa knows about the chip

`src/freedreno/common/freedreno_devices.py` (Mesa `main`) puts `GPUId(509)` and `GPUId(512)` in one
`A5xxGPUInfo` group: `num_sp_cores = 2`, `highest_bank_bit = 14`, `reg_size_vec4 = 96`,
`wave_granularity = 1`. The ir3 compiler and the Gallium `fd5` driver therefore already know the chip;
only the Metal front end has to be written. `highest_bank_bit = 14` matches the whyred DT.

## What the port already has / lacks

Has (from ios-whyred): eMMC/ADMA2, USB, display through the MDP, PMIC keys/RTC, touch bring-up, GIC and
timers, an empty `IOAcceleratorES`, and the SCM PAS code from the modem driver.

- **SCM / TrustZone:** see above; `IS_SUPPORTED` is the gate.
- **Clocks and power:** the port programs GCC/GDSC registers directly. The same style works for the GPU:
  GDSCs at `0x05066004` (CX) and `0x05066094` (GX), GPUCC at `0x05065000`.
- **SMMU:** the port owns no SMMU (USB and eMMC run untranslated). The GPU's kgsl SMMU has to be
  programmed by the GPU driver itself.
- **GX rail / CPR:** nothing in the port handles RPM regulators. The bootloader's corner may be enough
  at a low clock; raising it needs a corner/rail vote. Open.

The first power-up patch is read-only: map `0x05000000`, power CX/GX and the three bus clocks, then read the
CP/RBBM identification registers to learn whether the block is reachable at all.
