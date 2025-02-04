//
//  FeedView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import AVKit

struct FeedView: View {
    @State private var currentIndex = 0
    @State private var videos: [FeedVideo] = [
        FeedVideo(id: UUID(), videoURL: URL(string: "https://example.com/video1.mp4")!, creator: "Creator1", description: "Awesome video #1", likes: 1000, comments: 50),
        FeedVideo(id: UUID(), videoURL: URL(string: "https://example.com/video2.mp4")!, creator: "Creator2", description: "Check out this cool effect! #creatorTok", likes: 2500, comments: 120),
        // Add more sample videos here
    ]

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $currentIndex) {
                ForEach(videos.indices, id: \.self) { index in
                    FeedVideoView(video: videos[index])
                        .rotationEffect(.degrees(-90))
                        .frame(width: geometry.size.height, height: geometry.size.width)
                        .tag(index)
                }
            }
            .frame(width: geometry.size.height, height: geometry.size.width)
            .rotationEffect(.degrees(90), anchor: .topLeading)
            .offset(x: geometry.size.width)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
}

struct FeedVideo: Identifiable {
    let id: UUID
    let videoURL: URL
    let creator: String
    let description: String
    let likes: Int
    let comments: Int
}

struct FeedVideoView: View {
    let video: FeedVideo
    @State private var isLiked = false
    @State private var showComments = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VideoPlayer(player: AVPlayer(url: video.videoURL))
                .edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    
                    Text(video.creator)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Text(video.description)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding()
            
            VStack(spacing: 20) {
                Button(action: {
                    isLiked.toggle()
                }) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundColor(isLiked ? .red : .white)
                        .font(.system(size: 30))
                }
                
                Text("\(video.likes)")
                    .foregroundColor(.white)
                
                Button(action: {
                    showComments.toggle()
                }) {
                    Image(systemName: "message")
                        .foregroundColor(.white)
                        .font(.system(size: 30))
                }
                
                Text("\(video.comments)")
                    .foregroundColor(.white)
                
                Button(action: {
                    // Implement share functionality
                }) {
                    Image(systemName: "arrowshape.turn.up.right")
                        .foregroundColor(.white)
                        .font(.system(size: 30))
                }
            }
            .padding(.trailing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .sheet(isPresented: $showComments) {
            CommentsView(video: video)
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

