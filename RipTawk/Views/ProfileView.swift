//
//  ProfileView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI

struct ProfileView: View {
    @State private var username = "CreatorName"
    @State private var bio = "Creative video maker | Follow for daily content"
    @State private var followers = 10000
    @State private var following = 500
    @State private var likes = 50000
    @State private var videos: [FeedVideo] = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .center, spacing: 20) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                    
                    Text(username)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(bio)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    HStack(spacing: 30) {
                        VStack {
                            Text("\(followers)")
                                .font(.headline)
                            Text("Followers")
                                .font(.caption)
                        }
                        VStack {
                            Text("\(following)")
                                .font(.headline)
                            Text("Following")
                                .font(.caption)
                        }
                        VStack {
                            Text("\(likes)")
                                .font(.headline)
                            Text("Likes")
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        // Implement edit profile functionality
                    }) {
                        Text("Edit Profile")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    
                    Divider()
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                        ForEach(videos) { video in
                            VideoThumbnail(video: video)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarItems(trailing: Button(action: {
                // Implement settings functionality
            }) {
                Image(systemName: "gearshape.fill")
            })
            .navigationBarTitle("Profile", displayMode: .inline)
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

