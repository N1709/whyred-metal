# Power-up log

No whyred run yet.

First run order, one boot-arg step per boot:

1. `whyredgpu=1` - read-only GCC/GPUCC state. Confirms the AHB clock gate and that the GPUCC registers
   decode as GDSC/branch registers.
2. `whyredgpu=2` - vote `gcc_gpu_bimc_gfx_clk` and `gcc_bimc_gfx_clk`; check the halt bits.
3. `whyredgpu=3` - switch the CX GDSC on.
4. `whyredgpu=4` - switch the GX GDSC on, release the GMEM clamp, enable the GFX3D/RBBM timer branches,
   then read the RBBM/CP registers at `0x05000000`.

Expected on the first successful step 4: the live log prints chip id `0x05000900` and the CP/RBBM
identification registers, with no hang and no change to boot time.

If GX does not power: stop, keep the ladder collapsed, and inspect `gfx_ldo` (`0x0506e000 + 0x9000`)
and the CPR `gfx` corner. Do not raise the GPU clock before the corner.

Record for every run: boot arg, live-log timestamps, boot time to the lock screen, and whether
SpringBoard still advances. A run that stalls the compositor is a failure even if the GPU line printed.
