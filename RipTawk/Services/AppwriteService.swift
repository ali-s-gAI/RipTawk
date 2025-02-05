import Foundation
import SwiftUI
import Appwrite
import JSONCodable

struct VideoProject: Identifiable, Codable {
    let id: String            // Appwrite document ID
    let title: String
    let videoFileId: String   // Appwrite storage file ID
    let duration: TimeInterval
    let createdAt: Date
    let userId: String        // Appwrite user ID
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"       // Appwrite uses $id for document IDs
        case title
        case videoFileId
        case duration
        case createdAt
        case userId
    }
}

class AppwriteService {
    static let shared = AppwriteService()
    
    let client: Client
    let account: Account
    let storage: Storage
    let databases: Databases
    
    // Constants
    private let databaseId = "67a2ea9400210dd0d73b"  // main
    private let videosCollectionId = "67a2eaa90034a69780ef"  // videos
    private let videoBucketId = "67a2eabd002ffabdf95f"  // videos
    @AppStorage("currentUserId") private var currentUserId: String = ""
    
    private init() {
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
                "videoFileId": file.id,
                "duration": duration,
                "createdAt": isoDate,
                "userId": currentUserId
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
            userId: currentUserId
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
            guard let title = data["title"]?.value as? String,
                  let videoFileId = data["videoFileId"]?.value as? String,
                  let duration = data["duration"]?.value as? TimeInterval,
                  let createdAt = data["createdAt"]?.value as? Date,
                  let userId = data["userId"]?.value as? String else {
                throw NSError(domain: "AppwriteService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid document data"])
            }
            
            return VideoProject(
                id: doc.id,
                title: title,
                videoFileId: videoFileId,
                duration: duration,
                createdAt: createdAt,
                userId: userId
            )
        }
    }
    
    func getVideoURL(fileId: String) async throws -> URL {
        print("📥 Getting video URL for file ID: \(fileId)")
        let file = try await storage.getFile(
            bucketId: videoBucketId,
            fileId: fileId
        )
        
        let urlString = try await storage.getFileView(
            bucketId: videoBucketId,
            fileId: fileId
        ).description
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "AppwriteService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid video URL"])
        }
        
        print("📥 Got video URL: \(url.absoluteString)")
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
} 
