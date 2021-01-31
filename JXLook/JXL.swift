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
        var buffer: UnsafeMutableBufferPointer<UInt8> = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 1)
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
            
            var format = JxlPixelFormat(num_channels: 4, data_type: JXL_TYPE_UINT8, endianness: JXL_NATIVE_ENDIAN, align: 0)
            
            JxlDecoderSetInput(decoder, nextIn, bytes.count)
            
            parsingLoop: while true {
                let result = JxlDecoderProcessInput(decoder)
                
                switch result {
                case JXL_DEC_BASIC_INFO:
                    if JxlDecoderGetBasicInfo(decoder, infoPtr) != JXL_DEC_SUCCESS {
                        Swift.print("Cannot get basic info")
                        break parsingLoop
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
                    let colorSpace = icc.flatMap({ NSColorSpace(iccProfileData: Data(buffer: $0)) }) ?? .sRGB
                    if let imageRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(info.xsize), pixelsHigh: Int(info.ysize), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: 4 * Int(info.xsize), bitsPerPixel: 32)?.retagging(with: colorSpace) {
                        imageRep.size = CGSize(width: Int(info.xsize) / 2, height: Int(info.ysize) / 2)
                        if let pixels = imageRep.bitmapData {
                            memmove(pixels, buffer.baseAddress, buffer.count)
                        }
                        let img = NSImage(size: imageRep.size)
                        img.addRepresentation(imageRep)
                        image = img
                    }
                    
                case JXL_DEC_NEED_IMAGE_OUT_BUFFER:
                    var outputBufferSize: Int = 0
                    if JxlDecoderImageOutBufferSize(decoder, &format, &outputBufferSize) != JXL_DEC_SUCCESS {
                        Swift.print("cannot get size")
                    }
                    Swift.print("buffer size: \(outputBufferSize)")
                    
                    buffer.deallocate()
                    buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: outputBufferSize)
                    
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
