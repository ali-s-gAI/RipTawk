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
                    VStack(spacing: 20) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Welcome to RipTawk")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
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
                    .padding()
                    .alert("Error", isPresented: $showError) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text(errorMessage)
                    }
                }
            }
        }
    }
    
    private func login() {
        Task {
            do {
                let session = try await AppwriteService.shared.account.createEmailPasswordSession(
                    email: email,
                    password: password
                )
                print("Logged in successfully: \(session.userId)")
                DispatchQueue.main.async {
                    isAuthenticated = true
                }
            } catch {
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

