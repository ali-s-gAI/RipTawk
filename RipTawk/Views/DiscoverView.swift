//
//  DiscoverView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import AVFoundation

struct DiscoverView: View {
    @State private var projects: [Project] = []
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView()
                } else {
                    List(projects) { project in
                        Button(action: {
                            transcribeProject(project)
                        }) {
                            HStack {
                                Text(project.title)
                                    .foregroundColor(.primary)
                                Spacer()
                                if !project.isTranscribed {
                                    Image(systemName: "wand.and.stars")
                    .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                    
                    if projects.isEmpty {
                        Text("No projects found")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("AI Hub")
            .alert("Transcription Result", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .task {
                await fetchProjects()
            }
        }
    }
    
    private func fetchProjects() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch projects from Appwrite
            projects = try await AppwriteService.shared.getProjects()
        } catch {
            print("Failed to fetch projects:", error)
            alertMessage = "Failed to load projects: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func transcribeProject(_ project: Project) {
        print("🎬 [TRANSCRIBE] Starting transcription for project: \(project.id)")
        
        guard let videoURL = project.videoURL else {
            print("❌ [TRANSCRIBE] No video URL found for project: \(project.id)")
            alertMessage = "Video URL not found"
            showAlert = true
            return
        }
        
        print("📍 [TRANSCRIBE] Video URL: \(videoURL.absoluteString)")
        
        Task {
            do {
                // Create temporary output URL for audio
                let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("m4a")
                print("📝 [TRANSCRIBE] Created temp output URL: \(outputURL.path)")
                
                // Convert video to audio
                print("🎵 [TRANSCRIBE] Starting audio extraction...")
                let audioURL = try await extractAudio(from: videoURL, outputURL: outputURL)
                print("✅ [TRANSCRIBE] Audio extraction complete: \(audioURL.path)")
                
                // Test audio playback
                print("🔊 [TRANSCRIBE] Testing audio playback...")
                let player = try AVAudioPlayer(contentsOf: audioURL)
                print("🔊 [TRANSCRIBE] Audio duration: \(player.duration) seconds")
                print("🔊 [TRANSCRIBE] Audio format: \(player.format)")
                print("🔊 [TRANSCRIBE] Number of channels: \(player.numberOfChannels)")
                
                // Get audio file size for debugging
                let audioFileSize = try FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int64 ?? 0
                print("📊 [TRANSCRIBE] Audio file size: \(Float(audioFileSize) / 1024 / 1024) MB")
                
                // Check if audio file is valid
                if player.duration < 0.1 || audioFileSize < 1000 {
                    throw NSError(domain: "AudioExtraction", code: 3, 
                                userInfo: [NSLocalizedDescriptionKey: "Audio file appears to be empty or invalid"])
                }
                
                print("📤 [TRANSCRIBE] Reading audio data...")
                let audioData = try Data(contentsOf: audioURL)
                print("✅ [TRANSCRIBE] Audio data loaded: \(audioData.count) bytes")
                
                // Call transcription service
                print("🎙 [TRANSCRIBE] Calling transcription service...")
                let transcript = try await callTranscriptionService(audioData: audioData, project: project)
                print("✅ [TRANSCRIBE] Transcription received: \(transcript.prefix(100))...")
                
                print("🧹 [TRANSCRIBE] Cleaning up temp file...")
                try? FileManager.default.removeItem(at: audioURL)
                print("✅ [TRANSCRIBE] Temp file cleaned up")
                
                // Parse the response to get description and tags
                if let data = transcript.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let transcriptText = json["response"] as? String ?? ""
                    let description = json["description"] as? String
                    let tags = json["tickers"] as? [String]
                    
                    // Update project in Appwrite with all fields
                    print("💾 [TRANSCRIBE] Updating project with transcription data...")
                    try await AppwriteService.shared.updateProjectWithTranscription(
                        projectId: project.id,
                        transcript: transcriptText,
                        description: description,
                        tags: tags
                    )
                    print("✅ [TRANSCRIBE] Project updated with transcription data")
                    
                    // Update UI with description if available
                    if let description = description {
                        alertMessage = "Transcription complete!\nDescription: \(description)"
                    } else {
                        alertMessage = "Transcription complete!"
                    }
                } else {
                    // Fallback to just updating transcript if JSON parsing fails
                    print("⚠️ [TRANSCRIBE] Could not parse JSON response, updating transcript only")
                    try await AppwriteService.shared.updateProjectWithTranscription(
                        projectId: project.id,
                        transcript: transcript,
                        description: nil,
                        tags: nil
                    )
                    alertMessage = "Transcript received!\n\(transcript.prefix(100))..."
                }
                
                showAlert = true
                
                // Refresh projects list
                print("🔄 [TRANSCRIBE] Refreshing projects list...")
                await fetchProjects()
                print("✅ [TRANSCRIBE] Process complete for project: \(project.id)")
                
            } catch {
                print("❌ [TRANSCRIBE] Error: \(error.localizedDescription)")
                if let urlError = error as? URLError {
                    print("🔍 [TRANSCRIBE] URL Error details:")
                    print("  - Code: \(urlError.code.rawValue)")
                    print("  - Description: \(urlError.localizedDescription)")
                    print("  - Failed URL: \(urlError.failureURLString ?? "none")")
                }
                alertMessage = "Error: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func extractAudio(from videoURL: URL, outputURL: URL) async throws -> URL {
        print("🎵 [EXTRACT] Creating asset from URL: \(videoURL.absoluteString)")
        let asset = AVAsset(url: videoURL)
        let composition = AVMutableComposition()
        
        print("🎵 [EXTRACT] Loading audio tracks...")
        guard let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            print("❌ [EXTRACT] No audio track found in video")
            throw NSError(domain: "AudioExtraction", code: 0, userInfo: [NSLocalizedDescriptionKey: "No audio track found"])
        }
        print("✅ [EXTRACT] Audio track found")
        
        print("🎵 [EXTRACT] Creating composition track...")
        guard let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            print("❌ [EXTRACT] Failed to create composition track")
            throw NSError(domain: "AudioExtraction", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create composition track"])
        }
        
        print("🎵 [EXTRACT] Loading track time range...")
        let timeRange = try await sourceAudioTrack.load(.timeRange)
        print("✅ [EXTRACT] Time range loaded: \(timeRange.duration.seconds) seconds")
        
        print("🎵 [EXTRACT] Inserting audio into composition...")
        try compositionAudioTrack.insertTimeRange(
            timeRange,
            of: sourceAudioTrack,
            at: CMTime.zero
        )
        print("✅ [EXTRACT] Audio inserted into composition")
        
        print("🎵 [EXTRACT] Creating export session...")
        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            print("❌ [EXTRACT] Failed to create export session")
            throw NSError(domain: "AudioExtraction", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create exporter"])
        }
        
        exporter.outputFileType = .m4a
        exporter.outputURL = outputURL
        
        print("🎵 [EXTRACT] Starting export...")
        await exporter.export()
        
        if let error = exporter.error {
            print("❌ [EXTRACT] Export failed: \(error.localizedDescription)")
            throw error
        }
        
        // Verify the exported file exists and has content
        guard FileManager.default.fileExists(atPath: outputURL.path),
              let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
              let fileSize = attributes[.size] as? Int64,
              fileSize > 0 else {
            throw NSError(domain: "AudioExtraction", code: 4, 
                         userInfo: [NSLocalizedDescriptionKey: "Exported audio file is empty or missing"])
        }
        
        print("✅ [EXTRACT] Export complete: \(outputURL.path)")
        return outputURL
    }
    
    private func callTranscriptionService(audioData: Data, project: Project) async throws -> String {
        print("🎙 [API] Preparing transcription request...")
        
        // Create the request body with base64 encoded audio
        let base64Audio = audioData.base64EncodedString()
        print("🎙 [API] Base64 audio length: \(base64Audio.count)")
        print("🎙 [API] Base64 audio prefix: \(String(base64Audio.prefix(100)))...")
        
        let requestBody: [String: Any] = [
            "audio": base64Audio,
            "format": "m4a",
            "documentId": project.id
        ]
        
        let jsonString = requestBody.jsonString()
        print("🎙 [API] Request body size: \(jsonString.count) bytes")
        
        // Call the function through AppwriteService
        let response = try await AppwriteService.shared.functions.createExecution(
            functionId: AppwriteService.shared.transcriptionFunctionId,
            body: jsonString
        )
        
        print("🎙 [API] Response received: \(response)")
        print("🎙 [API] Response body: '\(response.responseBody)'")
        print("🎙 [API] Response status: \(response.status)")
        
        if response.status != "completed" {
            // If status is not completed, try to parse error from response body
            if let data = response.responseBody.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? String {
                throw NSError(domain: "TranscriptionService", code: 500, 
                            userInfo: [NSLocalizedDescriptionKey: "Function error: \(error)"])
            }
            throw NSError(domain: "TranscriptionService", code: 500, 
                         userInfo: [NSLocalizedDescriptionKey: "Function failed with status: \(response.status)"])
        }
        
        // At this point, status is "completed"
        // Try to parse the response as JSON first
        if !response.responseBody.isEmpty,
           let data = response.responseBody.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("🎙 [API] Parsed response JSON: \(json)")
            
            // Extract all relevant fields
            let transcript = json["response"] as? String
            let description = json["description"] as? String
            let tags = json["tags"] as? [String]
            
            // Update the project with all fields
            try await AppwriteService.shared.updateProjectWithTranscription(
                projectId: project.id,
                transcript: transcript ?? "",
                description: description,
                tags: tags
            )
            
            return transcript ?? ""
        }
        
        // If response body is empty or invalid JSON, wait briefly and fetch the updated project
        print("🔄 [API] Function completed, fetching updated project data...")
        // Wait a moment for the database to update
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Fetch the updated project directly
        let updatedProjects = try await AppwriteService.shared.listUserVideos()
        if let updatedProject = updatedProjects.first(where: { $0.id == project.id }) {
            if let transcript = updatedProject.transcript {
                print("✅ [API] Retrieved updated project with transcript")
                // No need to update the project again since we got it from the database
                return transcript
            }
            throw NSError(domain: "TranscriptionService", code: 500,
                         userInfo: [NSLocalizedDescriptionKey: "Project found but transcript is missing"])
        }
        
        throw NSError(domain: "TranscriptionService", code: 500,
                     userInfo: [NSLocalizedDescriptionKey: "Could not retrieve transcription data"])
    }
}

// Helper extension to convert dictionary to JSON string
extension Dictionary {
    func jsonString() -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Search", text: $text)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct TrendingVideo: Identifiable {
    let id = UUID()
    let title: String
    let creator: String
    let thumbnail: String
    let views: Int
}

struct TrendingVideoCell: View {
    let video: TrendingVideo
    
    var body: some View {
        VStack {
            Image(video.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 120)
                .cornerRadius(10)
            
            Text(video.title)
                .font(.headline)
                .lineLimit(2)
            
            Text(video.creator)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("\(video.views) views")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    var onDocumentPicked: (URL) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onDocumentPicked(url)
        }
    }
}

// This struct should match your Appwrite document structure
struct Project: Identifiable {
    let id: String
    let title: String
    let videoURL: URL?
    let isTranscribed: Bool
    
    init(id: String, title: String, videoURL: URL?, isTranscribed: Bool = false) {
        self.id = id
        self.title = title
        self.videoURL = videoURL
        self.isTranscribed = isTranscribed
    }
}
