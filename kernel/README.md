# Kernel snapshots

`whyred_gpu.c` and `WhyredGPU.cpp` are copies of the files the ios-whyred
patch series ships: the ladder from `0211`, the service from `0217`, and the
Metal pieces from `0240` (contiguous pool, submit-by-buffer, plug-in
properties, `whyredgpuclk`).

The canonical source is
[N1709/ios-whyred](https://github.com/N1709/ios-whyred), `drivers/gpu/`.
Edit there and copy here, not the other way round; `tools/extract_drivers.py`
in that repository regenerates its mirrors from the patch series.

They are kept here so the service interface and the ladder can be read next
to the userland layer without cloning the whole port. Nothing in this
repository builds them.
