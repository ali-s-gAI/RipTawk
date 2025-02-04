//
//  ContentView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import Appwrite

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isSignUp = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        Group {
            if isAuthenticated {
                MainTabView()
            } else {
                NavigationView {
                    ScrollView {
                        VStack(spacing: 20) {
                            Spacer(minLength: 30)
                            
                            Image(systemName: "video.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                            
                            Text("Welcome to RipTawk")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            VStack(spacing: 15) {
                                if isSignUp {
                                    TextField("Name", text: $name)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .autocapitalization(.words)
                                        .padding(.horizontal)
                                }
                                
                                TextField("Email", text: $email)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                    .padding(.horizontal)
                                
                                SecureField("Password", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.horizontal)
                            }
                            .padding(.vertical)
                            
                            VStack(spacing: 15) {
                                Button(action: {
                                    if isSignUp {
                                        signUp()
                                    } else {
                                        login()
                                    }
                                }) {
                                    Text(isSignUp ? "Sign Up" : "Log In")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .padding(.horizontal)
                                
                                Button(action: {
                                    isSignUp.toggle()
                                }) {
                                    Text(isSignUp ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Spacer(minLength: 30)
                        }
                        .padding()
                    }
                    .alert("Error", isPresented: $showError) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text(errorMessage)
                    }
                }
            }
        }
        .onAppear {
            checkCurrentSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
            isAuthenticated = false
            email = ""
            password = ""
            name = ""
        }
    }
    
    private func checkCurrentSession() {
        Task {
            do {
                if let account = try? await AppwriteService.shared.account.get() {
                    print("🔑 [SESSION CHECK] Found existing session for user: \(account.id)")
                    // Delete the existing session
                    print("🧹 [SESSION CHECK] Cleaning up existing session...")
                    try? await AppwriteService.shared.account.deleteSessions()
                    DispatchQueue.main.async {
                        isAuthenticated = false
                    }
                } else {
                    print("❌ [SESSION CHECK] No active session found")
                    DispatchQueue.main.async {
                        isAuthenticated = false
                    }
                }
            } catch {
                print("⚠️ [SESSION CHECK] Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isAuthenticated = false
                }
            }
        }
    }
    
    private func login() {
        Task {
            do {
                NSLog("🔄 [LOGIN] Attempting to log in...")
                
                if let sessions = try? await AppwriteService.shared.account.listSessions() {
                    NSLog("📋 [LOGIN] Active sessions found: \(sessions.total)")
                    for session in sessions.sessions {
                        NSLog("   - Session ID: \(session.id), Provider: \(session.provider)")
                    }
                }
                
                // Delete all sessions first
                print("🧹 [LOGIN] Cleaning up existing sessions...")
                try? await AppwriteService.shared.account.deleteSessions()
                
                print("📝 [LOGIN] Creating new session...")
                let session = try await AppwriteService.shared.account.createEmailPasswordSession(
                    email: email,
                    password: password
                )
                print("✅ [LOGIN] Success - created session for user: \(session.userId)")
                DispatchQueue.main.async {
                    isAuthenticated = true
                }
            } catch {
                print("❌ [LOGIN] Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func signUp() {
        Task {
            do {
                let user = try await AppwriteService.shared.account.create(
                    userId: ID.unique(),
                    email: email,
                    password: password,
                    name: name
                )
                print("User created successfully: \(user.id)")
                // Automatically log in after successful signup
                await login()
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

