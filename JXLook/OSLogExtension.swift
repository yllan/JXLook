//
//  OSLogExtension.swift
//  JXLook
//
//  Created by low-batt on 6/26/23.
//

import Foundation
import os

/// Configure `OSLog` for use by JXLook.
///
/// - Note: [Logger](https://developer.apple.com/documentation/os/logger) is not used  as it is not available under
///         macOS Catalina.
extension OSLog {

    // MARK: - Log Categories

    /// Category for messages concerning decoding the JPEG XL file.
    static let decode = construct("decode")

    /// Category for messages concerning rendering the image.
    static let render = construct("render")

    /// Category for messages concering application settings.
    static let settings = construct("settings")

    /// Category for high level messages concerning viewing the JPEG XL image.
    static let view = construct("view")

    // MARK: - Private

    private static let subsystem = Bundle.main.bundleIdentifier!

    private static func construct(_ category: String) -> OSLog {
        OSLog(subsystem: subsystem, category: category)
    }
}
