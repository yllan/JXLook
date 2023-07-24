//
//  ViewController.swift
//  JXLook
//
//  Created by Yung-Luen Lan on 2021/1/18.
//

import Cocoa
import os

class ViewController: NSViewController {
    
    static let minSize = CGSize(width: 200, height: 200)
    
    @IBOutlet weak var imageView: MetalImageView!
    @IBOutlet weak var clipView: CenterClipView!
    @IBOutlet weak var scrollView: NSScrollView!
    
    var zoomToFit: Bool = true {
        didSet {
            clipView.centersDocumentView = !zoomToFit
        }
    }
    
    private var addedSettingsObservers = false

    deinit {
        NotificationCenter.default.removeObserver(self,
            name: NSWindow.didChangeOcclusionStateNotification, object: nil)
        removeObserverForScreenChanges()
        guard addedSettingsObservers else { return }
        Settings.shared.removeObserver(self, forKey: .extendedDynamicRange)
        Settings.shared.removeObserver(self, forKey: .highDynamicRange)
        Settings.shared.removeObserver(self, forKey: .toneMapping)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.allowsMagnification = true
        imageView.highDynamicRange = Settings.shared.highDynamicRange
        imageView.extendedDynamicRange = Settings.shared.extendedDynamicRange
        imageView.toneMapping = Settings.shared.toneMapping
        Settings.shared.addObserver(self, forKey: .extendedDynamicRange, options: .new, context: nil)
        Settings.shared.addObserver(self, forKey: .highDynamicRange, options: .new, context: nil)
        Settings.shared.addObserver(self, forKey: .toneMapping, options: .new, context: nil)
        addedSettingsObservers = true
        NotificationCenter.default.addObserver(self, selector: #selector(occlusionStateChanged),
            name: NSWindow.didChangeOcclusionStateNotification, object: nil)
    }

