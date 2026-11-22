# Hardware map log

2026-11-22
- whyred-metal created for the Redmi Note 5 (whyred, SDM636, Adreno 509). This log records the hardware
  map and the first power-up plan; no device run yet.
- Register map from `ios-whyred/drivers/gpu/hw.md` and
  `ios-whyred/drivers/gpu/adreno/native/GpuRegs.h`: kgsl-3d0 at `0x05000000` (size `0x40000`), chip id
  `0x05000900`, IRQ SPI 300, GPUCC at `0x05065000` (size `0x10000`), GDSC CX at `+0x1004` (hw status
  `+0x1008`), GDSC GX at `+0x1094`, gfx_ldo at `0x0506e000` (GPUCC `+0x9000`), kgsl SMMU at
  `0x05040000`, zap pas-id 13.
- Linux `a5xx_catalog.c`: chip `0x05000900` uses `a530_pm4.fw`, `a530_pfp.fw`, zap `a512_zap.mdt`
  (the 509 shares the 512 zap), GMEM 256 KiB + 16 KiB, quirk `LMLOADKILL_DISABLE`, inactive period
  250 ms, no GPMU firmware.
- Mesa `freedreno_devices.py`: `GPUId(509)` and `GPUId(512)` share
  `A5xxGPUInfo(num_sp_cores = 2, highest_bank_bit = 14, reg_size_vec4 = 96, wave_granularity = 1)`.
- Open: extract and hash the whyred `vendor.img` firmware; read the whyred `qcom,gpu-pwrlevels-*`
  table; confirm the SCM PAS convention; no device run yet.
