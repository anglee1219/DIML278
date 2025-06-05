const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp({
  projectId: 'cs-278-diml'
});

const db = admin.firestore();

async function testNotification() {
  console.log('📱 Adding test notification to Firestore...');
  
  try {
    const notificationRequest = {
      fcmToken: 'test_token_12345',
      title: '🧪 Direct Test Push',
      body: 'Testing Cloud Function trigger directly',
      data: {
        type: 'test',
        source: 'direct'
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      processed: false
    };
    
    const docRef = await db.collection('notificationRequests').add(notificationRequest);
    console.log('✅ Test notification added with ID:', docRef.id);
    console.log('🔍 This should trigger the sendPushNotification Cloud Function');
    
    // Wait a moment then check if it was processed
    setTimeout(async () => {
      const doc = await docRef.get();
      const data = doc.data();
      console.log('📊 Document after processing:', {
        processed: data.processed,
        sentAt: data.sentAt,
        failed: data.failed,
        error: data.error
      });
    }, 5000);
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

testNotification(); 