//
//  MetalImageView.swift
//  JXLook
//
//  Created by low-batt on 6/1/23.
//

import Cocoa
import MetalKit
import os

/// View for displaying images using [Metal](https://developer.apple.com/metal/).
///
/// At the time of this coding the latest version of macOS is Ventura. Under Ventura
/// [NSImageView](https://developer.apple.com/documentation/appkit/nsimageview) is unable to properly
/// display [High Dynamic Range ](https://developer.apple.com/documentation/metal/hdr_content/displaying_hdr_content_in_a_metal_layer#3335504)
/// images. `NSImageView` will not enable [Extended Dynamic Range](https://developer.apple.com/documentation/metal/hdr_content/displaying_hdr_content_in_a_metal_layer#3335505).
/// Highlights in HDR images beyond standard dynamic range will be clipped.
///
/// This view extends [MTKView](https://developer.apple.com/documentation/metalkit/mtkview) to be able to
/// display a HDR image with EDR enabled, tone mapping the image to the current display headroom.
///
/// This view contains a `NSImageView` subview. Whenever possible the `NSImageView` subview will be used to display the
/// image. The decision to use `Metal` or `NSImageView` is made by the `settingChanged` method.
///
/// As per MVC conventions the controller is responsible for observing notifications of changes and appropriately adjusting the public
/// properties exposed by this view.
class MetalImageView: MTKView {

    @IBOutlet weak var imageView: NSImageView!

    // MARK: - Public Properties

    /// Whether to permit use of extended dynamic range for screens that support it.
    var extendedDynamicRange = true {
        didSet {
            guard extendedDynamicRange != oldValue else { return }
            settingChanged()
        }
    }

    /// The view’s frame rectangle, which defines its position and size in its superview’s coordinate system.
    override var frame: NSRect { didSet { frameChanged() } }

    /// Whether to permit processing of high dynamic range images.
    ///
    /// Setting this to `false` disables special processing of HDR images. The image will be sent directly to the `NSImageView`
    /// for display. This provides a workaround should there be any problems in the code that renders HDR images.
    var highDynamicRange = true {
        didSet {
            guard highDynamicRange != oldValue else { return }
            settingChanged()
        }
    }

    /// The image displayed by this view.
    var image: NSImage? {
        didSet {
            forceMetalDraw = true
            settingChanged()
        }
    }

    /// The screen the window containing this view is on.
    var screen: NSScreen? { didSet { screenChanged() } }

    /// Whether to perform tone mapping on high dynamic range images.
    ///
    /// When extended dynamic range is unavailable this will cause HDR images to be tone mapped to SDR. When EDR is active this
    /// will cause the Metal tone mapper to be used to keep the image within the display's current headroom.
    var toneMapping = true {
        didSet {
            guard toneMapping != oldValue else { return }
            settingChanged()
        }
    }

    // MARK: - Private Properties

    /// An evaluation context for rendering image processing performed by the `draw` method.
    ///
    /// This context is constructed by the `settingChanged` and saved in this property to reduce the amount of work performed
    /// by the `draw` method. In [Processing an Image Using Built-in Filters](https://developer.apple.com/documentation/coreimage/processing_an_image_using_built-in_filters)
    /// Apple indicates that creating a `CIContext` is expensive, therefore it is important to reuse context objects when possible.
    private var ciContext: CIContext?

    /// Representation of the image  for use by the `scaleAndCenterImage` method.
    ///
    /// This image is constructed by the `settingChanged` and saved in this property to reduce the amount of work performed
    /// when the `frame` size is changed.
    private var ciImage: CIImage?

    /// This flag instructs the `draw` method to erase the image displayed by this view.
    ///
    /// This happens when this view is displaying the image and we want the NSImageView subview to display the image.
    private var clearImage = false

    /// Display headroom used to configure the `Metal` layer tone mapper.
    private var configuredHeadroom: CGFloat = 1.0

    /// The screen the window containing this view was on when the current configuration was generated.
    private var configuredScreen: NSScreen?

#if DEBUG
    /// Whether to emit log messages detailing internal state.
    ///
    /// The log messages emitted are  only of interest to developers.
    private static let detailedDebugLogging = false
#endif

