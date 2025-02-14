import Foundation
import SwiftUI
import Appwrite
import JSONCodable

struct VideoProject: Identifiable, Codable {
    let id: String            // Appwrite document ID
    var title: String
    let videoFileId: String   // Appwrite storage file ID
    let duration: TimeInterval
    let createdAt: Date
    let userId: String        // Appwrite user ID
    var transcript: String?   // Optional transcript text
    var isTranscribed: Bool   // Flag to track transcription status
    var description: String?  // AI-generated description
    var tags: [String]?      // AI-extracted tags
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"       // Appwrite uses $id for document IDs
        case title
        case videoFileId = "videoFileID"  // Match the expected field name in Appwrite
        case duration
        case createdAt
        case userId
        case transcript
        case isTranscribed
        case description
        case tags
    }
}

class AppwriteService {
    static let shared = AppwriteService()
    
    let client: Client
    let account: Account
    let storage: Storage
    let databases: Databases
    let functions: Functions
    
    // Constants
    private let databaseId = "67a2ea9400210dd0d73b"  // main
    private let videosCollectionId = "67a2eaa90034a69780ef"  // videos
    private let videoBucketId = "67a2eabd002ffabdf95f"  // videos
    let transcriptionFunctionId = "67ac304b000401bf40eb"
    @AppStorage("currentUserId") private var currentUserId: String = ""
    
    // This cache is cleared when app restarts
    private var videoURLCache: [String: URL] = [:]
    
    private let urlCache: URLCache
    
    private init() {
        // 50MB memory cache, 100MB disk cache
        urlCache = URLCache(memoryCapacity: 50*1024*1024, 
                          diskCapacity: 100*1024*1024, 
                          diskPath: "videos")
        URLCache.shared = urlCache
        
        // Initialize Client with proper session handling
        client = Client()
            .setEndpoint("https://cloud.appwrite.io/v1")
            .setProject("riptawk")
            .setSelfSigned(false)
        
        print("🔧 [INIT] Initialized Appwrite client with project: riptawk")
        
        // Initialize Services
        account = Account(client)
        storage = Storage(client)
        databases = Databases(client)
        functions = Functions(client)
    }
    
    // MARK: - Session Management
    
    func initializeSession() async throws {
        print("🔄 [SESSION] Initializing session...")
        do {
            // Try to get the current session
            let session = try await account.getSession(sessionId: "current")
            currentUserId = session.userId
            print("✅ [SESSION] Restored existing session - UserID: \(session.userId)")
            
            // Verify account access
            let accountDetails = try await account.get()
            print("👤 [SESSION] Account verified - ID: \(accountDetails.id), Email: \(accountDetails.email)")
        } catch {
            print("⚠️ [SESSION] No active session found: \(error.localizedDescription)")
            currentUserId = ""
            throw error
        }
    }
    
    func createSession(email: String, password: String) async throws {
        print("🔑 [SESSION] Creating new session...")
        
        // First, clean up any existing sessions
        do {
            try await account.deleteSessions()
            print("🧹 [SESSION] Cleaned up existing sessions")
        } catch {
            print("⚠️ [SESSION] No existing sessions to clean up")
        }
        
        // Create new session
        let session = try await account.createEmailPasswordSession(
            email: email,
            password: password
        )
        currentUserId = session.userId
        print("✅ [SESSION] Created new session - UserID: \(session.userId)")
        
        // Verify the session works
        let accountDetails = try await account.get()
        print("👤 [SESSION] Session verified - ID: \(accountDetails.id), Email: \(accountDetails.email)")
    }
    
