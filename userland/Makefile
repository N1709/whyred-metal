# Host tests for the A5xx layer (no device). `make test`; `make regen` rewrites a5xx.hpp from refs/ext (Mesa XML).
CXX = clang++
CXXFLAGS ?= -std=c++17 -Wall -Wextra -Iinclude

test: build/cp_test
	build/cp_test

build/cp_test: tests/cp_test.cpp include/whyred-metal/*.hpp
	mkdir -p build
	$(CXX) $(CXXFLAGS) tests/cp_test.cpp -o $@

# The plug-in must name the whyred service, bundle and GPU id, not the lavender ones.
plugin-check:
	@grep -q 'IOServiceMatching("WhyredGPU")' plugin/WhyredMetal.m
	@grep -q 'WhyredMetalDevice' plugin/WhyredMetal-Info.plist
	@grep -q 'WHYRED_GPU_ID=509' plugin/hk/build-ios.sh
	@! grep -q 'LavenderGPU' plugin/WhyredMetal.m
	@echo "plugin-check: WhyredGPU service, WhyredMetalDevice, GPU id 509"

regen:
	cd .. && python3 tools/gen_a5xx.py

.PHONY: test plugin-check regen
