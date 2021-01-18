//
//  ViewController.swift
//  JXLook
//
//  Created by Yung-Luen Lan on 2021/1/18.
//

import Cocoa

class ViewController: NSViewController {
    @IBOutlet weak var imageView: NSImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
            if let doc = representedObject as? Document, let img = doc.image {
                self.imageView.image = img
                self.imageView.frame = CGRect(x: 0, y: 0, width: img.size.width, height: img.size.height)
            }
        }
    }


}

