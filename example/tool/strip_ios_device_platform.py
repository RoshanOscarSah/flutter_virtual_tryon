#!/usr/bin/env python3
"""Strip LC_BUILD_VERSION/LC_VERSION_MIN_IPHONEOS from arm64 objects in
vendored MLKit static frameworks under ios/Pods.

Why: Google's ML Kit pods (Vision Mirror auto-align) ship arm64 slices whose
objects are stamped "platform iOS" (device-only), so linking them into an
arm64 iOS *Simulator* build fails with "Building for 'iOS-simulator', but
linking in object file built for 'iOS'" — and iOS 26+ simulators on Apple
Silicon are arm64-only (no Rosetta/x86_64 fallback). An object with NO
platform load command is accepted by ld for both device and simulator;
MLKitFaceDetection already ships that way and links everywhere. This script
rewrites the remaining MLKit archives to match, in place: it compacts the
load-command list within its existing region and zero-pads the tail, so file
sizes and every absolute offset (fat headers, ar members, LC_SYMTAB) stay
valid. Idempotent — a second run finds nothing to strip.

Invoked from ios/Podfile post_install. Run manually:
    python3 tool/strip_ios_device_platform.py [ios/Pods]
"""

import struct
import sys
from pathlib import Path

MH_MAGIC_64 = 0xFEEDFACF
FAT_MAGIC_BE = 0xCAFEBABE
CPU_ARM64 = 0x0100000C
MH_OBJECT = 0x1
LC_VERSION_MIN_IPHONEOS = 0x25
LC_BUILD_VERSION = 0x32
PLATFORM_IOS = 2
AR_MAGIC = b"!<arch>\n"


def strip_macho_object(buf: bytearray, off: int) -> int:
    """Strip device-platform load commands from one 64-bit MH_OBJECT at
    buf[off:]. Returns number of commands removed."""
    magic, _cpu, _sub, filetype, ncmds, sizeofcmds, _flags, _res = struct.unpack_from(
        "<IiiIIIII", buf, off
    )
    if magic != MH_MAGIC_64 or filetype != MH_OBJECT:
        return 0
    lc_start = off + 32
    # Collect (start, size, keep) for each load command.
    cmds = []
    p = lc_start
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", buf, p)
        keep = True
        if cmd == LC_VERSION_MIN_IPHONEOS:
            keep = False
        elif cmd == LC_BUILD_VERSION:
            (platform,) = struct.unpack_from("<I", buf, p + 8)
            if platform == PLATFORM_IOS:
                keep = False
        cmds.append((p, cmdsize, keep))
        p += cmdsize
    removed = [c for c in cmds if not c[2]]
    if not removed:
        return 0
    kept_bytes = b"".join(bytes(buf[s : s + sz]) for s, sz, keep in cmds if keep)
    buf[lc_start : lc_start + len(kept_bytes)] = kept_bytes
    # Zero the freed tail of the original load-command region.
    buf[lc_start + len(kept_bytes) : lc_start + sizeofcmds] = bytes(
        sizeofcmds - len(kept_bytes)
    )
    struct.pack_into(
        "<II", buf, off + 16, ncmds - len(removed), len(kept_bytes)
    )
    return len(removed)


def strip_ar_archive(buf: bytearray, off: int, size: int) -> int:
    """Strip every Mach-O member of a BSD ar archive at buf[off:off+size]."""
    removed = 0
    p = off + len(AR_MAGIC)
    end = off + size
    while p + 60 <= end:
        name = bytes(buf[p : p + 16]).decode("ascii", "replace").strip()
        member_size = int(bytes(buf[p + 48 : p + 58]).split()[0])
        data = p + 60
        obj = data
        if name.startswith("#1/"):  # BSD extended name: name precedes data
            obj = data + int(name[3:])
        if obj + 4 <= end and struct.unpack_from("<I", buf, obj)[0] == MH_MAGIC_64:
            removed += strip_macho_object(buf, obj)
        p = data + member_size + (member_size & 1)  # members are 2-byte aligned
    return removed


def strip_slice(buf: bytearray, off: int, size: int) -> int:
    if bytes(buf[off : off + len(AR_MAGIC)]) == AR_MAGIC:
        return strip_ar_archive(buf, off, size)
    if struct.unpack_from("<I", buf, off)[0] == MH_MAGIC_64:
        return strip_macho_object(buf, off)
    return 0


def process_binary(path: Path) -> int:
    buf = bytearray(path.read_bytes())
    if len(buf) < 8:
        return 0
    removed = 0
    (magic_be,) = struct.unpack_from(">I", buf, 0)
    if magic_be == FAT_MAGIC_BE:
        (nfat,) = struct.unpack_from(">I", buf, 4)
        for i in range(nfat):
            cpu, _sub, s_off, s_size, _align = struct.unpack_from(
                ">iiIII", buf, 8 + i * 20
            )
            if cpu == CPU_ARM64:
                removed += strip_slice(buf, s_off, s_size)
    else:
        removed += strip_slice(buf, 0, len(buf))
    if removed:
        path.write_bytes(bytes(buf))
    return removed


def main() -> None:
    pods = Path(sys.argv[1] if len(sys.argv) > 1 else "ios/Pods")
    # Only Google's vendored ML Kit binaries need this; source-built pods
    # compile per-SDK and never carry a wrong-platform stamp.
    targets = [
        b
        for pod in ("MLImage", "MLKitCommon", "MLKitVision", "MLKitFaceDetection")
        for b in pods.glob(f"{pod}/**/*.framework/{pod}")
    ]
    total = 0
    for binary in targets:
        n = process_binary(binary)
        total += n
        if n:
            print(f"  stripped device-platform stamp from {n} object(s) in {binary.name}")
    print(f"strip_ios_device_platform: {total} object(s) patched")


if __name__ == "__main__":
    main()
