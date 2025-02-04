//
//  FeedView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import AVKit

struct FeedVideo: Identifiable {
    let id = UUID()
    let title: String
    let author: String
    let likes: Int
    let comments: Int
    let videoURL: URL
}

struct FeedView: View {
    @State private var currentIndex = 0
    @State private var videos: [FeedVideo] = [
        FeedVideo(title: "Cool Dance", author: "User1", likes: 1200, comments: 45, videoURL: URL(string: "https://example.com")!),
        FeedVideo(title: "Funny Moment", author: "User2", likes: 800, comments: 30, videoURL: URL(string: "https://example.com")!),
    ]
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $currentIndex) {
                ForEach(videos.indices, id: \.self) { index in
                    FeedVideoView(video: videos[index])
                        .rotationEffect(.degrees(0)) // Prevents auto-rotation
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
    }
}

struct FeedVideoView: View {
    let video: FeedVideo
    @State private var isLiked = false
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black // Placeholder for video
                .overlay(
                    Text("Video Player Here")
                        .foregroundColor(.white)
                )
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(video.author)
                        .font(.headline)
                    Text(video.title)
                        .font(.subheadline)
                }
                .foregroundColor(.white)
                .padding()
                
                Spacer()
                
                VStack(spacing: 20) {
                    Button(action: { isLiked.toggle() }) {
                        VStack {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundColor(isLiked ? .red : .white)
                                .font(.system(size: 30))
                            Text("\(video.likes)")
                                .foregroundColor(.white)
                        }
                    }
                    
                    VStack {
                        Image(systemName: "message")
                            .font(.system(size: 30))
                        Text("\(video.comments)")
                    }
                    .foregroundColor(.white)
                    
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 60)
                .padding(.trailing)
            }
        }
    }
}

struct CommentsView: View {
    let video: FeedVideo
    @State private var newComment = ""

    var body: some View {
        VStack {
            Text("Comments")
                .font(.title)
                .padding()
            
            List {
                ForEach(1...video.comments, id: \.self) { index in
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

