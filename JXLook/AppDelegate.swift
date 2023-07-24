//
//  AppDelegate.swift
//  JXLook
//
//  Created by Yung-Luen Lan on 2021/1/18.
//

import Cocoa
import os

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Settings.shared.registerDefaults()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        if let dictionary = Bundle.main.infoDictionary {
            if let version = dictionary["CFBundleShortVersionString"] as? String,
               let build = dictionary["CFBundleVersion"] as? String {
                os_log("JXLook %{public}@", log: .view, type: .info, "\(version) (\(build))")
            }
            if let copyright = dictionary["NSHumanReadableCopyright"] as? String {
                os_log("%{public}@", log: .view, type: .info, copyright)
            }
        }
        os_log("Using libjxl %{public}@", log: .view, type: .info,
               "v\(JPEGXL_MAJOR_VERSION).\(JPEGXL_MINOR_VERSION).\(JPEGXL_PATCH_VERSION)")
        os_log("Running under macOS %{public}@", log: .view, type: .info,
               ProcessInfo.processInfo.operatingSystemVersionString)
   }

    func applicationWillTerminate(_ aNotification: Notification) {
        os_log("Terminating", log: .view, type: .info)
    }
}