    /// Threshold at which a change in display headroom causes tone mapping to be reconfigured.
    private static let headroomChangeThreshold = 0.02

    /// Whether to explicitly draw the view or leave it to AppKit to decide when to display the view.
    ///
    /// This is needed to force an initial drawing of the view so that when a window initially starts minimized to the dock the window
    /// counterpart generated by AppKit and shown as the dock icon contains a miniaturized image.
    private var forceMetalDraw = true

    /// Scaled and centered image ready for use by the `draw` method.
    ///
    /// This image is constructed by the `scaleAndCenterImage` and saved in this property to reduce the amount of work
    /// performed by the `draw` method.
    private var imageToRender: CIImage?

    /// Full initialization is delayed and performed on demand as needed.
    private var notInitialized = true

    /// Filter used by the `scaleAndCenterImage` method to scale the image to fit in the view.
    private var scaleFilter: CIFilter?

    /// Whether this view is showing an image.
    private var showingImage = false

    /// Whether this view is drawing the image (as opposed to the `NSImageView` subview).
    private var useMetalRenderer = false

    // MARK: - Initialization

    required init(coder: NSCoder) {
        super.init(coder: coder)
        // By default a MTKView redraws its contents based on an internal timer. Reconfigure the
        // view to redraw when something invalidates its contents.
        enableSetNeedsDisplay = true
        framebufferOnly = false
        isPaused = true
    }

    // MARK: - Drawing

    /// Draw or erase the image.
    ///
    /// This method will draw the image if the `settingChanged` method determined that
    /// [Metal](https://developer.apple.com/metal/) **must** be used to display the image. Otherwise
    /// preference is given to the [NSImageView](https://developer.apple.com/documentation/appkit/nsimageview)
    /// subview.
    ///
    /// This method is also responsible for erasing the displayed image. This occurs when `Metal` is being used to display the image
    /// and a configuration change causes `settingChanged` to determine `NSImageView` can now be used to display the image.
    ///
    /// - Note: No errors should be reported by this method. If any of the `guard` statements are violated then there is an internal
    ///         error in `MetalImageView` or `AppKit`.
    ///
    /// - Parameter dirtyRect: A rectangle defining the portion of the view that requires redrawing. The current implementation
    ///     ignores this parameter.
    override func draw(_ dirtyRect: NSRect) {
        guard useMetalRenderer || clearImage else {
            // The NSImageView subview is being used to display the image instead of this view.
            return
        }
        guard let device = device else {
            os_log("Cannot get metal device", log: .render, type: .error)
            return
        }
        guard let commandQueue = device.makeCommandQueue() else {
            os_log("Cannot make a command queue", log: .render, type: .error)
            return
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            os_log("Cannot make a command buffer", log: .render, type: .error)
            return
        }

        // This sequence is required to erase the texture to the background color specified in the
        // clearColor property.
        guard let renderPassDescriptor = currentRenderPassDescriptor else {
            os_log("Cannot get render pass descriptor", log: .render, type: .error)
            return
        }
        guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: renderPassDescriptor) else {
            os_log("Cannot make a command encoder", log: .render, type: .error)
            return
        }
        commandEncoder.endEncoding()

