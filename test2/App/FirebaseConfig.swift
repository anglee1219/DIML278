import Firebase
import FirebaseFirestore
import FirebaseStorage

class FirebaseConfig {
    static func configure() {
        FirebaseApp.configure()
        
        // Configure Firestore settings for real-time sync and caching
        let db = Firestore.firestore()
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true // Enable offline caching
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited // Allow unlimited cache
        db.settings = settings
        
        print("🔥 Firebase configured with Firestore real-time sync and caching enabled")
        
        // Configure Storage settings
        let storage = Storage.storage()
        let storageConfig = StorageConfiguration()
        storageConfig.maxUploadRetryTime = 60 // seconds
        storageConfig.maxDownloadRetryTime = 60 // seconds
    }
} 