    override func viewWillAppear() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.willMagnify), name: NSScrollView.willStartLiveMagnifyNotification, object: self.scrollView)
    }
    
    override func viewDidDisappear() {
        NotificationCenter.default.removeObserver(self,
            name: NSScrollView.willStartLiveMagnifyNotification, object: self.scrollView)
    }
    
    override var representedObject: Any? {
        didSet {
            if let doc = representedObject as? Document, let img = doc.image {
                let window = self.view.window!
                imageView.screen = window.screen
                self.imageView.image = img
                addOrRemoveScreenObserver()
                let windowTitle = window.frame.height - scrollView.frame.height
                let maxWindowFrame = window.constrainFrameRect(CGRect(origin: CGPoint.zero, size: CGSize(width: img.size.width, height: img.size.height + windowTitle)), to: window.screen)
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
                    window.setContentSize(CGSize(width: newSize.width - 2, height: newSize.height - 2))
                    imageView.frame = CGRect(origin: CGPoint.zero, size: newSize)
                } else
                {
                    self.zoomToFit = true
                    window.setContentSize(CGSize(width: maxContentSize.width, height: maxContentSize.height))
                    imageView.frame = CGRect(origin: CGPoint.zero, size: maxContentSize)
               }
            }
        }
    }
    
    override func viewDidLayout() {
        if zoomToFit {
            scrollView.magnification = 1.0
            imageView.frame.size = scrollView.frame.size
        }
    }
    
    @objc func willMagnify(_ notification: NSNotification) {
        self.zoomToFit = false
    }
    
    @IBAction func zoomImageToActualSize(_ sender: Any!) {
        if let doc = self.representedObject as? Document, let img = doc.image {
            zoomToFit = false
            imageView.frame.size = img.size
            scrollView.magnification = 1.0
            // TODO: adjust the window size
        }
    }
    
    @IBAction func zoomImageToFit(_ sender: Any!) {
        zoomToFit = true
        self.viewDidLayout()
    }
    
    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(self.zoomImageToFit) {
            menuItem.state = zoomToFit ? .on : .off
            return !zoomToFit
        } else if menuItem.action == #selector(self.zoomImageToActualSize) {
            print(self.scrollView.magnification)
            if let doc = self.representedObject as? Document, let img = doc.image {
                let isActualSize = self.scrollView.magnification == 1.0 && self.imageView.frame.size == img.size
                menuItem.state = isActualSize ? .on : .off
                return !isActualSize
            }
            return false;
        }
        return true
    }

    // MARK: - Observers

    /// Observer for changes to application settings stored in [UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults).
    /// - Parameters:
    ///   - keyPath; The key path, relative to `object`, to the value that has changed.
    ///   - object: The source object of the key path `keyPath`.
    ///   - change: A dictionary that describes the changes that have been made to the value of the property at the key path
    ///             `keyPath` relative to object. Entries are described in `Change Dictionary Keys`.
    ///   - context: The value that was provided when the observer was registered to receive key-value observation notifications.
    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else {
            os_log("Observed key path is missing", log: .settings, type: .error)
            return
        }
        guard let key = Settings.Key(rawValue: keyPath) else {
            os_log("Observed key path is unrecognized: %{public}@", log: .settings, type: .error,
                   keyPath)
            return
        }
        guard let valueAsBool = change?[.newKey] as? Bool else {
            os_log("Cannot get new value for key %{public}@", log: .settings, type: .error, keyPath)
            return
        }
        let suffix = "has been " + (valueAsBool ? "enabled" : "disabled")
        switch key {
        case .extendedDynamicRange:
            os_log("Extended dynamic range %{public}@", log: .settings, type: .info, suffix)
            // Changes to this setting can affect the need to observe screen changes.
            addOrRemoveScreenObserver()
            imageView.extendedDynamicRange = valueAsBool
        case .highDynamicRange:
            os_log("High dynamic range %{public}@", log: .settings, type: .info, suffix)
            // Changes to this setting can affect the need to observe screen changes.
            addOrRemoveScreenObserver()
            imageView.highDynamicRange = valueAsBool
        case .toneMapping:
            os_log("Tone mapping %{public}@", log: .settings, type: .info, suffix)
            imageView.toneMapping = valueAsBool
        }
    }

    /// Observer for [didChangeOcclusionStateNotification](https://developer.apple.com/documentation/appkit/nswindow/1419549-didchangeocclusionstatenotificat)
    ///
    /// Changes in window visibility can affect the need to observe screen changes.
    /// - Parameter notification: `NSWindow` object whose occlusion state changed.
    @objc func occlusionStateChanged(notification: NSNotification) {
        addOrRemoveScreenObserver()
    }

    /// Observer for [didChangeScreenNotification](https://developer.apple.com/documentation/appkit/nswindow/1419552-didchangescreennotification)
    /// - Parameter notification: `NSWindow` object that has changed screens.
    @objc func screenChanged(notification: NSNotification) {
        guard let screen = view.window?.screen else { return }
        imageView.screen = screen
    }

    // MARK: - Private Functions

    /// Add or remove the screen changes observer based on need.
    ///
    /// This method adds or removes an observer for screen changes based on the current need to monitor changes to the screen.
    /// When extended dynamic range is active screen change notifications will be posted at a significant rate in order to report
    /// changes in display headroom which can dynamically change due to ambient conditions. Adherence to energy efficiency best
    /// practices requires removing observers if they are not needed to avoid needless processing.
    private func addOrRemoveScreenObserver() {
        guard mustObserveScreenChanges() else {
            removeObserverForScreenChanges()
            return
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged),
            name: NSWindow.didChangeScreenNotification, object: nil)
        imageView.screen = view.window?.screen
    }

    /// Determine if an observer for screen changes is needed.
    ///
    /// The [NSScreen](https://developer.apple.com/documentation/appkit/nsscreen) properties of interest are:
    ///- [maximumPotentialExtendedDynamicRange](https://developer.apple.com/documentation/appkit/nsscreen/3180381-maximumpotentialextendeddynamicr)
    /// The value of this property indicates if the screen supports extended dynamic range.
    /// - [maximumExtendedDynamicRangeColor](https://developer.apple.com/documentation/appkit/nsscreen/1388362-maximumextendeddynamicrangecolor)
    /// The value of this property provides the current display extended dynamic range headroom.
    ///
    /// Therefore changes to the screen the window is on only needs to be actively monitored if:
    /// - The user has not disabled support for high dynamic range images
    /// - The user has not disabled support for activating enhanced dynamic range
    /// - The window is visible
    /// - A high dynamic range image is being displayed
    /// - Returns: `true` if screen changes must be observed, `false` otherwise.
    private func mustObserveScreenChanges() -> Bool {
        guard Settings.shared.highDynamicRange, Settings.shared.extendedDynamicRange,
              let window = view.window, window.occlusionState.contains(.visible),
              let image = imageView.image, image.isHighDynamicRange else { return false }
        return true
    }

    private func removeObserverForScreenChanges() {
        NotificationCenter.default.removeObserver(self,
            name: NSWindow.didChangeScreenNotification, object: nil)
    }
}
