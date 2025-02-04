//
//  VideosView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI

struct VideosView: View {
    @State private var projects: [VideoProject] = []

    var body: some View {
        NavigationView {
            List(projects) { project in
                NavigationLink(destination: EditorView(videoURL: project.videoURL)) {
                    VideoProjectRow(project: project)
                }
            }
            .navigationTitle("My Projects")
            .toolbar {
                Button(action: {
                    // Add new project
                }) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct VideoProject: Identifiable {
    let id = UUID()
    let title: String
    let thumbnail: String
    let duration: TimeInterval
    let videoURL: URL
}

struct VideoProjectRow: View {
    let project: VideoProject
    
    var body: some View {
        HStack {
            Image(project.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 45)
                .cornerRadius(5)
            
            VStack(alignment: .leading) {
                Text(project.title)
                    .font(.headline)
                Text(formatDuration(project.duration))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? ""
    }
}