        // Draw or erase the image.
        guard let drawable = currentDrawable else {
            os_log("Cannot get current drawable", log: .render, type: .error)
            return
        }
        if clearImage {
            // Switching to displaying the image using the NSImageView subview. The clearColor has
            // been set to a fully transparent color. Drawing this background color once erases the
            // image being displayed by this view allowing the image drawn by the subview to be seen.
            clearImage = false
            showingImage = false
        } else {
            showingImage = true

            // Render the image into the Metal texture.
            guard let ciContext = ciContext else {
                os_log("Cannot get ciContext", log: .render, type: .error)
                return
            }
            guard let colorspace = colorspace else {
                os_log("Cannot get colorspace", log: .render, type: .error)
                return
            }
            guard let imageToRender = imageToRender else {
                os_log("Cannot get imageToRender", log: .render, type: .error)
                return
            }
            let texture = drawable.texture
            let width = CGFloat(texture.width)
            let height = CGFloat(texture.height)
            let textureBounds = CGRect(x: 0, y: 0, width: width, height: height)
            ciContext.render(imageToRender, to: texture, commandBuffer: commandBuffer,
                             bounds: textureBounds, colorSpace: colorspace)
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Private Functions

    /// Configure Metal layer tone mapping for extended dynamic range images.
    ///
    /// This method constructs a [CAEDRMetadata](https://developer.apple.com/documentation/quartzcore/caedrmetadata)
    /// object and stores it in the given Metal layer's
    /// [edrMetadata](https://developer.apple.com/documentation/quartzcore/cametallayer/3182052-edrmetadata)
    /// property. The maximum luminance is set to the current display headroom of the given screen.
    ///
    /// The headroom changes dynamically as discussed in [Extended Dynamic Range](https://developer.apple.com/documentation/metal/hdr_content/displaying_hdr_content_in_a_metal_layer#3335505).
    /// The layer must be updated with a new `CAEDRMetadata` object if the display headroom changes significantly. The headroom
    /// used is preserved in `configuredHeadroom`. This provides the ability to compare the headroom being used for tone
    /// mapping to the current display headroom in order to determine if tone mapping needs to be reconfigured. A separate property
    /// is needed because `CAEDRMetadata` does not provide any way to get the values used to construct it.
    /// - Parameters:
    ///   - layer: The Metal layer on which to configure tone mapping
    ///   - screen: The screen the window containing this view is on
    private func configureMetalToneMapping(_ layer: CAMetalLayer, _ screen: NSScreen) {
        layer.edrMetadata = CAEDRMetadata.hdr10(minLuminance: 0.0,
            maxLuminance: Float(screen.maximumExtendedDynamicRangeColorComponentValue * 100),
            opticalOutputScale: 100)
        configuredHeadroom = screen.maximumExtendedDynamicRangeColorComponentValue
    }

    /// Adjust the view configuration to reflect a change in the view's frame.
    private func frameChanged() {
        /// Any changes to this view's frame must also be made to the `NSImageView` subview's frame.
        imageView.frame = frame

        // If Metal is being used to draw the image then the scaled image used by the draw method
        // must be rescaled to work with the new frame size.
        guard useMetalRenderer else { return }
        scaleAndCenterImage()
    }

#if DEBUG
    /// Emit detailed log messages describing important state.
    ///
    /// This is a debugging tool for developers.
    /// - Note: The property `detailedDebugLogging` must be set to `true` to enable the logging.
    private func logState(function: String = #function, line: Int = #line) {
        guard MetalImageView.detailedDebugLogging else { return }
        os_log("State in %{public}@ at line %d:", log: .render, type: .debug, function, line)
        os_log("clearImage: %{public}@", log: .render, type: .debug, String(clearImage))
        os_log("colorPixelFormat: %{public}@", log: .render, type: .debug,
               String(describing: colorPixelFormat))
        if let colorspace = colorspace?.name {
            os_log("colorspace: %{public}@", log: .render, type: .debug, "\(colorspace)")
        }
        os_log("configuredMaximumExtendedDynamicRange: %f", log: .render, type: .debug, configuredHeadroom)
        if let image = image {
            os_log("image.representations: %{public}@", log: .render, type: .debug,
                   image.representations)
        }
        if let image = imageView.image {
            os_log("imageView.image.representations: %{public}@", log: .render, type: .debug,
                   image.representations)
        }
        if let layer = layer as? CAMetalLayer {
            if let colorspace = layer.colorspace?.name {
                os_log("layer.colorspace: %{public}@", log: .render, type: .debug, "\(colorspace)")
            }
            if let edrMetadata = layer.edrMetadata {
                os_log("layer.edrMetadata: %{public}@", log: .render, type: .debug, "\(edrMetadata)")
            }
            os_log("layer.pixelFormat: %{public}@", log: .render, type: .debug,
                   "\(layer.pixelFormat)")
            os_log("layer.wantsExtendedDynamicRangeContent: %{public}@", log: .render, type: .debug,
                   String(layer.wantsExtendedDynamicRangeContent))
        }
        if let colorspace = screen?.colorSpace?.localizedName {
            os_log("screen.colorSpace: %{public}@", log: .render, type: .debug, "\(colorspace)")
        }
        if let maximum = screen?.maximumExtendedDynamicRangeColorComponentValue {
            os_log("screen.maximumExtendedDynamicRangeColorComponentValue: %f",
                   log: .render, type: .debug, maximum)
        }
        if let potential = screen?.maximumPotentialExtendedDynamicRangeColorComponentValue {
            os_log("screen.maximumPotentialExtendedDynamicRangeColorComponentValue: %f",
                   log: .render, type: .debug, potential)
        }
        os_log("showingImage: %{public}@", log: .render, type: .debug, String(showingImage))
        os_log("useMetalRenderer: %{public}@", log: .render, type: .debug, String(useMetalRenderer))
        if let colorspace = window?.colorSpace?.localizedName {
            os_log("window.colorspace: %{public}@", log: .render, type: .debug, "\(colorspace)")
        }
    }
#endif

    /// Perform delayed one time initialization.
    ///
    /// As SDR images are common, this method initializes on demand objects that are only needed when displaying HDR images.
    private func onDemandInitialization() -> Bool {
        guard notInitialized else { return true }
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        colorPixelFormat = .rgba16Float
        device = preferredDevice ?? MTLCreateSystemDefaultDevice()
        guard let device = device else {
            os_log("Cannot get metal device", log: .render, type: .error)
            return false
        }
        ciContext = CIContext(mtlDevice: device)

        // The Metal device usually corresponds to the GPU associated with the screen that’s
        // displaying the view. Remember the screen that was used to detect when reconfiguration is
        // required due to the window moving to a different screen.
        guard let screen = screen else {
            os_log("Cannot get screen", log: .render, type: .error)
            return false
        }
        configuredScreen = screen
        guard let layer = layer as? CAMetalLayer else {
            os_log("Cannot get metal layer", log: .render, type: .fault)
            return false
        }
        layer.isOpaque = false
        layer.pixelFormat = .rgba16Float
        guard let scaleFilter = CIFilter(name: "CILanczosScaleTransform") else {
            os_log("Cannot get CILanczosScaleTransform filter", log: .render, type: .error)
            return false
        }
        scaleFilter.setValue(1.0, forKey: kCIInputAspectRatioKey)
        self.scaleFilter = scaleFilter
        notInitialized = false
        return true
    }

    /// Scale and center the image for display in this view.
    ///
    /// The image contained in the `ciImage` property is scaled, centered and stored in the `imageToRender` property based on
    /// the current [drawableSize](https://developer.apple.com/documentation/metalkit/mtkview/1535969-drawablesize).
    /// This is done to reduce the amount of work performed by the `draw` method.
    private func scaleAndCenterImage() {

        // Scale the image.
        guard let ciImage = ciImage else {
             os_log("Cannot get ciImage", log: .render, type: .error)
             return
        }
        let width = CGFloat(drawableSize.width)
        let height = CGFloat(drawableSize.height)
        let scaleX = width / CGFloat(ciImage.extent.width)
        let scaleY = height / CGFloat(ciImage.extent.height)
        let factor = min(scaleX, scaleY)
        guard let scaleFilter = scaleFilter else {
            os_log("Cannot get scaleFilter", log: .render, type: .error)
            return
        }
        scaleFilter.setValue(factor, forKey: kCIInputScaleKey)
        let scaledImage = scaleFilter.outputImage!

        // Center the image in the view.
        let originX = max(width - scaledImage.extent.width, 0) / 2
        let originY = max(height - scaledImage.extent.height, 0) / 2
        imageToRender = scaledImage.transformed(by: CGAffineTransform(
            translationX: originX, y: originY))
    }

    /// Adjust the view configuration to reflect a change in the screen the window is on.
    private func screenChanged() {
        guard let screen = screen else { return }

        // No need to process screen changes until on demand initialization has been done.
        guard !notInitialized else { return }

        // Check to see if the window moved to a different screen.
        if screen != configuredScreen {
            os_log("Window moved to screen: %{public}@", log: .render, type: .debug,
                   screen.localizedName)
            configuredScreen = screen

            // The preferredDevice usually corresponds to the GPU associated with the screen that’s
            // displaying the view. Ensure the optimum Metal device is being used.
            device = preferredDevice ?? MTLCreateSystemDefaultDevice()
            guard let device = device else {
                os_log("Cannot get metal device", log: .render, type: .error)
                return
            }
            ciContext = CIContext(mtlDevice: device)

            // Aspects such as the ability to support extended dynamic range may have changed.
            // Reassess the configuration.
            settingChanged()
            return
        }

        // Same screen. Screen attributes must have changed. We are only interested in the display
        // headroom and only if the Metal renderer is being used with tone mapping.
        guard useMetalRenderer, toneMapping else { return }

        // Compare the current display headroom to the headroom used to configure tone mapping.
        let currentHeadroom = screen.maximumExtendedDynamicRangeColorComponentValue
        let changeInHeadroom = abs(currentHeadroom - configuredHeadroom)

        // The display headroom frequently changes by small amounts. To avoid constantly adjusting
        // tone mapping and redrawing ignore changes until the difference between the configured
        // and current headroom passes a threshold.
        guard changeInHeadroom > MetalImageView.headroomChangeThreshold else { return }
        guard let layer = layer as? CAMetalLayer else {
            os_log("Cannot get metal layer", log: .render, type: .error)
            return
        }
        configureMetalToneMapping(layer, screen)
        needsDisplay = true
    }

    /// Adjust the view configuration to reflect a change in settings.
    ///
    /// To minimize the amount of work done in the `draw` method objects that are not dependent upon the view size are
    /// constructed by this method and cached in private properties. When any of the inputs used by this method change it is called
    /// again to reconstruct the objects.
    ///
    /// This method is also responsible for deciding if this view should render the image or if the `NSViewImage` subview should be
    /// used. Should any problems constructing the objects be encountered the subview will be used.
    private func settingChanged() {

        // Discard state.
        ciImage = nil
        clearImage = false
        imageToRender = nil
        imageView.image = nil
        guard let layer = layer as? CAMetalLayer else {
            os_log("Cannot get metal layer", log: .render, type: .error)
            return
        }
        layer.colorspace = nil
        layer.edrMetadata = nil
        layer.wantsExtendedDynamicRangeContent = false
        useMetalRenderer = false

        // Nothing more to do if we don't have an image to display.
        guard let image = image else { return }

        // If this method exits without having decided to use the Metal renderer then switch to
        // using the NSImageView subview by passing the image to that view.
        defer {
            if !useMetalRenderer {
                // If the metal view is already displaying an image then it must be cleared so that
                // the image being displayed by the subview is visible.
                if showingImage {
                    clearImage = true
                    needsDisplay = true
                    os_log("Clearing image displayed by MTKView", log: .render, type: .debug)
                }
                // Pass the image to the NSImageView subview unless it has already been given a
                // tone mapped image to display.
                if imageView.image == nil { imageView.image = image }
                imageView.needsDisplay = true
                os_log("Using NSImageView to draw image", log: .render, type: .debug)
            }
#if DEBUG
            logState()
#endif
        }

        if !highDynamicRange {
            // The user disabled HDR in settings. This setting allows the user to fall back to using
            // NSImageView for rendering should a severe problem with this Metal based renderer be
            // encountered. Of course as of macOS Ventura NSImageView does not tone map HDR images
            // so highlights will be clipped.
            os_log("High dynamic range is disabled", log: .render, type: .info)
            return
        }

        // Use the NSImageView subview to display the SDR images.
        let imageFilename = window?.title ?? "<unknown>"
        guard image.isHighDynamicRange else {
            os_log("Not a high dynamic range image: %{private}@", log: .render, type: .info,
                    imageFilename)
            return
        }
        os_log("Rendering high dynamic range image: %{private}@", log: .render, type: .info,
                imageFilename)

        // Perform one time initialization that is not needed when displaying SDR images.
        guard onDemandInitialization() else { return }

        // Determine if extended dynamic range can be used.
        if extendedDynamicRange {
            guard let screen = screen else {
                os_log("Cannot get screen", log: .render, type: .error)
                return
            }
            if screen.maximumPotentialExtendedDynamicRangeColorComponentValue > 1.0 {
                os_log("Screen supports extended dynamic range: %{public}@ (max %.1fx)",
                       log: .render, type: .info, screen.localizedName,
                       screen.maximumPotentialExtendedDynamicRangeColorComponentValue)
                layer.wantsExtendedDynamicRangeContent = true
                if toneMapping {
                    if image.isInHybridLogGammaFormat {
                        // CAEDRMetadata documentation indicates the HLG inverse OETF must be
                        // applied to use HLG tone mapping. That has not been implemented, so EDR
                        // tone mapping can not be used for HLG images at this time.
                        os_log("Tone mapping for images using the hybrid log-gamma format is not implemented",
                               log: .render, type: .info)
                        return
                    }
                    configureMetalToneMapping(layer, screen)
                    os_log("Tone mapping HDR image to display headroom", log: .render, type: .info)
                } else if #available(macOS 13.0, *){
                    // Under macOS Ventura NSImageView is capable of displaying a HDR image once
                    // EDR has been enabled in the image, as long as tone mapping is not needed.
                    os_log("Tone mapping is disabled", log: .render, type: .info)
                    return
                }
            } else {
                os_log("Screen does not support extended dynamic range: %{public}@", log: .render,
                       type: .info, screen.localizedName)
            }
        } else {
            // The user disabled use of EDR. As EDR consumes more energy the user might choose to
            // turn it off to conserve battery.
            os_log("Extended dynamic range is disabled", log: .render, type: .info)
        }

        if !layer.wantsExtendedDynamicRangeContent {
            if !toneMapping {
                os_log("Tone mapping is disabled", log: .render, type: .info)
                return
            }
            if #unavailable(macOS 11.0) {
                os_log("Tone mapping is not working under macOS Catalina", log: .render, type: .info)
                return
            }
        }

