import SwiftUI
import AVKit

struct VideoProjectEditorView: View {
    let project: VideoProject
    @State private var localVideoURL: URL?
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if let localVideoURL = localVideoURL {
                // Launch our video editor with the local URL & existing project.
                VideoEditorSwiftUIView(video: localVideoURL, existingProject: project)
            } else if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            } else {
                ProgressView("Loading video...")
            }
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                let remoteURL = try await AppwriteService.shared.getVideoURL(fileId: project.videoFileId)
                localVideoURL = try await downloadFile(from: remoteURL)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .onDisappear {
            // Release the video so that playback stops.
            localVideoURL = nil
        }
    }
    
    /// Downloads the file from the given remote URL to a temporary local URL with a proper file extension.
    func downloadFile(from remoteURL: URL) async throws -> URL {
        let (tempURL, response) = try await URLSession.shared.download(from: remoteURL)
        let ext: String
        if let httpResponse = response as? HTTPURLResponse,
           let mimeType = httpResponse.mimeType {
            if mimeType == "video/mp4" {
                ext = "mp4"
            } else if mimeType == "video/quicktime" {
                ext = "mov"
            } else {
                ext = "mov"  // default fallback
            }
        } else {
            ext = "mov"
        }
        let newURL = tempURL.deletingPathExtension().appendingPathExtension(ext)
        try FileManager.default.moveItem(at: tempURL, to: newURL)
        return newURL
    }
} 