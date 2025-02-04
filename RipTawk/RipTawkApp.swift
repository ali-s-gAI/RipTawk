//
//  RipTawkApp.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import VideoEditorSDK

@main
struct RipTawkApp: App {
    init() {
        // Initialize VideoEditorSDK license
        if let licenseURL = Bundle.main.url(forResource: "license", withExtension: "") {
            VESDK.unlockWithLicense(at: licenseURL)
        } else {
            print("⚠️ VideoEditorSDK license file not found")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
