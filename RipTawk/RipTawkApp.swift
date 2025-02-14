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
    @StateObject private var authState = AuthState()
    @AppStorage("isDarkMode") private var isDarkMode: Bool?
    @StateObject private var projectManager = ProjectManager()
    
    private var effectiveColorScheme: ColorScheme? {
        isDarkMode.map { $0 ? .dark : .light }
    }
    
    init() {
        // Initialize VideoEditorSDK license
        let possiblePaths = [
            Bundle.main.url(forResource: "license", withExtension: ""),  // No extension
            Bundle.main.url(forResource: "license", withExtension: "txt"),  // With .txt extension
            Bundle.main.bundleURL.appendingPathComponent("license"),  // Direct in bundle
            Bundle.main.bundleURL.appendingPathComponent("Assets.xcassets/license"),  // In assets
            Bundle.main.resourceURL?.appendingPathComponent("license")  // In resources
        ].compactMap { $0 }
        
        print("📝 [LICENSE] Searching for license file in:")
        for path in possiblePaths {
            print("   - \(path.path)")
        }
        
        // Try each path until we find one that works
        for licenseURL in possiblePaths {
            if FileManager.default.fileExists(atPath: licenseURL.path) {
                print("📝 [LICENSE] Found license file at: \(licenseURL.path)")
                do {
                    let licenseData = try Data(contentsOf: licenseURL)
                    if let licenseString = String(data: licenseData, encoding: .utf8) {
                        print("📝 [LICENSE] License content length: \(licenseString.count)")
                        VESDK.unlockWithLicense(at: licenseURL)
                        print("✅ [LICENSE] Successfully initialized VideoEditorSDK")
                        return
                    }
                } catch {
                    print("❌ [LICENSE] Error reading license file at \(licenseURL.path): \(error)")
                }
            }
        }
        
        // If we get here, we couldn't find or load the license file
        print("❌ [LICENSE] Could not find or load license file in any location")
        print("📝 [LICENSE] Bundle path: \(Bundle.main.bundlePath)")
        print("📝 [LICENSE] All bundle resources:")
        for path in Bundle.main.paths(forResourcesOfType: nil, inDirectory: nil) {
            print("   - \(path)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authState.isInitializing {
                    ProgressView("Loading...")
                } else if authState.isAuthenticated {
                    ContentView(isAuthenticated: true)
                        .environmentObject(projectManager)
                } else {
                    ContentView(isAuthenticated: false)
                        .environmentObject(projectManager)
                }
            }
            .task {
                await authState.checkSession()
            }
            .preferredColorScheme(effectiveColorScheme)
        }
    }
}

@MainActor
class AuthState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isInitializing = true
    
    func checkSession() async {
        print("🔐 [APP] Checking authentication status...")
        isInitializing = true
        
        do {
            try await AppwriteService.shared.initializeSession()
            print("✅ [APP] User is authenticated")
            isAuthenticated = true
        } catch {
            print("❌ [APP] No valid session: \(error.localizedDescription)")
            isAuthenticated = false
        }
        
        isInitializing = false
    }
}