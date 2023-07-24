//
//  Settings.swift
//  JXLook
//
//  Created by low-batt on 6/12/23.
//

import Foundation
import os

/// An interface for accessing user's application settings.
///
/// This is merely a wrapper around the macOS
/// [UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults)
/// system that simplifies access to settings.
struct Settings {
    /// The `Settings` singleton object.
    static let shared = Settings()

    enum Key: String {
        case extendedDynamicRange
        case highDynamicRange
        case toneMapping
    }

    // MARK: - Settings Properties

    /// Enable extended dynamic range for high dynamic range images on screens that support EDR.
    ///
    /// - Note: EDR support requires the `highDynamicRange` setting be enabled.
    var extendedDynamicRange: Bool { bool(.extendedDynamicRange) }

    /// Enable use of a custom a renderer for high dynamic range images.
    ///
    /// Disabling this setting results in HDR images being passed directly to
    /// [NSImageView](https://developer.apple.com/documentation/appkit/nsimageview). As of macOS Ventura
    /// `NSImageView` does not enable EDR and does not tone map HDR images resulting in clipping of  highlights. Therefore
    /// disabling this setting usually produces undesirable results for HDR images. This setting is useful in order to be able to see the
    /// changes in rendering provided by the `MetalImageView` class. This also provides a workaround should problems in the
    /// custom rendering code be encountered.
    var highDynamicRange: Bool { bool(.highDynamicRange) }

    /// Enable tone mapping for high dynamic range images.
    ///
    /// When EDR is active HDR images will be dynamically tone mapped to stay within the current headroom of the display. When
    /// EDR is not available HDR images will be tone mapped to SDR.
    /// - Note: tone mapping support requires the `highDynamicRange` setting be enabled.
    var toneMapping: Bool { bool(.toneMapping) }

    // MARK: - Default Registration

    /// Register default values with the
    /// [UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults) system for all of
    /// the settings
    func registerDefaults() {
        let defaults: [String: Any] = [Key.extendedDynamicRange.rawValue: true,
                                       Key.highDynamicRange.rawValue: true,
                                       Key.toneMapping.rawValue: true]
        UserDefaults.standard.register(defaults: defaults)
    }

    // MARK: - Observer Registration

    /// Registers the observer object to receive notifications for the specified setting.
    ///
    /// This is a simple wrapper that merely allows the caller to specify the setting as a `Key` enumeration value instead of a String.
    /// - Parameters:
    ///   - observer: The object to register for notifications of changes to the specified setting. The observer must implement
    ///               the key-value observing method [observeValue(forKeyPath:of:change:context:)](https://developer.apple.com/documentation/objectivec/nsobject/1416553-observevalue).
    ///   - key: The setting to observe.
    ///   - options: A combination of the `NSKeyValueObservingOptions` values that specifies what is included in
    ///             observation notifications. For possible values, see [NSKeyValueObservingOptions](https://developer.apple.com/documentation/foundation/nskeyvalueobservingoptions).
    ///   - context: Arbitrary data that is passed to observer in [observeValue(forKeyPath:of:change:context:)](https://developer.apple.com/documentation/objectivec/nsobject/1416553-observevalue).
    func addObserver(_ observer: NSObject, forKey key: Key, options: NSKeyValueObservingOptions = [],
                     context: UnsafeMutableRawPointer?) {
        UserDefaults.standard.addObserver(observer, forKeyPath: key.rawValue, options: options,
                                          context: context)
    }

    /// Removes matching entries from the notification center's dispatch table.
    ///
    /// This is a simple wrapper that merely allows the caller to specify the setting as a `Key` enumeration value instead of a String.
    /// - Parameters:
    ///   - observer: The observer to remove from the dispatch table. Specify an observer to remove only entries for this observer.
    ///   - key: The setting being observed.
    func removeObserver(_ observer: NSObject, forKey key: Key) {
        UserDefaults.standard.removeObserver(observer, forKeyPath: key.rawValue)
    }

    // MARK: - Private Functions

    /// Returns the value for the specified setting.
    ///
    /// This is a simple wrapper that merely allows the caller to specify the setting as a `Key` enumeration value instead of a String.
    /// - Parameter key: The setting to return the value of.
    /// - Returns: The value set for the specified setting.
    private func bool(_ key: Key) -> Bool {
        UserDefaults.standard.bool(forKey: key.rawValue)
    }

    private init() {}
}
