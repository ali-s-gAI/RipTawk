//
//  SettingsView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import Appwrite

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode: Bool?
    @State private var username = ""
    @State private var email = ""
    @State private var showChangePassword = false
    @State private var showSignOutAlert = false
    @State private var isEditingUsername = false
    @State private var newUsername = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isClearingCache = false
    
    // Password change states
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    @Environment(\.colorScheme) private var systemColorScheme
    
    private var effectiveColorScheme: ColorScheme {
        if let isDarkMode {
            return isDarkMode ? .dark : .light
        }
        return systemColorScheme
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Profile Section
                Section {
                    HStack {
                        Text("Username")
                        Spacer()
                        if isEditingUsername {
                            TextField("New username", text: $newUsername)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .submitLabel(.done)
                                .onSubmit(updateUsername)
                        } else {
                            Text(username)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onTapGesture {
                        if !isEditingUsername {
                            newUsername = username
                            isEditingUsername = true
                        }
                    }
                    
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(email)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("Change Password") {
                        showChangePassword = true
                    }
                } header: {
                    Text("Profile")
                }
                
                // Updated Appearance Section
                Section {
                    Picker("Appearance", selection: .init(
                        get: { isDarkMode },
                        set: { newValue in
                            isDarkMode = newValue
                            UserDefaults.standard.synchronize()
                        }
                    )) {
                        Text("System").tag(Optional<Bool>.none)
                        Text("Light").tag(Optional<Bool>.some(false))
                        Text("Dark").tag(Optional<Bool>.some(true))
                    }
                } header: {
                    Text("Appearance")
                }
                
                // Cache Section
                Section {
                    Button(action: clearCache) {
                        HStack {
                            Text("Clear Cache")
                            Spacer()
                            if isClearingCache {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isClearingCache)
                } header: {
                    Text("Storage")
                }
                
                // Sign Out Section
                Section {
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .preferredColorScheme(effectiveColorScheme)
            .onAppear(perform: loadUserData)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .sheet(isPresented: $showChangePassword) {
                changePasswordView
            }
        }
    }
    
    private var changePasswordView: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Current Password", text: $oldPassword)
                    SecureField("New Password", text: $newPassword)
                    SecureField("Confirm New Password", text: $confirmPassword)
                }
                
                Section {
                    Button("Update Password") {
                        updatePassword()
                    }
                    .disabled(oldPassword.isEmpty || newPassword.isEmpty || newPassword != confirmPassword)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showChangePassword = false
                    }
                }
            }
        }
    }
    
    private func loadUserData() {
        Task {
            do {
                let account = try await AppwriteService.shared.account.get()
                await MainActor.run {
                    username = account.name
                    email = account.email
                    print("👤 [SETTINGS] Loaded user data - Name: \(username), Email: \(email)")
                }
            } catch {
                print("❌ [SETTINGS] Failed to load user data: \(error.localizedDescription)")
                errorMessage = "Failed to load user data"
                showError = true
            }
        }
    }
    
    private func updateUsername() {
        guard !newUsername.isEmpty, newUsername != username else {
            isEditingUsername = false
            return
        }
        
        Task {
            do {
                let account = try await AppwriteService.shared.account.updateName(name: newUsername)
                await MainActor.run {
                    username = account.name
                    isEditingUsername = false
                    print("✅ [SETTINGS] Updated username to: \(username)")
                }
            } catch {
                print("❌ [SETTINGS] Failed to update username: \(error.localizedDescription)")
                errorMessage = "Failed to update username"
                showError = true
                isEditingUsername = false
            }
        }
    }
    
    private func updatePassword() {
        Task {
            do {
                try await AppwriteService.shared.account.updatePassword(
                    password: newPassword,
                    oldPassword: oldPassword
                )
                await MainActor.run {
                    showChangePassword = false
                    oldPassword = ""
                    newPassword = ""
                    confirmPassword = ""
                    print("✅ [SETTINGS] Password updated successfully")
                }
            } catch {
                print("❌ [SETTINGS] Failed to update password: \(error.localizedDescription)")
                errorMessage = "Failed to update password"
                showError = true
            }
        }
    }
    
    private func clearCache() {
        Task {
            await MainActor.run { isClearingCache = true }
            do {
                // Clear video cache
                if let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("videoCache") {
                    try FileManager.default.removeItem(at: cachePath)
                    try FileManager.default.createDirectory(at: cachePath, withIntermediateDirectories: true)
                }
                print("✅ [SETTINGS] Cache cleared successfully")
            } catch {
                print("❌ [SETTINGS] Failed to clear cache: \(error.localizedDescription)")
                errorMessage = "Failed to clear cache"
                showError = true
            }
            await MainActor.run { isClearingCache = false }
        }
    }
    
    private func signOut() {
        Task {
            do {
                try await AppwriteService.shared.signOut()
                print("✅ [SETTINGS] User signed out successfully")
                NotificationCenter.default.post(name: .userDidSignOut, object: nil)
            } catch {
                print("❌ [SETTINGS] Sign out error: \(error.localizedDescription)")
                errorMessage = "Failed to sign out"
                showError = true
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

