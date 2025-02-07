//
//  FeedView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import AVKit

// Note: We now use VideoProject (from AppwriteService) as our video model.

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var currentIndex = 0
    
    var body: some View {
        GeometryReader { geometry in
            // The outer TabView is rotated -90° to achieve vertical paging
            TabView(selection: $currentIndex) {
                ForEach(viewModel.projects.indices, id: \.self) { index in
                    // Rotate each child back by 90°
                    FeedVideoView(project: viewModel.projects[index])
                        .rotationEffect(.degrees(90))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .tag(index)
                        .onAppear {
                            // Preload the next video when this video appears
                            if index == currentIndex {
                                preloadNextVideo(at: index + 1)
                            }
                        }
                }
            }
            // Swap the frame dimensions and rotate the TabView
            .frame(width: geometry.size.height, height: geometry.size.width)
            .rotationEffect(.degrees(-90))
            .ignoresSafeArea()
        }
        .onAppear {
            Task {
                await viewModel.loadFeedVideos()
            }
        }
    }
    
    private func preloadNextVideo(at index: Int) {
        guard index < viewModel.projects.count else { return }
        let nextProject = viewModel.projects[index]
        Task {
            // Preload the video URL to warm the cache.
            _ = try? await AppwriteService.shared.getVideoURL(fileId: nextProject.videoFileId)
        }
    }
}

@MainActor
class FeedViewModel: ObservableObject {
    @Published var projects: [VideoProject] = []
    
    func loadFeedVideos() async {
        do {
            // Load videos using the same ordering as in VideosView.
            let projects = try await AppwriteService.shared.listUserVideos()
            self.projects = projects
        } catch {
            print("❌ Error loading feed videos: \(error)")
        }
    }
}

struct FeedVideoView: View {
    let project: VideoProject
    @State private var videoURL: URL?
    @State private var isLiked = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if let url = videoURL {
                // Display the video using VideoPlayer
                VideoPlayer(player: AVPlayer(url: url))
                    .ignoresSafeArea()
            } else {
                // Loading state while fetching video URL
                Color.black
                ProgressView("Loading video...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            
            // Overlay the video description (placeholder texts)
            VStack(alignment: .leading, spacing: 8) {
                Text("Author: \(project.userId)") // Placeholder for author name
                    .font(.headline)
                Text(project.title)
                    .font(.subheadline)
                Text("Video description...") // Placeholder description
                    .font(.body)
            }
            .foregroundColor(.white)
            .padding()
            .background(
                // Adding a subtle black gradient for better text readability
                LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.6)]),
                               startPoint: .top,
                               endPoint: .bottom)
                    .ignoresSafeArea()
            )
            
            // Action buttons overlay placed at bottom right
            VStack(spacing: 20) {
                ActionButton(icon: isLiked ? "heart.fill" : "heart", text: "1200", action: {
                    isLiked.toggle()
                }, iconColor: isLiked ? .red : .white)
                
                ActionButton(icon: "message", text: "45", action: {
                    // Implement comment action here.
                })
                
                ActionButton(icon: "square.and.arrow.up", text: nil, action: {
                    // Implement share action here.
                })
            }
            .padding(.bottom, 60)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .onAppear {
            loadVideo()
        }
    }
    
    private func loadVideo() {
        Task {
            do {
                videoURL = try await AppwriteService.shared.getVideoURL(fileId: project.videoFileId)
            } catch {
                print("❌ Error loading video URL: \(error)")
            }
        }
    }
}

// A reusable view for the action buttons (like, comment, share)
struct ActionButton: View {
    let icon: String
    let text: String?
    let action: () -> Void
    var iconColor: Color = .white
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(iconColor)
                    .padding(10)
                    .background(Circle().fill(Color.black.opacity(0.6)))
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                if let text = text {
                    Text(text)
                        .foregroundColor(.white)
                        .font(.footnote)
                }
            }
        }
    }
}

struct CommentsView: View {
    let video: VideoProject  // Changed from FeedVideo to VideoProject
    @State private var newComment = ""
    
    var body: some View {
        VStack {
            Text("Comments")
                .font(.title)
                .padding()
            
            // Using a placeholder comment count (e.g. 3) since VideoProject doesn't have a comments property.
            List {
                ForEach(1...3, id: \.self) { index in
                    CommentRow(username: "User\(index)", comment: "This is comment #\(index)")
                }
            }
            
            HStack {
                TextField("Add a comment", text: $newComment)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Post") {
                    // Implement post comment functionality
                    newComment = ""
                }
            }
            .padding()
        }
    }
}

struct CommentRow: View {
    let username: String
    let comment: String

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading) {
                Text(username)
                    .font(.headline)
                Text(comment)
                    .font(.subheadline)
            }
        }
    }
}

