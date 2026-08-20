# Bundled glibc runtime (2.44)

This directory ships a full glibc runtime for **aarch64**, extracted from the
Debian `libc6` package (glibc 2.44). It lets the device run software built
against a newer glibc than the firmware's own `/lib` provides.

The device's `ld-linux-aarch64.so.1` cannot be replaced from the SD card, so
the loader here is invoked directly — the same trick AppImages and portable
toolchains use. To run any glibc-linked binary with this runtime:

```sh
jm-glibc /path/to/binary [args...]
```

`jm-glibc` (in `System/bin`) execs `ld-linux-aarch64.so.1` with
`--library-path` pointing here and `--inhibit-cache`, so these libraries always
win over the firmware's. Name resolution works via the bundled `libnss_*`
modules (DNS + files).

## Contents

| File | Purpose |
|---|---|
| `ld-linux-aarch64.so.1` | glibc 2.44 dynamic linker |
| `libc.so.6`, `libm.so.6`, `libmvec.so.1` | core C + math |
| `libpthread.so.0`, `libdl.so.2`, `librt.so.1`, `libutil.so.1` | threading / dlopen / realtime |
| `libresolv.so.2`, `libanl.so.1`, `libnsl.so.1` | DNS + legacy resolver |
| `libnss_dns.so.2`, `libnss_files.so.2` | hostname resolution |
| `libthread_db.so.1` | debugger thread support |

## Updating

Fetch the newest `libc6_*_arm64.deb` from the Debian pool and copy the files:

```sh
curl -O https://deb.debian.org/debian/pool/main/g/glibc/libc6_<ver>_arm64.deb
ar x libc6_<ver>_arm64.deb && tar xf data.tar.*
cp usr/lib/aarch64-linux-gnu/{ld-linux-aarch64.so.1,libc.so.6,libm.so.6,\
  libmvec.so.1,libpthread.so.0,libdl.so.2,librt.so.1,libutil.so.1,\
  libresolv.so.2,libanl.so.1,libnsl.so.1,libthread_db.so.1,\
  libnss_dns.so.2,libnss_files.so.2} System/lib/glibc/
```

Source: `https://deb.debian.org/debian/pool/main/g/glibc/` (GLIBC license,
LGPL-2.1-or-later, see `/usr/share/common-licenses/LGPL-2.1` in the package).
