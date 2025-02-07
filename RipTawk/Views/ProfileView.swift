//
//  ProfileView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import Appwrite
import AVKit

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
                    
                    // Example usage of VideoThumbnail for user's videos
                    VideoThumbnail(video: sampleVideoProject)
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

// Replace the use of FeedVideo with VideoProject. Here, we generate a thumbnail asynchronously.
struct VideoThumbnail: View {
    let video: VideoProject  // Changed from FeedVideo to VideoProject
    @State private var thumbnail: UIImage?
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                Color.gray
            }
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "heart.fill")
                    Text("1200") // Placeholder like count
                }
                .font(.caption)
                .padding(4)
                .background(Color.black.opacity(0.6))
                .foregroundColor(.white)
                .cornerRadius(4)
                Spacer()
            }
            .padding(8)
        }
        .frame(height: 200)
        .cornerRadius(8)
        .onAppear {
            Task {
                if thumbnail == nil {
                    thumbnail = await generateThumbnail()
                }
            }
        }
    }
    
    private func generateThumbnail() async -> UIImage? {
        do {
            let videoURL = try await AppwriteService.shared.getVideoURL(fileId: video.videoFileId)
            let asset = AVAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 1, preferredTimescale: 600)
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Thumbnail generation error: \(error)")
            return nil
        }
    }
}

// A temporary sample VideoProject for preview/testing purposes.
let sampleVideoProject = VideoProject(
    id: "sampleID",
    title: "Sample Video",
    videoFileId: "sampleFileId",
    duration: 120,
    createdAt: Date(),
    userId: "SampleUser"
)

struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .font(.largeTitle)
    }
}

