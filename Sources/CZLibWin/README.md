# CZLibWin — vendored zlib for Windows

Windows runners have no system `zlib.h` and no `pkg-config`, and clang-cl
rejects the `#import`s in `Sources/CZLib/shim.h`, so the upstream
`systemLibrary(name: "CZlib", pkgConfig: "zlib")` target cannot work there.

`Package.swift` therefore builds this directory as a regular C target named
**CZlib** when `os(Windows)` (see the `#elseif os(Windows)` branch). The
module name is unchanged, so `Sources/ZIPFoundation/Data+Compression.swift`
(`import CZlib`) compiles unmodified and deflate/inflate keep working.

## Contents

- `include/zlib.h`, `include/zconf.h` — public headers (the module's umbrella).
- `include/module.modulemap` — declares `module CZlib`.
- `zlib/*.c`, `zlib/*.h` — zlib 1.3.1 sources, unmodified, taken from
  https://github.com/madler/zlib `v1.3.1` (only the top-level core files;
  `contrib/` and `examples/` are not included).
- `zlib/README.zlib-upstream` — upstream README with the zlib license.

zlib is © Jean-loup Gailly and Mark Adler, distributed under the
zlib license (see `README.zlib-upstream`).
