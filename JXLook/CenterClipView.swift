//
//  CenterClipView.swift
//  JXLook
//
//  Created by Yung-Luen Lan on 2021/1/20.
//

import Cocoa

class CenterClipView: NSClipView {
    var centersDocumentView: Bool = true
    
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        
        if centersDocumentView,
           let documentViewFrameRect = self.documentView?.frame
        {
            if proposedBounds.size.width >= documentViewFrameRect.size.width {
                rect.origin.x = floor((proposedBounds.size.width - documentViewFrameRect.size.width) / -2.0)
            }
            if proposedBounds.size.height >= documentViewFrameRect.size.height {
                rect.origin.y += floor((proposedBounds.size.height - documentViewFrameRect.size.height) / -2.0)
            }
        }
        return rect
    }
    
}
