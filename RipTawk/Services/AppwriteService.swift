import Foundation
import Appwrite

class AppwriteService {
    static let shared = AppwriteService()
    
    let client: Client
    let account: Account
    let storage: Storage
    let databases: Databases
    
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
} 