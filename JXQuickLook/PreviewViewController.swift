//
//  PreviewViewController.swift
//  JXQuickLook
//
//  Created by Yung-Luen Lan on 2021/1/22.
//

import Cocoa
import Quartz

class PreviewViewController: NSViewController, QLPreviewingController {
    
    @IBOutlet weak var imageView: NSImageView!
    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }

    override func loadView() {
        super.loadView()
        // Do any additional setup after loading the view.
    }

    /*
     * Implement this method and set QLSupportsSearchableItems to YES in the Info.plist of the extension if you support CoreSpotlight.
    func preparePreviewOfSearchableItem(identifier: String, queryString: String?, completionHandler handler: @escaping (Error?) -> Void) {
        // Perform any setup necessary in order to prepare the view.
        
        // Call the completion handler so Quick Look knows that the preview is fully loaded.
        // Quick Look will display a loading spinner while the completion handler is not called.
        handler(nil)
    }
    */
    @available(macOSApplicationExtension 12.0, *)
    func providePreview(for request: QLFilePreviewRequest,
                        completionHandler handler: @escaping (QLPreviewReply?, Error?) -> Void) {
        if let img = try? JXL.parse(data: Data(contentsOf: request.fileURL)) {
            let reply = QLPreviewReply(dataOfContentType: .image, contentSize: img.size) { preview in
                return img.tiffRepresentation ?? "Unreachable!".data(using: .utf8)!;
            }
            handler(reply, nil);
        }
        handler(nil, JXLError.cannotDecode);
    }
    
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        
        // Add the supported content types to the QLSupportedContentTypes array in the Info.plist of the extension.
        // Perform any setup necessary in order to prepare the view.
        if let img = try? JXL.parse(data: Data(contentsOf: url)) {
            imageView.image = img
            if let window = self.view.window {
                let maxWindowFrame = window.constrainFrameRect(CGRect(origin: CGPoint.zero, size: CGSize(width: img.size.width, height: img.size.height)), to: window.screen)
                Swift.print(maxWindowFrame)
                if img.size.width > maxWindowFrame.width || img.size.height > maxWindowFrame.height {
                    let ratio = min(maxWindowFrame.width / img.size.width, maxWindowFrame.height / img.size.height)
                    let newSize = CGSize(width: max(300, img.size.width * ratio), height: max(300, img.size.height * ratio))
                    self.preferredContentSize = newSize
                } else {
                    self.preferredContentSize = img.size
                }
                
            }
        } else {
            handler(JXLError.cannotDecode)
        }
        handler(nil)
    }
}