        guard !image.representations.isEmpty,
              let bitmapImageRep = image.representations[0] as? NSBitmapImageRep else {
            // Internal error. A NSBitmapImageRep should have been attached by JXL.parse.
            os_log("Cannot get bitmapImageRep", log: .render, type: .error)
            return
        }
        guard let ciImage = CIImage(bitmapImageRep: bitmapImageRep) else {
            os_log("Cannot get ciImage", log: .render, type: .error)
            return
        }

        // If not using EDR then tone map the image to SDR.
        if !layer.wantsExtendedDynamicRangeContent {
            guard let ciContext = ciContext else {
                os_log("Cannot get ciContext", log: .render, type: .error)
                return
            }
            let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
            guard let cgImage = cgImage else {
                os_log("Cannot get cgImage", log: .render, type: .error)
                return
            }
            let size = NSSize(width: cgImage.width, height: cgImage.height)
            imageView.image = NSImage(cgImage: cgImage, size: size)
            return
        }

        // Use Metal to draw the image.
        self.ciImage = ciImage

        // Use an extended colorspace for EDR.
        guard let colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3) else {
            os_log("Cannot get extendedLinearDisplayP3 colorspace", log: .render, type: .error)
            return
        }
        layer.colorspace = colorspace

        // The reusable scale filter must have already been constructed and initialized.
        guard let scaleFilter = scaleFilter else {
            os_log("Cannot get scaleFilter", log: .render, type: .error)
            return
        }
        scaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
        scaleAndCenterImage()

        useMetalRenderer = true
        os_log("Using MTKView to draw image", log: .render, type: .debug)

        // Normally leave it to AppKit to decide when to redisplay the view.
        guard forceMetalDraw else {
            needsDisplay = true
            return
        }
        forceMetalDraw = false

        // When the window initially starts minimized to the dock setting needsDisplay will not
        // cause AppKit to draw the view. This is expected as the view is not visible. However this
        // causes the AppKit code that generates the window counterpart to construct a dock icon
        // that does not contain a miniaturized image as occurs with NSImageView. Forcing the view
        // to be drawn works around this issue. The window property isMiniaturized is of no help as
        // it initially returns false and is only updated by AppKit to true after the counterpart
        // has been generated.
        draw()
    }
}
