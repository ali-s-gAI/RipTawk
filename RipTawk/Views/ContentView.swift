//
//  ContentView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import Appwrite

struct ContentView: View {
    @State private var isAuthenticated: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isSignUp = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    init(isAuthenticated: Bool) {
        _isAuthenticated = State(initialValue: isAuthenticated)
    }
    
    var body: some View {
        Group {
            if isAuthenticated {
                MainTabView()
                    .onAppear {
                        print(" [AUTH] Showing MainTabView - User is authenticated")
                    }
            } else {
                AuthenticationView(
                    isAuthenticated: $isAuthenticated,
                    email: $email,
                    password: $password,
                    name: $name,
                    isSignUp: $isSignUp,
                    errorMessage: $errorMessage,
                    showError: $showError,
                    onLogin: login,
                    onSignUp: signUp
                )
                .onAppear {
                    print(" [AUTH] Showing AuthenticationView - User is NOT authenticated")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
            handleSignOut()
        }
    }
    
    private func handleSignOut() {
        print(" [AUTH] Starting sign out process...")
        Task {
            do {
                try await AppwriteService.shared.signOut()
                print(" [AUTH] Sign out successful - clearing local state")
                await MainActor.run {
                    isAuthenticated = false
                    email = ""
                    password = ""
                    name = ""
                    isSignUp = false
                }
            } catch {
                print(" [AUTH] Sign out error: \(error.localizedDescription)")
                // Still clear local state
                await MainActor.run {
                    print(" [AUTH] Clearing local state despite sign out error")
                    isAuthenticated = false
                    email = ""
                    password = ""
                    name = ""
                    isSignUp = false
                }
            }
        }
    }
    
    private func login() {
        Task {
            do {
                print(" [LOGIN] Attempting to log in...")
                try await AppwriteService.shared.createSession(
                    email: email,
                    password: password
                )
                
                await MainActor.run {
                    isAuthenticated = true
                }
            } catch {
                print(" [LOGIN] Error: \(error.localizedDescription)")
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
                print(" [SIGNUP] Creating account...")
                let user = try await AppwriteService.shared.createAccount(
                    email: email,
                    password: password,
                    name: name
                )
                print(" [SIGNUP] Created account for: \(user.email)")
                
                // Now create a session
                try await AppwriteService.shared.createSession(
                    email: email,
                    password: password
                )
                
                await MainActor.run {
                    isAuthenticated = true
                }
            } catch {
                print(" [SIGNUP] Error: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

struct AuthenticationView: View {
    @Binding var isAuthenticated: Bool
    @Binding var email: String
    @Binding var password: String
    @Binding var name: String
    @Binding var isSignUp: Bool
    @Binding var errorMessage: String
    @Binding var showError: Bool
    let onLogin: () -> Void
    let onSignUp: () -> Void

    var body: some View {
        VStack {
            Text(isSignUp ? "Sign Up" : "Login")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color.brandPrimary)
                .padding(.bottom, 20)

            if showError {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(5)
            }

            VStack(spacing: 15) {
                if isSignUp {
                    TextField("Name", text: $name)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }

                TextField("Email", text: $email)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)

            Button(action: {
                if isSignUp {
                    onSignUp()
                } else {
                    onLogin()
                }
            }) {
                Text(isSignUp ? "Create Account" : "Login")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.brandPrimary)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Button(action: {
                isSignUp.toggle()
                errorMessage = "" // Clear error message on toggle
                showError = false
            }) {
                Text(isSignUp ? "Already have an account? Login" : "Don't have an account? Sign Up")
                    .foregroundColor(Color.brandPrimary)
            }
            .padding(.top, 10)
        }
        .padding()
        .background(Color.brandSurface)
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding()
    }
}
