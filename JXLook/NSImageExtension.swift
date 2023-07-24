//
//  NSImageExtension.swift
//  JXLook
//
//  Created by low-batt on 6/30/23.
//

import Cocoa
import os

extension NSImage {

    /// Whether this is a high dynamic range image.
    ///
    /// This is not a general purpose extension, it relies upon the image having been created by `JKL.parse`.
    var isHighDynamicRange: Bool {
        guard !representations.isEmpty,
              let bitmapImageRep = representations[0] as? NSBitmapImageRep else {
            // Internal error. A NSBitmapImageRep should have been attached by JXL.parse.
            os_log("Cannot get bitmapImageRep", log: .render, type: .error)
            return false
        }
        guard let cgColorSpace = bitmapImageRep.colorSpace.cgColorSpace,
              let colorSpaceName = cgColorSpace.name else {
            os_log("Cannot get cgColorSpace name", log: .render, type: .error)
            return false
        }
        if #available(macOS 11.0, *) {
            if colorSpaceName == CGColorSpace.itur_2100_PQ {
                return true
            }
        } else if #available(macOS 10.15.4, *) {
            if colorSpaceName == CGColorSpace.itur_2020_PQ {
                return true
            }
        } else if colorSpaceName == CGColorSpace.itur_2020_PQ_EOTF {
            return true
        }
        if #available(macOS 11.0, *) {
            if colorSpaceName == CGColorSpace.itur_2100_HLG {
                return true
            }
        } else if #available(macOS 10.15.6, *), colorSpaceName == CGColorSpace.itur_2020_HLG {
            return true
        }
        return false
    }

    /// Whether this is a high dynamic range image that uses the hybrid log-gamma format.
    ///
    /// This is not a general purpose extension, it relies upon the image having been created by `JKL.parse`.
    var isInHybridLogGammaFormat: Bool {
        guard !representations.isEmpty,
              let bitmapImageRep = representations[0] as? NSBitmapImageRep else {
            // Internal error. A NSBitmapImageRep should have been attached by JXL.parse.
            os_log("Cannot get bitmapImageRep", log: .render, type: .error)
            return false
        }
        guard let colorSpaceName = bitmapImageRep.colorSpace.cgColorSpace?.name else {
            // Internal error. Should be able to obtain the name of the color space.
            os_log("Cannot get cgColorSpace name", log: .render, type: .error)
            return false
        }
        if #available(macOS 11.0, *) {
            return colorSpaceName == CGColorSpace.itur_2100_HLG
        }
        if #available(macOS 10.15.6, *) {
            return colorSpaceName == CGColorSpace.itur_2020_HLG
        }
        return false
    }
}
