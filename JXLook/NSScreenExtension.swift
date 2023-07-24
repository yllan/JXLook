//
//  NSScreenExtension.swift
//  JXLook
//
//  Created by low-batt on 6/26/23.
//

import Cocoa

extension NSScreen {

    /// A textual representation of this instance.
    ///
    /// Customize the string conversion for a `NSScreen` object to contain the values of the properties that are important to `JXLook`.
    public override var description: String {
        var result = "NSScreen(localizedName: \(localizedName), "
        if let name = colorSpace?.localizedName {
            result += "colorSpace: \(name), "
        }
        result += """
maximumExtendedDynamicRangeColorComponentValue: \
\(maximumExtendedDynamicRangeColorComponentValue), \
maximumPotentialExtendedDynamicRangeColorComponentValue: \
\(maximumPotentialExtendedDynamicRangeColorComponentValue))
"""
        return result
    }
}