    func signOut() async {
        print("🚪 [SESSION] Signing out...")
        do {
            try await account.deleteSessions()
            currentUserId = ""
            print("✅ [SESSION] Successfully signed out")
        } catch {
            print("❌ [SESSION] Error signing out: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Account Management
    
    func createAccount(email: String, password: String, name: String) async throws -> User<[String: AnyCodable]> {
        print("📝 [ACCOUNT] Creating new account...")
        let user = try await self.account.create(
            userId: ID.unique(),
            email: email,
            password: password,
            name: name
        )
        print("✅ [ACCOUNT] Created account - Email: \(email), Name: \(name)")
        return user
    }
    
    // MARK: - Video Management
    
    func uploadVideo(url: URL, title: String, duration: TimeInterval) async throws -> VideoProject {
        print("📤 Starting video upload to Appwrite")
        
        guard !currentUserId.isEmpty else {
            print("❌ [UPLOAD] Error: User not logged in")
            throw NSError(domain: "AppwriteService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        // 1. Upload video file to storage
        print("📤 [UPLOAD] Uploading to bucket: \(videoBucketId)")
        let file = try await storage.createFile(
            bucketId: videoBucketId,
            fileId: ID.unique(),
            file: InputFile.fromPath(url.path)
        )
        print("📤 [UPLOAD] Video file uploaded with ID: \(file.id)")
        
        // 2. Create video document in database
        print("📤 [UPLOAD] Creating document in collection: \(videosCollectionId)")
        let now = Date()
        let isoFormatter = ISO8601DateFormatter()
        let isoDate = isoFormatter.string(from: now)
        
        let document = try await databases.createDocument(
            databaseId: databaseId,
            collectionId: videosCollectionId,
            documentId: ID.unique(),
            data: [
                "title": title,
                "videoFileID": file.id,  // Changed to match expected field name
                "duration": duration,
                "createdAt": isoDate,
                "userId": currentUserId,
                "isTranscribed": false,  // Add required field
                "transcript": nil,       // Initialize as nil
                "description": nil,      // Initialize as nil
                "tags": []              // Initialize as empty array
            ] as [String : Any]
        )
        print("📤 [UPLOAD] Video document created with ID: \(document.id)")
        
        // 3. Create and return VideoProject
        return VideoProject(
            id: document.id,
            title: title,
            videoFileId: file.id,
            duration: duration,
            createdAt: now,
            userId: currentUserId,
            transcript: nil,
            isTranscribed: false,
            description: nil,
            tags: []
        )
    }
    
    func listUserVideos() async throws -> [VideoProject] {
        print("📥 Fetching user videos from Appwrite")
        guard !currentUserId.isEmpty else {
            throw NSError(domain: "AppwriteService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        let documents = try await databases.listDocuments(
            databaseId: databaseId,
            collectionId: videosCollectionId,
            queries: [
                Query.equal("userId", value: currentUserId),
                Query.orderDesc("createdAt")
            ]
        )
        
        return try documents.documents.map { doc in
            let data = doc.data
            print("📥 [DEBUG] Document data: \(data)")
            
            do {
                guard let title = data["title"]?.value as? String else {
                    print("❌ [DEBUG] Invalid title: \(String(describing: data["title"]))")
                    throw NSError(domain: "AppwriteService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid title"])
                }
                
                guard let videoFileId = data["videoFileID"]?.value as? String else {
                    print("❌ [DEBUG] Invalid videoFileID: \(String(describing: data["videoFileID"]))")
                    throw NSError(domain: "AppwriteService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid videoFileID"])
                }
                
                guard let duration = data["duration"]?.value as? TimeInterval else {
                    print("❌ [DEBUG] Invalid duration: \(String(describing: data["duration"]))")
                    throw NSError(domain: "AppwriteService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid duration"])
                }
                
                // Handle date parsing
                let createdAt: Date
                if let dateString = data["createdAt"]?.value as? String {
                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = isoFormatter.date(from: dateString) {
                        createdAt = date
                    } else {
                        print("❌ [DEBUG] Invalid date format: \(dateString)")
                        throw NSError(domain: "AppwriteService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid date format"])
                    }
                } else {
                    print("❌ [DEBUG] Missing createdAt: \(String(describing: data["createdAt"]))")
                    throw NSError(domain: "AppwriteService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing createdAt"])
                }
                
                guard let userId = data["userId"]?.value as? String else {
                    print("❌ [DEBUG] Invalid userId: \(String(describing: data["userId"]))")
                    throw NSError(domain: "AppwriteService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid userId"])
                }
                
                let transcript = data["transcript"]?.value as? String
                let isTranscribed = data["isTranscribed"]?.value as? Bool ?? false
                let description = data["description"]?.value as? String
                let tags = data["tags"]?.value as? [String]
                
                return VideoProject(
                    id: doc.id,
                    title: title,
                    videoFileId: videoFileId,
                    duration: duration,
                    createdAt: createdAt,
                    userId: userId,
                    transcript: transcript,
                    isTranscribed: isTranscribed,
                    description: description,
                    tags: tags
                )
            } catch {
                print("❌ [DEBUG] Error parsing document \(doc.id): \(error)")
                throw error
            }
        }
    }
    
