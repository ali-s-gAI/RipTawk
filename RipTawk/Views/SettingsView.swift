//
//  SettingsView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import Appwrite

struct SettingsView: View {
    @State private var notificationsEnabled = true
    @State private var darkModeEnabled = false
    @State private var autoSaveInterval = 5
    @State private var selectedQuality = VideoQuality.high
    @State private var showSignOutAlert = false
    @Environment(\.dismiss) private var dismiss

    enum VideoQuality: String, CaseIterable, Identifiable {
        case low, medium, high
        var id: Self { self }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account")) {
                    NavigationLink("Account Settings") {
                        Text("Account Settings")
                    }
                    NavigationLink("Subscription") {
                        Text("Subscription Details")
                    }
                }
                
                Section(header: Text("App Settings")) {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    Toggle("Dark Mode", isOn: $darkModeEnabled)
                    Picker("Auto-Save Interval", selection: $autoSaveInterval) {
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("10 minutes").tag(10)
                    }
                    Picker("Video Quality", selection: $selectedQuality) {
                        ForEach(VideoQuality.allCases) { quality in
                            Text(quality.rawValue.capitalized).tag(quality)
                        }
                    }
                }
                
                Section(header: Text("Support")) {
                    NavigationLink("Help & Support") {
                        Text("Help Center")
                    }
                    NavigationLink("About") {
                        Text("About RipTawk")
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    private func signOut() {
        Task {
            do {
                try await AppwriteService.shared.account.deleteSession(sessionId: "current")
                NotificationCenter.default.post(name: .userDidSignOut, object: nil)
            } catch {
                print("Sign out error: \(error.localizedDescription)")
            }
        }
    }
}

struct AccountSettingsView: View {
    @State private var username = ""
    @State private var email = ""
    @State private var bio = ""

    var body: some View {
        Form {
            Section(header: Text("Profile Information")) {
                TextField("Username", text: $username)
                TextField("Email", text: $email)
                TextEditor(text: $bio)
                    .frame(height: 100)
            }
            
            Section {
                Button(action: {
                    // Save changes
                }) {
                    Text("Save Changes")
                }
            }
            
            Section {
                NavigationLink(destination: Text("Change Password")) {
                    Text("Change Password")
                }
                NavigationLink(destination: Text("Privacy Settings")) {
                    Text("Privacy Settings")
                }
            }
        }
        .navigationTitle("Account Settings")
    }
}

// Add this extension somewhere in your project, like in a separate Notifications.swift file
extension Notification.Name {
    static let userDidSignOut = Notification.Name("userDidSignOut")
}

