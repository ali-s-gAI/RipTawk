import Foundation
import Appwrite

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
    private let databaseId = "main"
    private let videosCollectionId = "videos"
    private let videoBucketId = "videos"
    
    private init() {
        // Initialize Client
        client = Client()
            .setEndpoint("https://cloud.appwrite.io/v1") // Replace with your Appwrite endpoint if self-hosted
            .setProject("riptawk")                       // Your project ID
        
        // Initialize Services
        account = Account(client)
        storage = Storage(client)
        databases = Databases(client)
    }
    
    // MARK: - Video Management
    
    func uploadVideo(url: URL, title: String, duration: TimeInterval) async throws -> VideoProject {
        print("📤 Starting video upload to Appwrite")
        
        // 1. Upload video file to storage
        let file = try await storage.createFile(
            bucketId: videoBucketId,
            fileId: ID.unique(),
            file: InputFile.fromPath(url.path)
        )
        print("📤 Video file uploaded with ID: \(file.id)")
        
        // 2. Create video document in database
        let document = try await databases.createDocument(
            databaseId: databaseId,
            collectionId: videosCollectionId,
            documentId: ID.unique(),
            data: [
                "title": title,
                "videoFileId": file.id,
                "duration": duration,
                "createdAt": Date(),
                "userId": account.currentUser?.id ?? ""
            ]
        )
        print("📤 Video document created with ID: \(document.id)")
        
        // 3. Create and return VideoProject
        return VideoProject(
            id: document.id,
            title: title,
            videoFileId: file.id,
            duration: duration,
            createdAt: Date(),
            userId: account.currentUser?.id ?? ""
        )
    }
    
    func listUserVideos() async throws -> [VideoProject] {
        print("📥 Fetching user videos from Appwrite")
        guard let userId = account.currentUser?.id else {
            throw NSError(domain: "AppwriteService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        let documents = try await databases.listDocuments(
            databaseId: databaseId,
            collectionId: videosCollectionId,
            queries: [
                Query.equal("userId", userId),
                Query.orderDesc("createdAt")
            ]
        )
        
        return try documents.documents.map { doc in
            try VideoProject(
                id: doc.id,
                title: doc.data["title"] as! String,
                videoFileId: doc.data["videoFileId"] as! String,
                duration: doc.data["duration"] as! TimeInterval,
                createdAt: doc.data["createdAt"] as! Date,
                userId: doc.data["userId"] as! String
            )
        }
    }
    
    func getVideoURL(fileId: String) async throws -> URL {
        print("📥 Getting video URL for file ID: \(fileId)")
        let file = try await storage.getFile(
            bucketId: videoBucketId,
            fileId: fileId
        )
        
        let url = try await storage.getFileView(
            bucketId: videoBucketId,
            fileId: fileId
        )
        
        print("📥 Got video URL: \(url.absoluteString)")
        return url
    }
    
    func deleteVideo(project: VideoProject) async throws {
        print("🗑 Deleting video project: \(project.id)")
        
        // Delete file from storage
        try await storage.deleteFile(
            bucketId: videoBucketId,
            fileId: project.videoFileId
        )
        print("🗑 Deleted video file: \(project.videoFileId)")
        
        // Delete document from database
        try await databases.deleteDocument(
            databaseId: databaseId,
            collectionId: videosCollectionId,
            documentId: project.id
        )
        print("🗑 Deleted video document: \(project.id)")
    }
} 