    func getVideoURL(fileId: String) async throws -> URL {
        // Check cache first
        if let cachedURL = videoURLCache[fileId] {
            return cachedURL
        }
        
        print("📥 Getting video URL for file ID: \(fileId)")
        
        // Get the file view URL
        let urlString = "\(client.endPoint)/storage/buckets/\(videoBucketId)/files/\(fileId)/view"
        guard var urlComponents = URLComponents(string: urlString) else {
            throw NSError(domain: "AppwriteService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid video URL"])
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "project", value: "riptawk")
        ]
        
        guard let url = urlComponents.url else {
            throw NSError(domain: "AppwriteService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid video URL"])
        }
        
        // Configure caching for the request
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = urlCache
        
        // Cache the URL
        videoURLCache[fileId] = url
        
        return url
    }
    
    func deleteVideo(_ project: VideoProject) async throws {
        print("🗑 [DELETE] Starting deletion for project: \(project.id)")
        
        guard !currentUserId.isEmpty else {
            print("❌ [DELETE] Error: User not logged in")
            throw NSError(domain: "AppwriteService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        // Verify ownership
        guard project.userId == currentUserId else {
            print("❌ [DELETE] Error: User does not own this video")
            throw NSError(domain: "AppwriteService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You don't have permission to delete this video"])
        }
        
        do {
            // 1. Delete file from storage
            print("🗑 [DELETE] Deleting file from storage: \(project.videoFileId)")
            try await storage.deleteFile(
                bucketId: videoBucketId,
                fileId: project.videoFileId
            )
            print("✅ [DELETE] File deleted from storage")
            
            // 2. Delete document from database
            print("🗑 [DELETE] Deleting document from collection: \(project.id)")
            try await databases.deleteDocument(
                databaseId: databaseId,
                collectionId: videosCollectionId,
                documentId: project.id
            )
            print("✅ [DELETE] Document deleted from collection")
            
        } catch {
            print("❌ [DELETE] Error during deletion: \(error.localizedDescription)")
            throw error
        }
    }
    
    func updateVideo(project: VideoProject, newVideoURL: URL, duration: TimeInterval) async throws -> VideoProject {
        print("📤 [UPDATE] Starting video update for project: \(project.id)")
        print("📤 [UPDATE] Current videoFileId: \(project.videoFileId)")
        
        guard !currentUserId.isEmpty else {
            print("❌ [UPDATE] Error: User not logged in")
            throw NSError(domain: "AppwriteService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        // Verify ownership
        guard project.userId == currentUserId else {
            print("❌ [UPDATE] Error: User does not own this video")
            throw NSError(domain: "AppwriteService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You don't have permission to update this video"])
        }
        
        // 1. Upload new file to storage first
        print("📤 [UPDATE] Uploading new file to bucket: \(videoBucketId)")
        let file = try await storage.createFile(
            bucketId: videoBucketId,
            fileId: ID.unique(),
            file: InputFile.fromPath(newVideoURL.path)
        )
        print("📤 [UPDATE] New video file uploaded with ID: \(file.id)")
        
        // 2. Update document in database with new file ID
        print("📤 [UPDATE] Updating document \(project.id) in collection: \(videosCollectionId)")
        
        let updateData: [String: Any] = [
            "videoFileID": file.id,  // Make sure this matches the field name in Appwrite
            "duration": duration
        ]
        print("📤 [UPDATE] Update data: \(updateData)")
        
        let document = try await databases.updateDocument(
            databaseId: databaseId,
            collectionId: videosCollectionId,
            documentId: project.id,
            data: updateData
        )
        print("📤 [UPDATE] Document updated. Response data: \(document.data)")
        
        // Verify the update
        guard let updatedFileId = document.data["videoFileID"]?.value as? String else {
            print("❌ [UPDATE] Failed to verify updated videoFileID in document")
            throw NSError(domain: "AppwriteService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to update video file ID"])
        }
        print("✅ [UPDATE] Verified new videoFileID in document: \(updatedFileId)")
        
        // 3. Delete old file from storage only after document is updated
        print("🗑 [UPDATE] Deleting old file: \(project.videoFileId)")
        do {
            try await storage.deleteFile(
                bucketId: videoBucketId,
                fileId: project.videoFileId
            )
            print("✅ [UPDATE] Successfully deleted old file")
        } catch {
            print("⚠️ [UPDATE] Failed to delete old file: \(error.localizedDescription)")
            // Continue since this is not critical
        }
        
        // Clear the URL cache for both old and new file IDs to ensure fresh data
        videoURLCache.removeValue(forKey: project.videoFileId)
        videoURLCache.removeValue(forKey: file.id)
        print("🧹 [UPDATE] Cleared URL cache for both old and new file IDs")
        
        // 4. Create and return updated VideoProject
        let updatedProject = VideoProject(
            id: document.id,
            title: project.title,
            videoFileId: file.id,
            duration: duration,
            createdAt: project.createdAt,
            userId: currentUserId,
            transcript: project.transcript,
            isTranscribed: project.isTranscribed,
            description: project.description,
            tags: project.tags
        )
        print("✅ [UPDATE] Returning updated project with new videoFileId: \(updatedProject.videoFileId)")
        return updatedProject
    }
    
    func updateProjectTitle(_ project: VideoProject, newTitle: String) async throws -> VideoProject {
        print("📝 [UPDATE] Updating project title to: \(newTitle)")
        
        let document = try await databases.updateDocument(
            databaseId: databaseId,
            collectionId: videosCollectionId,
            documentId: project.id,
            data: [
                "title": newTitle
            ]
        )
        
        // Return updated project
        return VideoProject(
            id: project.id,
            title: newTitle,
            videoFileId: project.videoFileId,
            duration: project.duration,
            createdAt: project.createdAt,
            userId: project.userId,
            transcript: project.transcript,
            isTranscribed: project.isTranscribed,
            description: project.description,
            tags: project.tags
        )
    }
    
    // Get all projects (wrapper around listUserVideos)
    func getProjects() async throws -> [Project] {
        let videoProjects = try await listUserVideos()
        
        // Convert VideoProject to Project using async operations
        var projects: [Project] = []
        for videoProject in videoProjects {
            // Get video URL (either from cache or fetch new)
            let videoURL = try await getVideoURL(fileId: videoProject.videoFileId)
            
            let project = Project(
                id: videoProject.id,
                title: videoProject.title,
                videoURL: videoURL,  // Use actual URL instead of just cached
                isTranscribed: videoProject.isTranscribed
            )
            projects.append(project)
        }
        
        return projects
    }
    
    // Update project with transcript
    func updateProjectTranscript(projectId: String, transcript: String) async throws {
        print("📝 [UPDATE] Adding transcript to project: \(projectId)")
        
        let data: [String: Any] = [
            "transcript": transcript,
            "isTranscribed": true
        ]
        
        do {
            try await databases.updateDocument(
                databaseId: databaseId,
                collectionId: videosCollectionId,
                documentId: projectId,
                data: data
            )
            print("✅ [UPDATE] Successfully added transcript")
        } catch {
            print("❌ [UPDATE] Error updating transcript: \(error)")
            throw error
        }
    }
    
    // Add new method to update transcript with AI-generated content
    func updateProjectWithTranscription(projectId: String, transcript: String, description: String?, tags: [String]?) async throws {
        print("📝 [UPDATE] Adding transcription data to project: \(projectId)")
        
        var data: [String: Any] = [
            "transcript": transcript,
            "isTranscribed": true
        ]
        
        if let description = description {
            data["description"] = description
        }
        
        if let tags = tags {
            data["tags"] = tags
        }
        
        do {
            try await databases.updateDocument(
                databaseId: databaseId,
                collectionId: videosCollectionId,
                documentId: projectId,
                data: data
            )
            print("✅ [UPDATE] Successfully added transcription data")
        } catch {
            print("❌ [UPDATE] Error updating transcription data: \(error)")
            throw error
        }
    }
    
    private func callTranscriptionService(audioData: Data) async throws -> String {
        // Construct the Appwrite function URL
        let functionURL = "\(client.endPoint)/functions/transcribe/executions"
        guard var urlComponents = URLComponents(string: functionURL) else {
            throw NSError(domain: "AppwriteService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid function URL"])
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "project", value: "riptawk")
        ]
        
        guard let url = urlComponents.url else {
            throw NSError(domain: "AppwriteService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid function URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
        
        // Add Appwrite session cookie if needed
        if let cookies = HTTPCookieStorage.shared.cookies {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        print("🎙 [TRANSCRIBE] Calling function at: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.upload(for: request, from: audioData)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AppwriteService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        print("🎙 [TRANSCRIBE] Response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if let errorText = String(data: data, encoding: .utf8) {
                print("🎙 [TRANSCRIBE] Error response: \(errorText)")
            }
            throw NSError(domain: "AppwriteService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Function returned error \(httpResponse.statusCode)"])
        }
        
        guard let transcript = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "AppwriteService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        return transcript
    }
    
    // Add a new method to fetch user names
    func getUserName(userId: String) async throws -> String {
        do {
            let user = try await account.get()
            if user.id == userId {
                return user.name
            }
            // If it's not the current user, return a formatted version of the ID
            return "User \(String(userId.prefix(6)))"
        } catch {
            print("⚠️ Could not fetch user name: \(error)")
            return "User \(String(userId.prefix(6)))"
        }
    }
    
    func updateProjectMetadata(projectId: String, description: String?, tags: [String]?) async throws {
        print("📝 [UPDATE] Updating project metadata for: \(projectId)")
        
        var data: [String: Any] = [:]
        
        if let description = description {
            data["description"] = description
        }
        
        if let tags = tags {
            data["tags"] = tags
        }
        
        do {
            try await databases.updateDocument(
                databaseId: databaseId,
                collectionId: videosCollectionId,
                documentId: projectId,
                data: data
            )
            print("✅ [UPDATE] Successfully updated project metadata")
        } catch {
            print("❌ [UPDATE] Error updating project metadata: \(error)")
            throw error
        }
    }
} 
