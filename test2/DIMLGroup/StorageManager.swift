import Foundation
import FirebaseStorage
import UIKit

class StorageManager {
    static let shared = StorageManager()
    private let storage = Storage.storage()
    
    private init() {}
    
    func uploadImage(_ image: UIImage, path: String) async throws -> String {
        print("🔥 StorageManager: Starting upload for path: \(path)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("🔥 StorageManager: Failed to convert image to JPEG data")
            throw NSError(domain: "StorageManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        print("🔥 StorageManager: Image converted to JPEG data (\(imageData.count) bytes)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let storageRef = storage.reference().child(path)
        print("🔥 StorageManager: Created storage reference for path: \(path)")
        
        do {
            print("🔥 StorageManager: Starting putDataAsync...")
            let _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
            print("🔥 StorageManager: putDataAsync completed successfully")
            
            print("🔥 StorageManager: Getting download URL...")
            let downloadURL = try await storageRef.downloadURL()
            print("🔥 StorageManager: Download URL obtained: \(downloadURL.absoluteString)")
            
            return downloadURL.absoluteString
        } catch {
            print("🔥 StorageManager: Error uploading image: \(error)")
            print("🔥 StorageManager: Error details: \(error.localizedDescription)")
            throw error
        }
    }
    
    func deleteImage(at path: String) async throws {
        let storageRef = storage.reference().child(path)
        try await storageRef.delete()
    }
} 