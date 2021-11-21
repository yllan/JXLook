//
//  JXL.swift
//  JXLook
//
//  Created by Yung-Luen Lan on 2021/1/22.
//

import Foundation
import Cocoa

enum JXLError: Error {
    case cannotDecode
}

struct JXL {
    static func parse(data: Data) throws -> NSImage? {
        var image: NSImage? = nil
        var buffer: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer<Float>.allocate(capacity: 1)
        var icc: UnsafeMutableBufferPointer<UInt8>? = nil
        
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
        
        JxlDecoderSubscribeEvents(decoder, Int32(JXL_DEC_BASIC_INFO.rawValue | JXL_DEC_COLOR_ENCODING.rawValue | JXL_DEC_FULL_IMAGE.rawValue))
        
        let _ = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> Bool in
            let nextIn = bytes.bindMemory(to: UInt8.self).baseAddress
            let infoPtr = UnsafeMutablePointer<JxlBasicInfo>.allocate(capacity: 1)
            defer {
                infoPtr.deallocate()
            }
            
            var format = JxlPixelFormat(num_channels: 4, data_type: JXL_TYPE_FLOAT, endianness: JXL_NATIVE_ENDIAN, align: 0)
            
            JxlDecoderSetInput(decoder, nextIn, bytes.count)
            
            parsingLoop: while true {
                let result = JxlDecoderProcessInput(decoder)
                
                switch result {
                case JXL_DEC_BASIC_INFO:
                    if JxlDecoderGetBasicInfo(decoder, infoPtr) != JXL_DEC_SUCCESS {
                        Swift.print("Cannot get basic info")
                        break parsingLoop
                    }
                    let info: JxlBasicInfo = infoPtr.pointee
                    if info.num_color_channels == 1 {
                        format = JxlPixelFormat(num_channels: 1, data_type: infoPtr.pointee.bits_per_sample == 16 ? JXL_TYPE_UINT16 : JXL_TYPE_UINT8, endianness: JXL_NATIVE_ENDIAN, align: 0)
                    } else {
                        var output_num_channels: UInt32 = 3; // assume rgb
                        if info.alpha_bits != 0 {
                            output_num_channels = 4 // output rgba if we have alpha channel
                        }
                        format = JxlPixelFormat(num_channels: output_num_channels, data_type: JXL_TYPE_FLOAT, endianness: JXL_NATIVE_ENDIAN, align: 0)
                    }
                    Swift.print("basic info: \(infoPtr.pointee)")
                case JXL_DEC_SUCCESS:
                    return true
                case JXL_DEC_COLOR_ENCODING:
                    var iccSize: size_t = 0
                    if JxlDecoderGetICCProfileSize(decoder, &format, JXL_COLOR_PROFILE_TARGET_DATA, &iccSize) != JXL_DEC_SUCCESS {
                        Swift.print("Cannot get ICC size")
                    }
                    icc?.deallocate() 
                    icc = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: iccSize)
                    if JxlDecoderGetColorAsICCProfile(decoder, &format, JXL_COLOR_PROFILE_TARGET_DATA, icc!.baseAddress, iccSize) != JXL_DEC_SUCCESS {
                        Swift.print("Cannot get ICC")
                    }
                    
                case JXL_DEC_FULL_IMAGE:
                    let info = infoPtr.pointee
                    if (image != nil) {
                        // todo: support animated JSX
                        // Currently returns the first frame
                        return true;
                    }
                    if info.num_color_channels == 1 { // greyscale
                        let colorSpace = icc.flatMap({ NSColorSpace(iccProfileData: Data(buffer: $0)) }) ?? .genericGray
                        if let imageRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(info.xsize), pixelsHigh: Int(info.ysize), bitsPerSample: Int(info.bits_per_sample), samplesPerPixel: 1, hasAlpha: false, isPlanar: false, colorSpaceName: .calibratedWhite, bytesPerRow: Int(info.bits_per_sample) / 8 * Int(info.xsize), bitsPerPixel: Int(info.bits_per_sample))?.retagging(with: colorSpace) {
                            imageRep.size = CGSize(width: Int(info.xsize), height: Int(info.ysize))
                            if let pixels = imageRep.bitmapData {
                                memmove(pixels, buffer.baseAddress, buffer.count)
                            }
                            let img = NSImage(size: imageRep.size)
                            img.addRepresentation(imageRep)
                            image = img
                        }
                    } else { // assume it's rgb
                        let num_channels = Int(format.num_channels)
                        let colorSpace = icc.flatMap({ NSColorSpace(iccProfileData: Data(buffer: $0)) }) ?? .sRGB
                        let colorSpaceName: NSColorSpaceName = .calibratedRGB
                        var bitmapFormat: UInt = NSBitmapImageRep.Format.floatingPointSamples.rawValue;
                        if (info.alpha_premultiplied == 0) {
                            bitmapFormat |= NSBitmapImageRep.Format.alphaNonpremultiplied.rawValue
                        }
                        if let imageRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(info.xsize), pixelsHigh: Int(info.ysize), bitsPerSample: 32, samplesPerPixel: num_channels, hasAlpha: info.alpha_bits != 0, isPlanar: false, colorSpaceName: colorSpaceName, bitmapFormat: .init(rawValue: bitmapFormat), bytesPerRow: 4 * num_channels * Int(info.xsize), bitsPerPixel: 32 * num_channels)?.retagging(with: colorSpace) {
                            imageRep.size = CGSize(width: Int(info.xsize), height: Int(info.ysize))
                            if let pixels = imageRep.bitmapData {
                                memmove(pixels, buffer.baseAddress, buffer.count)
                            }
                            let img = NSImage(size: imageRep.size)
                            img.addRepresentation(imageRep)
                            image = img
                        }
                    }

                    
                case JXL_DEC_NEED_IMAGE_OUT_BUFFER:
                    var outputBufferSize: Int = 0
                    if JxlDecoderImageOutBufferSize(decoder, &format, &outputBufferSize) != JXL_DEC_SUCCESS {
                        Swift.print("cannot get size")
                    }
                    Swift.print("buffer size: \(outputBufferSize)")
                    
                    buffer.deallocate()
                    buffer = UnsafeMutableBufferPointer<Float>.allocate(capacity: outputBufferSize)
                    
                    if JxlDecoderSetImageOutBuffer(decoder, &format, buffer.baseAddress, outputBufferSize) != JXL_DEC_SUCCESS {
                        Swift.print("cannot write buffer")
                    }
                case JXL_DEC_ERROR:
                    return false
                default:
                    Swift.print("result \(result)")
                }
            }
            return false
        }
        icc?.deallocate()
        buffer.deallocate()
        JxlThreadParallelRunnerDestroy(runner)
        JxlDecoderDestroy(decoder)
        return image
    }
}
