//
//  Extensions.swift
//  JXLook
//
//  Created by low-batt on 6/12/23.
//

import Cocoa

/// Extensions of enumerations declared outside of Swift that changes the conversion from the enum value to a string to use the
/// enumeration case name instead of the raw value. This improves the readability of log messages intended for developers.

extension JxlColorSpace: CustomStringConvertible {
    public var description: String {
        switch self {
        case JXL_COLOR_SPACE_RGB:
            // Tristimulus RGB
            return "JXL_COLOR_SPACE_RGB"
        case JXL_COLOR_SPACE_GRAY:
            // Luminance based, the primaries in JxlColorEncoding must be ignored. This value
            // implies that num_color_channels in JxlBasicInfo is 1, any other value implies
            // num_color_channels is 3.
            return "JXL_COLOR_SPACE_GRAY"
        case JXL_COLOR_SPACE_XYB:
            // XYB (opsin) color space
            return "JXL_COLOR_SPACE_XYB"
        case JXL_COLOR_SPACE_UNKNOWN:
            // None of the other table entries describe the color space appropriately
            return "JXL_COLOR_SPACE_UNKNOWN"
        default: return "JxlColorSpace(rawValue: \(rawValue))"
        }
    }
}

extension JxlOrientation: CustomStringConvertible {
    public var description: String {
        switch self {
        case JXL_ORIENT_IDENTITY: return "JXL_ORIENT_IDENTITY"
        case JXL_ORIENT_FLIP_HORIZONTAL: return "JXL_ORIENT_FLIP_HORIZONTAL"
        case JXL_ORIENT_ROTATE_180: return "JXL_ORIENT_ROTATE_180"
        case JXL_ORIENT_FLIP_VERTICAL: return "JXL_ORIENT_FLIP_VERTICAL"
        case JXL_ORIENT_TRANSPOSE: return "JXL_ORIENT_TRANSPOSE"
        case JXL_ORIENT_ROTATE_90_CW: return "JXL_ORIENT_ROTATE_90_CW"
        case JXL_ORIENT_ANTI_TRANSPOSE: return "JXL_ORIENT_ANTI_TRANSPOSE"
        case JXL_ORIENT_ROTATE_90_CCW: return "JXL_ORIENT_ROTATE_90_CCW"
        default: return "JxlOrientation(rawValue: \(rawValue))"
        }
    }
}

extension JxlPrimaries: CustomStringConvertible {
    public var description: String {
        switch self {
        case JXL_PRIMARIES_SRGB:
            // The CIE xy values of the red, green and blue primaries are: 0.639998686, 0.330010138;
            // 0.300003784, 0.600003357; 0.150002046, 0.059997204
           return "JXL_PRIMARIES_SRGB"
         case JXL_PRIMARIES_CUSTOM:
            // Primaries must be read from the JxlColorEncoding primaries_red_xy, primaries_green_xy
            // and primaries_blue_xy fields, or as ICC profile. This enum value is not an exact
            // match of the corresponding CICP value.
            return "JXL_PRIMARIES_CUSTOM"
        case JXL_PRIMARIES_2100:
            // As specified in Rec. ITU-R BT.2100-1
            return "JXL_PRIMARIES_2100"
        case JXL_PRIMARIES_P3:
            // As specified in SMPTE RP 431-2
            return "JXL_PRIMARIES_P3"
        default: return "JxlPrimaries(rawValue: \(rawValue))"
        }
    }
}

extension JxlRenderingIntent: CustomStringConvertible {
    public var description: String {
        switch self {
        case JXL_RENDERING_INTENT_PERCEPTUAL:
            // vendor-specific
            return "JXL_RENDERING_INTENT_PERCEPTUAL"
        case JXL_RENDERING_INTENT_RELATIVE:
            // media-relative
            return "JXL_RENDERING_INTENT_RELATIVE"
        case JXL_RENDERING_INTENT_SATURATION:
            // vendor-specific
            return "JXL_RENDERING_INTENT_SATURATION"
        case JXL_RENDERING_INTENT_ABSOLUTE:
            // ICC-absolute
            return "JXL_RENDERING_INTENT_ABSOLUTE"
        default: return "JxlRenderingIntent(rawValue: \(rawValue))"
        }
    }
}

extension JxlTransferFunction: CustomStringConvertible {
    public var description: String {
        switch self {
        case JXL_TRANSFER_FUNCTION_709:
            // As specified in SMPTE RP 431-2
            return "JXL_TRANSFER_FUNCTION_709"
        case JXL_TRANSFER_FUNCTION_UNKNOWN:
            // None of the other table entries describe the transfer function.
            return "JXL_TRANSFER_FUNCTION_UNKNOWN"
        case JXL_TRANSFER_FUNCTION_LINEAR:
            // The gamma exponent is 1
            return "JXL_TRANSFER_FUNCTION_LINEAR"
        case JXL_TRANSFER_FUNCTION_SRGB:
            // As specified in IEC 61966-2-1 sRGB
            return "JXL_TRANSFER_FUNCTION_SRGB"
        case JXL_TRANSFER_FUNCTION_PQ:
            // As specified in SMPTE ST 2084
            return "JXL_TRANSFER_FUNCTION_PQ"
        case JXL_TRANSFER_FUNCTION_DCI:
            // As specified in SMPTE ST 428-1
            return "JXL_TRANSFER_FUNCTION_DCI"
        case JXL_TRANSFER_FUNCTION_HLG:
            // As specified in Rec. ITU-R BT.2100-1 (HLG)
            return "JXL_TRANSFER_FUNCTION_HLG"
        case JXL_TRANSFER_FUNCTION_GAMMA:
            // Transfer function follows power law given by the gamma value in JxlColorEncoding.
            // Not a CICP value.
            return "JXL_TRANSFER_FUNCTION_GAMMA"
        default: return "JxlTransferFunction(rawValue: \(rawValue))"
        }
    }
}

extension JxlWhitePoint: CustomStringConvertible {
    public var description: String {
        switch self {
        case JXL_WHITE_POINT_D65:
            // CIE Standard Illuminant D65: 0.3127, 0.3290
            return "JXL_WHITE_POINT_D65"
        case JXL_WHITE_POINT_CUSTOM:
            // White point must be read from the JxlColorEncoding white_point field, or as ICC
            // profile. Th enum value is not an exact match of the corresponding CICP value.
            return "JXL_WHITE_POINT_CUSTOM"
        case JXL_WHITE_POINT_E:
            // CIE Standard Illuminant E (equal-energy): 1/3, 1/3
            return "JXL_WHITE_POINT_E"
        case JXL_WHITE_POINT_DCI:
            // DCI-P3 from SMPTE RP 431-2: 0.314, 0.351
            return "JXL_WHITE_POINT_DCI"
        default: return "JxlWhitePoint(rawValue: \(rawValue))"
        }
    }
}

extension MTLPixelFormat: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bgra8Unorm: return "bgra8Unorm"
        case .rgba16Float: return "rgba16Float"
        default: return "MTLPixelFormat(rawValue: \(rawValue))"
        }
    }
}
