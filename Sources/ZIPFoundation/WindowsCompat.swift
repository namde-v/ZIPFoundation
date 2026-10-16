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

#endif
