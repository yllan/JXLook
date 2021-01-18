//
//  Document.swift
//  JXLook
//
//  Created by Yung-Luen Lan on 2021/1/18.
//

import Cocoa

class Document: NSDocument {
    var image: NSImage? = nil
    
    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
        self.addWindowController(windowController)
        if let vc = windowController.contentViewController as? ViewController {
            vc.representedObject = self
        }
    }

    override func data(ofType typeName: String) throws -> Data {
        // Insert code here to write your document to data of the specified type, throwing an error in case of failure.
        // Alternatively, you could remove this method and override fileWrapper(ofType:), write(to:ofType:), or write(to:ofType:for:originalContentsURL:) instead.
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        let isValid = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> Bool in
            if let ptr = bytes.bindMemory(to: UInt8.self).baseAddress {
                let result = JxlSignatureCheck(ptr, CLong(bytes.count))
                return result == JXL_SIG_CODESTREAM || result == JXL_SIG_CONTAINER
            } else {
                return false
            }
        }
        guard isValid else {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
        let decoder = JxlDecoderCreate(nil)
        let runner = JxlThreadParallelRunnerCreate(nil, JxlThreadParallelRunnerDefaultNumWorkerThreads())
        if JxlDecoderSetParallelRunner(decoder, JxlThreadParallelRunner, runner) != JXL_DEC_SUCCESS {
            Swift.print("Cannot set runner")
        }
        
//        var fptr = UnsafeMutablePointer<JxlPixelFormat>.allocate(capacity: 1)
//        JxlDecoderDefaultPixelFormat(decoder, fptr)
//        Swift.print("format: \(fptr.pointee)")
        JxlDecoderSubscribeEvents(decoder, Int32(JXL_DEC_BASIC_INFO.rawValue | JXL_DEC_FULL_IMAGE.rawValue))
        
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> Bool in
            var nextIn = bytes.bindMemory(to: UInt8.self).baseAddress
            var available: Int = data.count
            let infoPtr = UnsafeMutablePointer<JxlBasicInfo>.allocate(capacity: 1)
            while true {
                let result = JxlDecoderProcessInput(decoder, &nextIn, &available)
                Swift.print("r: \(result), avail: \(available)")
                switch result {
                case JXL_DEC_BASIC_INFO:
                    if JxlDecoderGetBasicInfo(decoder, infoPtr) != JXL_DEC_SUCCESS {
                        Swift.print("Cannot get basic info")
                        break
                    }
                    Swift.print("basic info: \(infoPtr.pointee)")
                case JXL_DEC_SUCCESS:
                    return true
                case JXL_DEC_NEED_IMAGE_OUT_BUFFER:
                    let info = infoPtr.pointee
                    var format = JxlPixelFormat(num_channels: 4, data_type: JXL_TYPE_UINT8, endianness: JXL_NATIVE_ENDIAN, align: 0)
                    var outputBufferSize: Int = 0
                    if JxlDecoderImageOutBufferSize(decoder, &format, &outputBufferSize) != JXL_DEC_SUCCESS {
                        Swift.print("cannot get size")
                    }
                    Swift.print("buffer size: \(outputBufferSize)")
                    let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: outputBufferSize)
                    if JxlDecoderSetImageOutBuffer(decoder, &format, buffer.baseAddress, outputBufferSize) != JXL_DEC_SUCCESS {
                        Swift.print("cannot write buffer")
                    }
//                    for i in 0..<200 {
//                        Swift.print(buffer[i])
//                    }
                    let planes = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 1)
                    planes.pointee = buffer.baseAddress
                    if let imageRep = NSBitmapImageRep(bitmapDataPlanes: planes, pixelsWide: Int(info.xsize), pixelsHigh: Int(info.ysize), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: 4 * Int(info.xsize), bitsPerPixel: 32) {
                        let img = NSImage(size: imageRep.size)
                        img.addRepresentation(imageRep)
                        self.image = img
                    }
                case JXL_DEC_ERROR:
                    return false
                default:
                    Swift.print("result \(result)")
                }
            }
        }
    }


}

