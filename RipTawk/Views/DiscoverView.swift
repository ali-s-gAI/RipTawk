//
//  DiscoverView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import AVFoundation

// Progress step model
struct ProcessingStep: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    var isCompleted: Bool = false
    var isLoading: Bool = false
}

struct DiscoverView: View {
    @State private var projects: [Project] = []
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var processingSteps: [ProcessingStep] = []
    @State private var currentStepIndex: Int = 0
    @State private var showProcessingSheet = false
    
    private let steps = [
        ProcessingStep(title: "Getting video URL", icon: "link.circle"),
        ProcessingStep(title: "Extracting audio", icon: "waveform"),
        ProcessingStep(title: "Transcribing with AI", icon: "text.bubble"),
        ProcessingStep(title: "Analyzing content", icon: "brain"),
        ProcessingStep(title: "Saving results", icon: "checkmark.circle")
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [.black, Color.brandBackground]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if isLoading {
                        // Loading state
                        VStack(spacing: 24) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.brandPrimary)
                            Text("Loading your projects...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    } else {
                        // Project list
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(projects) { project in
                                    ProjectCard(
                                        project: project,
                                        onTranscribe: {
                                            startTranscription(project)
                                        }
                                    )
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical)
                        }
                        
                        if projects.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 50))
                                    .foregroundColor(.brandPrimary)
                                Text("No projects found")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                Text("Create a new project to get started")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("AI Hub")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Transcription Result", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showProcessingSheet) {
                ProcessingView(steps: $processingSteps)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground {
                        Color.black.opacity(0.9)
                            .ignoresSafeArea()
                    }
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
            projects = try await AppwriteService.shared.getProjects()
        } catch {
            print("Failed to fetch projects:", error)
            alertMessage = "Failed to load projects: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func startTranscription(_ project: Project) {
        // Reset and show processing sheet
        processingSteps = steps
        currentStepIndex = 0
        showProcessingSheet = true
        
        // Start transcription process
        transcribeProject(project)
    }
    
    private func updateStep(_ index: Int, isCompleted: Bool = false, isLoading: Bool = false) {
        guard index < processingSteps.count else { return }
        processingSteps[index].isCompleted = isCompleted
        processingSteps[index].isLoading = isLoading
        if isCompleted && index + 1 < processingSteps.count {
            processingSteps[index + 1].isLoading = true
        }
    }
    
    private func transcribeProject(_ project: Project) {
        print("🎬 [TRANSCRIBE] Starting transcription pipeline for project: \(project.id)")
        
        Task {
            do {
                // STEP 1: Get video URL and extract audio
                updateStep(0, isLoading: true)
                let videoURL = try await AppwriteService.shared.getVideoURL(fileId: project.videoFileID)
                updateStep(0, isCompleted: true)
                
                // Setup audio extraction
                updateStep(1, isLoading: true)
                let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("m4a")
                
                let audioURL = try await extractAudio(from: videoURL, outputURL: outputURL)
                let audioData = try Data(contentsOf: audioURL)
                updateStep(1, isCompleted: true)
                
                // STEP 2: Send to Whisper API
                updateStep(2, isLoading: true)
                let requestBody: [String: Any] = [
                    "audio": audioData.base64EncodedString(),
                    "format": "m4a",
                    "documentId": project.id
                ]
                
                // STEP 3: Get transcription
                let response = try await AppwriteService.shared.functions.createExecution(
                    functionId: AppwriteService.shared.transcriptionFunctionId,
                    body: requestBody.jsonString()
                )
                updateStep(2, isCompleted: true)
                
                // STEP 4: Process response
                updateStep(3, isLoading: true)
                if response.responseBody.isEmpty {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    let updatedProjects = try await AppwriteService.shared.listUserVideos()
                    if let updatedProject = updatedProjects.first(where: { $0.id == project.id }) {
                        print("✅ Project updated successfully")
                    }
                } else {
                    if let data = response.responseBody.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let transcript = json["response"] as? String
                        let description = json["description"] as? String
                        let tags = json["tags"] as? [String]
                        
                        try await AppwriteService.shared.updateProjectWithTranscription(
                            projectId: project.id,
                            transcript: transcript ?? "",
                            description: description,
                            tags: tags
                        )
                    }
                }
                updateStep(3, isCompleted: true)
                
                // STEP 5: Cleanup and finish
                updateStep(4, isLoading: true)
                try? FileManager.default.removeItem(at: audioURL)
                
                let finalProjects = try await AppwriteService.shared.listUserVideos()
                if let finalProject = finalProjects.first(where: { $0.id == project.id }) {
                    print("✅ Transcription completed successfully")
                }
                updateStep(4, isCompleted: true)
                
                // Close sheet after a short delay
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    showProcessingSheet = false
                    alertMessage = "Transcription completed successfully!"
                    showAlert = true
                }
                
            } catch {
                print("❌ Transcription failed:", error)
                await MainActor.run {
                    showProcessingSheet = false
                    alertMessage = "Error: \(error.localizedDescription)"
                    showAlert = true
                }
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

// MARK: - Supporting Views

struct ProjectCard: View {
    let project: Project
    let onTranscribe: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(formatDuration(project.duration))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: onTranscribe) {
                    HStack(spacing: 6) {
                        if project.isTranscribed {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Done")
                        } else {
                            Image(systemName: "wand.and.stars")
                            Text("Analyze")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(project.isTranscribed ? .gray : .black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        project.isTranscribed ? 
                            Color.gray.opacity(0.3) : 
                            Color.brandPrimary
                    )
                    .clipShape(Capsule())
                }
                .disabled(project.isTranscribed)
            }
            
            if project.isTranscribed {
                VStack(alignment: .leading, spacing: 8) {
                    if let description = project.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    
                    if let tags = project.tags, !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.brandPrimary.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ProcessingView: View {
    @Binding var steps: [ProcessingStep]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Processing Your Video")
                .font(.title2)
                .foregroundColor(.white)
            
            VStack(spacing: 20) {
                ForEach(steps) { step in
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(stepBackgroundColor(for: step))
                                .frame(width: 36, height: 36)
                            
                            if step.isLoading {
                                ProgressView()
                                    .tint(.brandPrimary)
                            } else {
                                Image(systemName: step.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(step.isCompleted ? .black : .white)
                            }
                        }
                        
                        Text(step.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if step.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.brandPrimary)
                        }
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding()
    }
    
    private func stepBackgroundColor(for step: ProcessingStep) -> Color {
        if step.isCompleted {
            return .brandPrimary
        } else if step.isLoading {
            return .brandPrimary.opacity(0.2)
        } else {
            return .white.opacity(0.1)
        }
    }
}
