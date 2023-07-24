//
//  JXL.swift
//  JXLook
//
//  Created by Yung-Luen Lan on 2021/1/22.
//

import Foundation
import Cocoa
import os

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
            os_log("Cannot set runner", log: .decode, type: .error)
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
            
            var colorEncoding: JxlColorEncoding? = nil

            parsingLoop: while true {
                let result = JxlDecoderProcessInput(decoder)
                
                switch result {
                case JXL_DEC_BASIC_INFO:
                    if JxlDecoderGetBasicInfo(decoder, infoPtr) != JXL_DEC_SUCCESS {
                        os_log("Cannot get basic info", log: .decode, type: .error)
                        break parsingLoop
                    }
                    let info: JxlBasicInfo = infoPtr.pointee
                    var output_num_channels: UInt32 = info.num_color_channels;
                    if info.alpha_bits != 0 {
                        output_num_channels += 1 // output rgba if we have alpha channel
                    }
                    let data_type: JxlDataType = output_num_channels < 3 ? info.bits_per_sample == 16 ? JXL_TYPE_UINT16 : JXL_TYPE_UINT8 : JXL_TYPE_FLOAT;
                    format = JxlPixelFormat(num_channels: output_num_channels, data_type: data_type, endianness: JXL_NATIVE_ENDIAN, align: 0)
                    
                    os_log("Basic info: %{public}@", log: .decode, type: .debug, "\(infoPtr.pointee)")
                case JXL_DEC_SUCCESS:
                    return true
                case JXL_DEC_COLOR_ENCODING:
                    var encoding = JxlColorEncoding()
                    if JxlDecoderGetColorAsEncodedProfile(decoder, nil,
                        JXL_COLOR_PROFILE_TARGET_ORIGINAL, &encoding) == JXL_DEC_SUCCESS {
                        if JxlDecoderSetPreferredColorProfile(decoder, &encoding) != JXL_DEC_SUCCESS {
                            os_log("Cannot set color encoding", log: .decode, type: .error)
                        }
                        os_log("Color encoding: %{public}@", log: .decode, type: .debug, "\(encoding)")
                        colorEncoding = encoding
                    } else {
                        var iccSize: size_t = 0
                        if JxlDecoderGetICCProfileSize(decoder, &format, JXL_COLOR_PROFILE_TARGET_DATA, &iccSize) != JXL_DEC_SUCCESS {
                            os_log("Cannot get ICC size", log: .decode, type: .error)
                        }
                        icc?.deallocate()
                        icc = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: iccSize)
                        if JxlDecoderGetColorAsICCProfile(decoder, &format, JXL_COLOR_PROFILE_TARGET_DATA, icc!.baseAddress, iccSize) != JXL_DEC_SUCCESS {
                            os_log("Cannot get ICC", log: .decode, type: .error)
                        }
                    }
                case JXL_DEC_FULL_IMAGE:
                    let info = infoPtr.pointee
                    if (image != nil) {
                        // todo: support animated JSX
                        // Currently returns the first frame
                        return true;
                    }
                    if info.num_color_channels == 1 { // greyscale
                        let num_channels = Int(format.num_channels)
                        let colorSpace = icc.flatMap({ NSColorSpace(iccProfileData: Data(buffer: $0)) }) ?? .genericGray
                        var bitmapFormat: UInt = 0;
                        if (info.alpha_premultiplied == 0) {
                            bitmapFormat |= NSBitmapImageRep.Format.alphaNonpremultiplied.rawValue
                        }
                        if let imageRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(info.xsize), pixelsHigh: Int(info.ysize), bitsPerSample: Int(info.bits_per_sample), samplesPerPixel: num_channels, hasAlpha: info.alpha_bits != 0, isPlanar: false, colorSpaceName: .calibratedWhite, bitmapFormat: .init(rawValue: bitmapFormat), bytesPerRow: Int(info.bits_per_sample) / 8 * num_channels * Int(info.xsize), bitsPerPixel: Int(info.bits_per_sample) * num_channels)?.retagging(with: colorSpace) {
                            if let pixels = imageRep.bitmapData {
                                memmove(pixels, buffer.baseAddress, buffer.count)
                            }
                            let img = NSImage(size: imageRep.size)
                            img.addRepresentation(imageRep)
                            image = img
                        }
                    } else { // assume it's rgb
                        let num_channels = Int(format.num_channels)
                        let colorSpace = decodeColorSpace(colorEncoding, icc)
                        os_log("Color space: %{public}@", log: .decode, type: .debug, "\(colorSpace)")

                        let colorSpaceName: NSColorSpaceName = .calibratedRGB
                        var bitmapFormat: UInt = NSBitmapImageRep.Format.floatingPointSamples.rawValue;
                        if (info.alpha_premultiplied == 0) {
                            bitmapFormat |= NSBitmapImageRep.Format.alphaNonpremultiplied.rawValue
                        }
                        if let imageRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(info.xsize), pixelsHigh: Int(info.ysize), bitsPerSample: 32, samplesPerPixel: num_channels, hasAlpha: info.alpha_bits != 0, isPlanar: false, colorSpaceName: colorSpaceName, bitmapFormat: .init(rawValue: bitmapFormat), bytesPerRow: 4 * num_channels * Int(info.xsize), bitsPerPixel: 32 * num_channels)?.retagging(with: colorSpace) {
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
                        os_log("Cannot get size", log: .decode, type: .error)
                    }
                    os_log("Buffer size: %d", log: .decode, type: .debug, outputBufferSize)

                    buffer.deallocate()
                    buffer = UnsafeMutableBufferPointer<Float>.allocate(capacity: outputBufferSize)
                    
                    if JxlDecoderSetImageOutBuffer(decoder, &format, buffer.baseAddress, outputBufferSize) != JXL_DEC_SUCCESS {
                        os_log("Cannot write buffer", log: .decode, type: .error)
                    }
                case JXL_DEC_ERROR:
                    return false
                default:
                    os_log("Result: %{public}@", log: .decode, type: .debug, "\(result)")
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

    private static func constructColorSpace(_ name: CFString) -> NSColorSpace {
        guard let cgColorSpace = CGColorSpace(name: name) else {
            os_log("Cannot get cgColorSpace for name: %{public}@", log: .decode, type: .error,
                   "\(name)")
            return .sRGB
        }
        guard let nsColorSpace = NSColorSpace(cgColorSpace: cgColorSpace) else {
            os_log("Cannot get nsColorSpace for cgColorSpace: %{public}@", log: .decode,
                   type: .error, "\(name)")
            return .sRGB
        }
        return nsColorSpace
    }

    private static func decodeColorSpace(_ colorEncoding: JxlColorEncoding?,
                                         _ icc: UnsafeMutableBufferPointer<UInt8>?) -> NSColorSpace {
        if let colorEncoding = colorEncoding {
            switch colorEncoding.primaries {
            case JXL_PRIMARIES_SRGB:
                return .sRGB
            case JXL_PRIMARIES_CUSTOM:
                os_log("Mising implementation for color encoding primaries of type: JXL_PRIMARIES_CUSTOM",
                       log: .decode, type: .error)
                return .sRGB
            case JXL_PRIMARIES_2100:
                switch colorEncoding.transfer_function {
                case JXL_TRANSFER_FUNCTION_PQ:
                    if #available(macOS 11.0, *) {
                        return constructColorSpace(CGColorSpace.itur_2100_PQ)
                    } else if #available(macOS 10.15.4, *) {
                        return constructColorSpace(CGColorSpace.itur_2020_PQ)
                    } else {
                        return constructColorSpace(CGColorSpace.itur_2020_PQ_EOTF)
                    }
                case JXL_TRANSFER_FUNCTION_HLG:
                    if #available(macOS 11.0, *) {
                        return constructColorSpace(CGColorSpace.itur_2100_HLG)
                    } else if #available(macOS 10.15.6, *) {
                        return constructColorSpace(CGColorSpace.itur_2020_HLG)
                    } else {
                        os_log("Mising implementation for transfer function of type: JXL_TRANSFER_FUNCTION_HLG",
                               log: .decode, type: .error)
                        return .sRGB
                    }
                default:
                    os_log("Unexpected color transfer function: %{public}@", log: .decode, type: .error,
                           "\(colorEncoding.transfer_function)")
                    return .sRGB
                }
            case JXL_PRIMARIES_P3:
                if #available(macOS 10.15.4, *) {
                    return constructColorSpace(CGColorSpace.displayP3_PQ)
                } else {
                    return constructColorSpace(CGColorSpace.displayP3_PQ_EOTF)
                }
            default:
                os_log("Unexpected color encoding primaries: %{public}@", log: .decode, type: .error,
                       "\(colorEncoding.primaries)")
                return .sRGB
            }
        }
        return icc.flatMap({ NSColorSpace(iccProfileData: Data(buffer: $0)) }) ?? .sRGB
    }
}
