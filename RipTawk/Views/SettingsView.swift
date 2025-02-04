//
//  SettingsView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI

struct SettingsView: View {
    @State private var notificationsEnabled = true
    @State private var darkModeEnabled = false
    @State private var autoSaveInterval = 5
    @State private var selectedQuality = VideoQuality.high

    enum VideoQuality: String, CaseIterable, Identifiable {
        case low, medium, high
        var id: Self { self }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account")) {
                    NavigationLink(destination: AccountSettingsView()) {
                        Text("Account Settings")
                    }
                    NavigationLink(destination: Text("Subscription Details")) {
                        Text("Subscription")
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
                    NavigationLink(destination: Text("Help Center")) {
                        Text("Help & Support")
                    }
                    NavigationLink(destination: Text("About CreatorCut")) {
                        Text("About")
                    }
                }
                
                Section {
                    Button(action: {
                        // Perform logout
                    }) {
                        Text("Log Out")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
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

