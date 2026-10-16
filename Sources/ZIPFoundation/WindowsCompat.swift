//
//  WindowsCompat.swift
//  ZIPFoundation (namde-v fork)
//
//  Windows-only shims for the POSIX file functions used throughout
//  ZIPFoundation that MSVC's CRT doesn't provide under their POSIX names.
//  Empty on every other platform.
//

import Foundation

#if os(Windows)

// MSVC names the 64-bit file-positioning functions _fseeki64/_ftelli64.
// Re-expose them under the POSIX names used by the rest of the module so
// the call sites need no changes.
func fseeko(_ stream: UnsafeMutablePointer<FILE>, _ offset: off_t, _ whence: Int32) -> Int32 {
    return _fseeki64(stream, Int64(offset), whence)
}

func ftello(_ stream: UnsafeMutablePointer<FILE>) -> Int64 {
    return _ftelli64(stream)
}

// MSVC has no ftruncate(2); _chsize_s is the CRT equivalent.
func ftruncate(_ fd: Int32, _ length: off_t) -> Int32 {
    return _chsize_s(fd, Int64(length))
}

// MARK: - POSIX stat/file-time compatibility
//
// MSVC's <sys/stat.h> provides struct _stat (imported as `stat` via the
// `stat` -> `_stat` macro) but none of the POSIX `lstat`/`lchmod`/`lutimes`
// functions, the `mode_t`/`suseconds_t` types, the `S_IF*` constants (only
// `_S_*` variants, and no `S_IFLNK`), or `struct timeval`.

/// MSVC's `st_mode` is `unsigned short`; there is no `mode_t` typedef.
typealias mode_t = UInt16

/// POSIX file-type constants (standard values; MSVC has no `S_IFLNK`).
let S_IFMT: mode_t = 0o170000
let S_IFDIR: mode_t = 0o040000
let S_IFREG: mode_t = 0o100000
let S_IFLNK: mode_t = 0o120000

/// `suseconds_t` is not defined by the UCRT.
typealias suseconds_t = Int

/// The UCRT has no `struct timeval`; provide the POSIX shape used by `lutimes`
/// and `Date+ZIP.swift`'s `timeval` extension.
struct timeval {
    var tv_sec: time_t
    var tv_usec: suseconds_t
    init(tv_sec: time_t, tv_usec: suseconds_t) {
        self.tv_sec = tv_sec
        self.tv_usec = tv_usec
    }
}

/// Windows has no `lstat(2)`. `_stat` follows symlinks, which is the closest
/// available semantic for ZIP's file-attribute queries.
func lstat(_ path: UnsafePointer<CChar>, _ buf: UnsafeMutablePointer<stat>) -> Int32 {
    return _stat(path, buf)
}

/// Windows has no `lchmod(2)`; `_chmod` follows symlinks.
func lchmod(_ path: UnsafePointer<CChar>, _ mode: mode_t) -> Int32 {
    return _chmod(path, Int32(mode))
}

/// Windows has no `lutimes(2)`; `_utime` sets access/modification times
/// (following symlinks).
func lutimes(_ path: UnsafePointer<CChar>, _ times: UnsafePointer<timeval>?) -> Int32 {
    var ubuf = _utimbuf()
    if let times = times {
        ubuf.actime = times[0].tv_sec
        ubuf.modtime = times[1].tv_sec
    } else {
        let now = time(nil)
        ubuf.actime = now
        ubuf.modtime = now
    }
    return _utime(path, &ubuf)
}

#endif
