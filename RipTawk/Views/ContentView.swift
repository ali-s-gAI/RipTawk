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
                try await AppwriteService.shared.initializeSession()
                await MainActor.run {
                    isAuthenticated = true
                }
            } catch {
                print("❌ [SESSION CHECK] No active session: \(error.localizedDescription)")
                await MainActor.run {
                    isAuthenticated = false
                }
            }
        }
    }
    
    private func login() {
        Task {
            do {
                print("🔄 [LOGIN] Attempting to log in...")
                try await AppwriteService.shared.createSession(
                    email: email,
                    password: password
                )
                
                await MainActor.run {
                    isAuthenticated = true
                }
            } catch {
                print("❌ [LOGIN] Error: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func signUp() {
        Task {
            do {
                print("📝 [SIGNUP] Creating account...")
                let user = try await AppwriteService.shared.createAccount(
                    email: email,
                    password: password,
                    name: name
                )
                print("✅ [SIGNUP] Created account for: \(user.email)")
                
                // Now create a session
                try await AppwriteService.shared.createSession(
                    email: email,
                    password: password
                )
                
                await MainActor.run {
                    isAuthenticated = true
                }
            } catch {
                print("❌ [SIGNUP] Error: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

