#!/bin/bash
# Build WhyredMetal.bundle on the Mac: Xcode, the iPhoneOS SDK, and the iOS Mesa archives that
# tools/mesa-ios/build-mac.sh made in $B (default /tmp/mi).
#   out/WhyredMetal.bundle   the plug-in, to be copied to /System/Library/Extensions/ on the phone
#   out/whyredmetal_test     the program that asks for the plug-in and checks buffers/blits
# The plug-in carries the shader compiler (hakios-metal's AIR front end and Mesa's ir3, in hk/ and the archives).
set -euo pipefail
cd "$(dirname "$0")"
. ../../tools/mesa-ios/flags.sh
mkdir -p out/WhyredMetal.bundle
CC="xcrun -sdk iphoneos clang -arch arm64 -target arm64-apple-ios16.0 -O1 -Wall"

(cd hk && bash ./build-ios.sh)
$CC -std=gnu11 -c why5.c -o out/why5.o
$CC -std=gnu11 -c why5r.c -o out/why5r.o
$CXX $CXXF -Ihk/include -c whycc.cpp -o out/whycc.o
$CC -fno-objc-arc -c WhyredMetal.m -o out/WhyredMetal.o

LIBS="$D/src/compiler/air/libair.a $(for a in $(cat $B/archives.txt); do [ $a = src/compiler/air/libair.a ] || echo -n "$D/$a "; done)"
$CXX -arch arm64 -isysroot "$SDK" -target arm64-apple-ios16.0 -bundle -o out/WhyredMetal.bundle/WhyredMetal \
	out/WhyredMetal.o out/why5.o out/why5r.o out/whycc.o hk/out/*.o $LIBS \
	-framework Foundation -framework IOKit -framework IOSurface -lc++ -lz -lm
cp WhyredMetal-Info.plist out/WhyredMetal.bundle/Info.plist
# the plug-in fails to load (Metal returns no device) once the unstripped binary grows past ~8.27 MB: strip it
strip -x out/WhyredMetal.bundle/WhyredMetal 2>/dev/null
codesign -s - -f out/WhyredMetal.bundle

$CC -fobjc-arc -framework Foundation -framework Metal -framework QuartzCore -framework IOSurface \
	-framework IOKit -framework CoreFoundation -o out/whyredmetal_test whyredmetal_test.m
codesign -s - -f out/whyredmetal_test
echo built
