//
//  CIImageExtension.swift
//  JXLook
//
//  Created by low-batt on 7/5/23.
//

import Cocoa

extension CIImage {

    /// A textual representation of this instance.
    ///
    /// Customize the string conversion for a `CIImage` object to contain the values of the properties that are important to `JXLook`.
    public override var description: String {
        var result = "CIImage("
        if let name = colorSpace?.name {
            result += "colorSpace: \(name), "
        }
        let x = Int(extent.origin.x)
        let y = Int(extent.origin.y)
        let width = Int(extent.width)
        let height = Int(extent.height)
        result += "extent [\(x) \(y) \(width) \(height)])"
        return result
    }
}
