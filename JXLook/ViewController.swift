//
//  ViewController.swift
//  JXLook
//
//  Created by Yung-Luen Lan on 2021/1/18.
//

import Cocoa

class ViewController: NSViewController {
    
    static let minSize = CGSize(width: 200, height: 200)
    
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var clipView: CenterClipView!
    @IBOutlet weak var scrollView: NSScrollView!
    
    var zoomToFit: Bool = true {
        didSet {
            clipView.centersDocumentView = !zoomToFit
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.allowsMagnification = true
    }

    override var representedObject: Any? {
        didSet {
            if let doc = representedObject as? Document, let img = doc.image {
                self.imageView.image = img

                let window = self.view.window!
                let windowTitle = window.frame.height - scrollView.frame.height
                let maxWindowFrame = window.constrainFrameRect(CGRect(origin: CGPoint.zero, size: img.size), to: window.screen)
                let maxContentSize = CGSize(width: maxWindowFrame.width, height: maxWindowFrame.height - windowTitle)

                window.minSize = ViewController.minSize
                window.minSize.height += windowTitle
                // less than min size
                if img.size.width <= ViewController.minSize.width && img.size.height <= ViewController.minSize.height
                {
                    self.zoomToFit = false
                    window.setContentSize(ViewController.minSize)
                    imageView.frame = CGRect(origin: .zero, size: img.size)
                } else if img.size.width > maxContentSize.width || img.size.height > maxContentSize.height
                { // at least one side larger than max window dimension, needs to scale down
                    self.zoomToFit = true
                    let ratio = min((maxContentSize.width) / img.size.width , (maxContentSize.height) / img.size.height)
                    let newSize = CGSize(width: max(ViewController.minSize.width, img.size.width * ratio), height: max(ViewController.minSize.height, img.size.height * ratio))
                    window.setContentSize(newSize)
                    imageView.frame = CGRect(origin: CGPoint.zero, size: newSize)
                } else
                {
                    self.zoomToFit = true
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

