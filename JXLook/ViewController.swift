//
//  ViewController.swift
//  JXLook
//
//  Created by Yung-Luen Lan on 2021/1/18.
//

import Cocoa

class ViewController: NSViewController {
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var scrollView: NSScrollView!
    
    var zoomToFit: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.allowsMagnification = true
    }

    override var representedObject: Any? {
        didSet {
            if let doc = representedObject as? Document, let img = doc.image {
                let window = self.view.window!
                let windowTitle = window.frame.height - scrollView.frame.height
                let maxWindowFrame = window.constrainFrameRect(CGRect(origin: CGPoint.zero, size: img.size), to: window.screen)
                let maxContentSize = CGSize(width: maxWindowFrame.width, height: maxWindowFrame.height - windowTitle)
                
                self.imageView.image = img
                
                if (maxContentSize.width < img.size.width || maxContentSize.height < img.size.height) { // needs to resize
                    let ratio = min((maxContentSize.width) / img.size.width , (maxContentSize.height) / img.size.height)
                    let newSize = CGSize(width: max(64, img.size.width * ratio), height: max(64, img.size.height * ratio))
                    window.setContentSize(newSize)
                    imageView.frame = CGRect(origin: CGPoint.zero, size: newSize)
                } else {
                    window.setContentSize(maxContentSize)
                    imageView.frame = CGRect(origin: CGPoint.zero, size: maxContentSize)
                }
            }
        }
    }
    
    override func viewDidLayout() {
        if zoomToFit {
            imageView.frame.size = scrollView.frame.size
        }
    }
}

