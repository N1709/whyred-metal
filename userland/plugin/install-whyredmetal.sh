#!/bin/sh
# Install WhyredMetal.bundle into an iOS root.
#
#   sudo install-whyredmetal.sh MOUNTED_ROOT [BUNDLE]
#
# MOUNTED_ROOT is the HFS+ iOS root mounted read-write (the image built by
# ios-whyred's tools/mkiosroot.sh and sweet-root-tweaks.py). BUNDLE defaults
# to out/WhyredMetal.bundle next to this script.
#
# This only copies files into the root; it does not touch a partition. The
# root image must then be installed the way the port installs any root
# (ios-whyred docs/build-and-boot.md), with the user's permission.
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=${1:?usage: install-whyredmetal.sh MOUNTED_ROOT [BUNDLE]}
bundle=${2:-$here/out/WhyredMetal.bundle}
dest=$root/System/Library/Extensions

[ -d "$root/System/Library" ] || { echo "not an iOS root: $root" >&2; exit 1; }
[ -d "$bundle" ] || { echo "no bundle: $bundle" >&2; exit 1; }
[ -f "$bundle/Info.plist" ] || { echo "no Info.plist in $bundle" >&2; exit 1; }
[ -f "$bundle/WhyredMetal" ] || { echo "no WhyredMetal binary in $bundle" >&2; exit 1; }

# The plug-in is loaded by the arm64 iOS userland; refuse a host build.
python3 - "$bundle/WhyredMetal" <<'EOF'
import struct, sys
with open(sys.argv[1], 'rb') as f:
    h = f.read(8)
magic, cputype = struct.unpack('<II', h)
if magic != 0xfeedfacf or cputype != 0x0100000c:
    sys.exit('WhyredMetal is not a thin arm64 Mach-O')
EOF

mkdir -p "$dest"
rm -rf "$dest/WhyredMetal.bundle"
cp -a "$bundle" "$dest/WhyredMetal.bundle"
chown -R 0:0 "$dest/WhyredMetal.bundle"
chmod 755 "$dest/WhyredMetal.bundle" "$dest/WhyredMetal.bundle/WhyredMetal"
chmod 644 "$dest/WhyredMetal.bundle/Info.plist"

echo "installed $dest/WhyredMetal.bundle"
ls -l "$dest/WhyredMetal.bundle"
