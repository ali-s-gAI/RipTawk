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

    enum VideoQuality: String, CaseIterable, Identifiable {
        case low, medium, high
        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Account Section
                Section(header: Text("Account")) {
                    NavigationLink("Account Settings", destination: AccountSettingsView())
                    NavigationLink("Subscription", destination: Text("Subscription Details"))
                }
                
                // App Settings Section
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
                
                // Support Section
                Section(header: Text("Support")) {
                    NavigationLink("Help & Support", destination: Text("Help Center"))
                    NavigationLink("About", destination: Text("About RipTawk"))
                }
                
                // Sign Out Section
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
                Button("Save Changes") {
                    // Save changes action here.
                }
            }
            
            Section {
                NavigationLink("Change Password", destination: Text("Change Password"))
                NavigationLink("Privacy Settings", destination: Text("Privacy Settings"))
            }
        }
        .navigationTitle("Account Settings")
    }
}

extension Notification.Name {
    static let userDidSignOut = Notification.Name("userDidSignOut")
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

