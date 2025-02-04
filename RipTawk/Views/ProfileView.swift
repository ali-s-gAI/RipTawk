//
//  ProfileView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import Appwrite

struct ProfileView: View {
    @State private var showSettings = false
    @State private var username = ""
    @State private var followers = 100
    @State private var following = 50
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                    
                    Text(username)
                        .font(.title)
                    
                    HStack(spacing: 40) {
                        VStack {
                            Text("\(followers)")
                                .font(.headline)
                            Text("Followers")
                                .foregroundColor(.gray)
                        }
                        
                        VStack {
                            Text("\(following)")
                                .font(.headline)
                            Text("Following")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button(action: {
                        // Edit profile action
                    }) {
                        Text("Edit Profile")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .onAppear {
                Task {
                    if let currentUser = try? await AppwriteService.shared.account.get() {
                        username = currentUser.name
                    }
                }
            }
            .toolbar {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

struct VideoThumbnail: View {
    let video: FeedVideo
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: video.videoURL) { image in
                image.resizable()
            } placeholder: {
                Color.gray
            }
            .aspectRatio(9/16, contentMode: .fill)
            .frame(height: 200)
            .cornerRadius(8)
            
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "heart.fill")
                    Text("\(video.likes)")
                }
                .font(.caption)
                .padding(4)
                .background(Color.black.opacity(0.6))
                .foregroundColor(.white)
                .cornerRadius(4)
            }
            .padding(8)
        }
    }
}

