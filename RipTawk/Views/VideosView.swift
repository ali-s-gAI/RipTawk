//
//  VideosView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import PhotosUI
import AVKit
import VideoEditorSDK
import UIKit

struct VideosView: View {
    @State private var showMediaPicker = false
    @State private var videos: [URL] = []  // Simple array of video URLs
    
    var body: some View {
        NavigationView {
            List {
                ForEach(videos.indices, id: \.self) { index in
                    let url = videos[index]
                    NavigationLink(destination: VideoEditorSwiftUIView(video: Video(url: url))) {
                        HStack {
                            Image(systemName: "video.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("Video \(index + 1)")
                                .font(.headline)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("My Videos")
            .toolbar {
                Button(action: {
                    showMediaPicker = true
                }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showMediaPicker) {
                MediaPickerView(isPresented: $showMediaPicker) { url in
                    videos.append(url)
                }
            }
        }
    }
}

struct MediaPickerView: View {
    @Binding var isPresented: Bool
    let onSelect: (URL) -> Void
    @State private var selectedItems: [PhotosPickerItem] = []
    
    var body: some View {
        NavigationView {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 1,
                matching: .videos
            ) {
                Text("Select Video")
                    .font(.headline)
            }
            .onChange(of: selectedItems) { _, items in
                guard let item = items.first else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                        
                        let fileName = "video_\(UUID().uuidString).mov"
                        let fileURL = documentsDirectory.appendingPathComponent(fileName)
                        
                        try data.write(to: fileURL)
                        await MainActor.run {
                            onSelect(fileURL)
                            isPresented = false
                        }
                    }
                }
            }
            .navigationTitle("Add Video")
            .toolbar {
                Button("Cancel") {
                    isPresented = false
                }
            }
        }
    }
}

@MainActor
class ProjectManager: ObservableObject {
    @Published var projects: [VideoProject] = []
    private let userDefaults = UserDefaults.standard
    private let projectsKey = "savedProjects"
    
    func loadProjects() {
        if let data = userDefaults.data(forKey: projectsKey),
           let decoded = try? JSONDecoder().decode([VideoProject].self, from: data) {
            projects = decoded
        }
    }
    
    func saveProjects() {
        if let encoded = try? JSONEncoder().encode(projects) {
            userDefaults.set(encoded, forKey: projectsKey)
        }
    }
    
    func createProject(with videoURL: URL) async {
        let asset = AVURLAsset(url: videoURL)
        let duration = (try? await asset.load(.duration).seconds) ?? 0
        
        let project = VideoProject(
            title: "Project \(projects.count + 1)",
            videoURL: videoURL,
            duration: duration,
            createdAt: Date()
        )
        
        projects.append(project)
        saveProjects()
    }
}

struct VideoProject: Codable {
    var uuid: UUID
    let title: String
    let videoURL: URL
    let duration: TimeInterval
    let createdAt: Date
    
    init(title: String, videoURL: URL, duration: TimeInterval, createdAt: Date) {
        self.id = UUID()
        self.title = title
        self.videoURL = videoURL
        self.duration = duration
        self.createdAt = createdAt
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, videoURL, duration, createdAt
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(videoURL, forKey: .videoURL)
        try container.encode(duration, forKey: .duration)
        try container.encode(createdAt, forKey: .createdAt)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        videoURL = try container.decode(URL.self, forKey: .videoURL)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

struct VideoProjectRow: View {
    let project: VideoProject
    @State private var thumbnail: UIImage?
    
    var body: some View {
        HStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 45)
                    .cornerRadius(5)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 45)
                    .cornerRadius(5)
            }
            
            VStack(alignment: .leading) {
                Text(project.title)
                    .font(.headline)
                Text(formatDuration(project.duration))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? ""
    }
    
    func generateThumbnail() {
        let asset = AVURLAsset(url: project.videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        Task {
            do {
                let cgImage = try await imageGenerator.image(at: .zero).image
                await MainActor.run {
                    thumbnail = UIImage(cgImage: cgImage)
                }
            } catch {
                print("Error generating thumbnail: \(error)")
            }
        }
    }
}

