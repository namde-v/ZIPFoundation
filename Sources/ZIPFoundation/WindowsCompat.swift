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
import WinSDK

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

/// Windows has no `lstat(2)` and the UCRT `_stat` is not visible to Swift.
/// Implement it via GetFileAttributesExW (which, like lstat, does not
/// follow the final path component's reparse point for attribute purposes).
func lstat(_ path: UnsafePointer<CChar>, _ buf: UnsafeMutablePointer<stat>) -> Int32 {
    let widePath: [UInt16] = Array(String(cString: path).utf16) + [0]
    var attrData = WIN32_FILE_ATTRIBUTE_DATA()
    let ok: Bool = widePath.withUnsafeBufferPointer { pathPtr in
        withUnsafeMutableBytes(of: &attrData) { attrBytes in
            GetFileAttributesExW(pathPtr.baseAddress, GetFileExInfoStandard, attrBytes.baseAddress)
        }
    }
    guard ok else { return -1 }

    let attrs = attrData.dwFileAttributes
    var mode: mode_t = S_IFREG
    if attrs & DWORD(FILE_ATTRIBUTE_DIRECTORY) != 0 {
        mode = S_IFDIR
    }
    // Approximate POSIX permissions from the readonly attribute.
    mode |= 0o444
    if attrs & DWORD(FILE_ATTRIBUTE_READONLY) == 0 {
        mode |= 0o222
    }

    var st = stat()
    st.st_mode = mode
    // Note: st_size is 32-bit off_t on Windows; clamp huge files.
    let fileSize = Int64(attrData.nFileSizeHigh) << 32 | Int64(attrData.nFileSizeLow)
    st.st_size = off_t(clamping: fileSize)
    st.st_atime = fileTimeToUnixTime(attrData.ftLastAccessTime)
    st.st_mtime = fileTimeToUnixTime(attrData.ftLastWriteTime)
    st.st_ctime = fileTimeToUnixTime(attrData.ftCreationTime)
    buf.pointee = st
    return 0
}

/// FILETIME (100ns ticks since 1601-01-01) -> Unix time_t (seconds since 1970-01-01).
private func fileTimeToUnixTime(_ ft: FILETIME) -> time_t {
    let ticks = Int64(ft.dwHighDateTime) << 32 | Int64(ft.dwLowDateTime)
    return time_t(ticks / 10_000_000 - 11644473600)
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
