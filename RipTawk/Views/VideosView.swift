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
    @StateObject private var projectManager = ProjectManager()
    @State private var showMediaPicker = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(projectManager.projects) { project in
                    NavigationLink {
                        if let videoURL = try? await AppwriteService.shared.getVideoURL(fileId: project.videoFileId) {
                            VideoEditorSwiftUIView(video: Video(url: videoURL))
                        }
                    } label: {
                        VideoProjectRow(project: project)
                    }
                }
            }
            .navigationTitle("My Projects")
            .toolbar {
                Button(action: {
                    showMediaPicker = true
                }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showMediaPicker) {
                MediaPickerView(isPresented: $showMediaPicker) { url in
                    Task {
                        await projectManager.createProject(with: url)
                    }
                }
            }
            .task {
                await projectManager.loadProjects()
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
    private let appwriteService = AppwriteService.shared
    
    func loadProjects() async {
        do {
            projects = try await appwriteService.listUserVideos()
            print("📥 Loaded \(projects.count) projects from Appwrite")
        } catch {
            print("❌ Error loading projects: \(error)")
        }
    }
    
    func createProject(with videoURL: URL) async {
        do {
            let asset = AVURLAsset(url: videoURL)
            let duration = asset.duration.seconds
            
            let project = try await appwriteService.uploadVideo(
                url: videoURL,
                title: "Project \(projects.count + 1)",
                duration: duration
            )
            
            projects.append(project)
            print("✅ Created new project with ID: \(project.id)")
        } catch {
            print("❌ Error creating project: \(error)")
        }
    }
}

struct VideoProjectRow: View {
    let project: VideoProject
    @State private var thumbnail: UIImage?
    @State private var videoURL: URL?
    
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
        .task {
            do {
                videoURL = try await AppwriteService.shared.getVideoURL(fileId: project.videoFileId)
                generateThumbnail()
            } catch {
                print("❌ Error loading video URL: \(error)")
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
    
    func generateThumbnail() {
        guard let videoURL = videoURL else { return }
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        Task {
            do {
                let cgImage = try await imageGenerator.image(at: .zero).image
                await MainActor.run {
                    thumbnail = UIImage(cgImage: cgImage)
                }
            } catch {
                print("❌ Error generating thumbnail: \(error)")
            }
        }
    }
}

