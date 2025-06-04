import Firebase
import FirebaseFirestore
import FirebaseStorage

class FirebaseConfig {
    static func configure() {
        FirebaseApp.configure()
        
        // Configure Storage settings
        let storage = Storage.storage()
        let storageConfig = StorageConfiguration()
        storageConfig.maxUploadRetryTime = 60 // seconds
        storageConfig.maxDownloadRetryTime = 60 // seconds
    }
} 