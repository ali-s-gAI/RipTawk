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
        print("🎬 [TRANSCRIBE] Starting transcription pipeline for project: \(project.id)")
        print("📊 [TRANSCRIBE] Initial project state:")
        print("  - Title: \(project.title)")
        print("  - Video File ID: \(project.videoFileID)")
        print("  - Is Transcribed: \(project.isTranscribed)")
        
        Task {
            do {
                // STEP 1: Get video URL and extract audio
                print("\n📍 [STEP 1] Getting video URL and extracting audio")
                let videoURL = try await AppwriteService.shared.getVideoURL(fileId: project.videoFileID)
                print("  - Video URL: \(videoURL.absoluteString)")
                
                let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("m4a")
                print("  - Temp audio output path: \(outputURL.path)")
                
                let audioURL = try await extractAudio(from: videoURL, outputURL: outputURL)
                let audioData = try Data(contentsOf: audioURL)
                print("  - Extracted audio size: \(Float(audioData.count) / 1024 / 1024) MB")
                
                // STEP 2: Send to Whisper API
                print("\n📍 [STEP 2] Sending audio to Whisper API")
                let requestBody: [String: Any] = [
                    "audio": audioData.base64EncodedString(),
                    "format": "m4a",
                    "documentId": project.id
                ]
                print("  - Request payload size: \(Float(requestBody.jsonString().count) / 1024 / 1024) MB")
                
                // STEP 3: Get transcription
                print("\n📍 [STEP 3] Getting transcription from Whisper")
                let response = try await AppwriteService.shared.functions.createExecution(
                    functionId: AppwriteService.shared.transcriptionFunctionId,
                    body: requestBody.jsonString()
                )
                print("  - Response status: \(response.status)")
                print("  - Response body length: \(response.responseBody.count) chars")
                print("  - Response preview: \(String(response.responseBody.prefix(200)))")
                
                // STEP 4: Update project with transcription
                print("\n📍 [STEP 4] Parsing response and updating project")
                if response.responseBody.isEmpty {
                    print("⚠️ Empty response body - checking for direct database update")
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    
                    let updatedProjects = try await AppwriteService.shared.listUserVideos()
                    if let updatedProject = updatedProjects.first(where: { $0.id == project.id }) {
                        print("  - Found updated project:")
                        print("    - Transcript exists: \(updatedProject.transcript != nil)")
                        print("    - Is Transcribed: \(updatedProject.isTranscribed)")
                        print("    - Has Description: \(updatedProject.description != nil)")
                        print("    - Tags count: \(updatedProject.tags?.count ?? 0)")
                    } else {
                        print("❌ Could not find updated project in database")
                    }
                } else {
                    print("  - Attempting to parse response JSON")
                    if let data = response.responseBody.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("  - Parsed JSON successfully")
                        print("  - Available keys: \(json.keys.joined(separator: ", "))")
                        
                        let transcript = json["response"] as? String
                        let description = json["description"] as? String
                        let tags = json["tags"] as? [String]
                        
                        print("  - Found transcript: \(transcript?.prefix(100) ?? "nil")")
                        print("  - Found description: \(description ?? "nil")")
                        print("  - Found tags: \(tags ?? [])")
                        
                        // Update project
                        try await AppwriteService.shared.updateProjectWithTranscription(
                            projectId: project.id,
                            transcript: transcript ?? "",
                            description: description,
                            tags: tags
                        )
                        print("✅ Project updated successfully")
                    } else {
                        print("❌ Failed to parse response as JSON")
                        print("Raw response: \(response.responseBody)")
                    }
                }
                
                // Clean up
                print("\n📍 [CLEANUP] Removing temporary audio file")
                try? FileManager.default.removeItem(at: audioURL)
                
                // Final verification
                print("\n📍 [VERIFICATION] Checking final project state")
                let finalProjects = try await AppwriteService.shared.listUserVideos()
                if let finalProject = finalProjects.first(where: { $0.id == project.id }) {
                    print("Final project state:")
                    print("  - Is Transcribed: \(finalProject.isTranscribed)")
                    print("  - Has Transcript: \(finalProject.transcript != nil)")
                    print("  - Has Description: \(finalProject.description != nil)")
                    print("  - Tags Count: \(finalProject.tags?.count ?? 0)")
                }
                
            } catch {
                print("\n❌ [ERROR] Pipeline failed:")
                print("  - Error: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("  - Domain: \(nsError.domain)")
                    print("  - Code: \(nsError.code)")
                    print("  - User Info: \(nsError.userInfo)")
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
            throw NSError(domain: "TranscriptionService", code: 500, 
                         userInfo: [NSLocalizedDescriptionKey: "Function failed with status: \(response.status)"])
        }
        
        // Handle empty response body
        if response.responseBody.isEmpty {
            print("⚠️ [API] Response body is empty, waiting for project update...")
            // Wait briefly for the database to update
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Fetch the updated project
            let updatedProjects = try await AppwriteService.shared.listUserVideos()
            if let updatedProject = updatedProjects.first(where: { $0.id == project.id }),
               let transcript = updatedProject.transcript {
                return transcript
            } else {
                throw NSError(domain: "TranscriptionService", code: 500,
                             userInfo: [NSLocalizedDescriptionKey: "Could not retrieve transcription after completion"])
            }
        }
        
        // Try to parse the response as JSON
        if let data = response.responseBody.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("🎙 [API] Parsed response JSON: \(json)")
            
            // Extract fields
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
        
        throw NSError(domain: "TranscriptionService", code: 500,
                     userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
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
    let videoFileID: String
    let videoURL: URL?
    let duration: Double
    let createdAt: Date
    let userId: String
    let transcript: String?
    let isTranscribed: Bool
    let description: String?
    let tags: [String]?
    
    init(id: String, title: String, videoFileID: String, videoURL: URL? = nil, duration: Double, createdAt: Date, userId: String, transcript: String? = nil, isTranscribed: Bool = false, description: String? = nil, tags: [String]? = nil) {
        self.id = id
        self.title = title
        self.videoFileID = videoFileID
        self.videoURL = videoURL
        self.duration = duration
        self.createdAt = createdAt
        self.userId = userId
        self.transcript = transcript
        self.isTranscribed = isTranscribed
        self.description = description
        self.tags = tags
    }
}
