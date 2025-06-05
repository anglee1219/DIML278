const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

// Cloud Function to send push notifications when a document is created
exports.sendPushNotification = onDocumentCreated('notificationRequests/{requestId}', async (event) => {
    const notificationData = event.data.data();
    
    console.log('📱 🚀 ☁️ === CLOUD FUNCTION TRIGGERED ===');
    console.log('📱 🚀 ☁️ Notification data:', notificationData);
    
    // Check if notification has already been processed
    if (notificationData.processed) {
        console.log('📱 🚀 ☁️ Notification already processed, skipping');
        return null;
    }
    
    const { fcmToken, title, body, data } = notificationData;
    
    if (!fcmToken) {
        console.log('📱 🚀 ☁️ ❌ No FCM token provided');
        return null;
    }
    
    // Create the FCM message
    const message = {
        notification: {
            title: title || 'DIML Notification',
            body: body || 'You have a new notification'
        },
        data: data || {},
        token: fcmToken,
        // iOS specific settings
        apns: {
            payload: {
                aps: {
                    alert: {
                        title: title || 'DIML Notification',
                        body: body || 'You have a new notification'
                    },
                    sound: 'default',
                    badge: 1
                }
            }
        }
    };
    
    try {
        console.log('📱 🚀 ☁️ Sending FCM message...');
        const response = await admin.messaging().send(message);
        console.log('📱 🚀 ☁️ ✅ Successfully sent push notification:', response);
        
        // Mark as processed
        await event.data.ref.update({ 
            processed: true, 
            sentAt: admin.firestore.FieldValue.serverTimestamp() 
        });
        
        return response;
    } catch (error) {
        console.error('📱 🚀 ☁️ ❌ Error sending push notification:', error);
        
        // Mark as failed
        await event.data.ref.update({ 
            processed: true, 
            failed: true, 
            error: error.message,
            failedAt: admin.firestore.FieldValue.serverTimestamp() 
        });
        
        throw error;
    }
});

// Cloud Function to send scheduled push notifications
exports.sendScheduledNotifications = onSchedule('every 1 minutes', async (event) => {
    console.log('📱 🚀 ☁️ === CHECKING FOR SCHEDULED NOTIFICATIONS ===');
    
    const now = admin.firestore.Timestamp.now();
    
    try {
        // Query for notifications that are due and not yet processed
        const scheduledNotifications = await admin.firestore()
            .collection('scheduledNotifications')
            .where('processed', '==', false)
            .where('scheduledTime', '<=', now)
            .limit(50) // Process up to 50 notifications at a time
            .get();
        
        console.log(`📱 🚀 ☁️ Found ${scheduledNotifications.size} scheduled notifications to send`);
        
        if (scheduledNotifications.empty) {
            console.log('📱 🚀 ☁️ No scheduled notifications to send');
            return null;
        }
        
        const batch = admin.firestore().batch();
        const fcmPromises = [];
        
        for (const doc of scheduledNotifications.docs) {
            const notificationData = doc.data();
            console.log('📱 🚀 ☁️ Processing scheduled notification:', doc.id);
            
            // Get user's current FCM token
            const userDoc = await admin.firestore()
                .collection('users')
                .doc(notificationData.userId)
                .get();
            
            if (!userDoc.exists) {
                console.log(`📱 🚀 ☁️ ⚠️ User ${notificationData.userId} not found`);
                batch.update(doc.ref, { 
                    processed: true, 
                    failed: true, 
                    error: 'User not found',
                    processedAt: admin.firestore.FieldValue.serverTimestamp() 
                });
                continue;
            }
            
            const userData = userDoc.data();
            const fcmToken = userData.fcmToken;
            
            if (!fcmToken) {
                console.log(`📱 🚀 ☁️ ⚠️ No FCM token for user ${notificationData.userId}`);
                batch.update(doc.ref, { 
                    processed: true, 
                    failed: true, 
                    error: 'No FCM token',
                    processedAt: admin.firestore.FieldValue.serverTimestamp() 
                });
                continue;
            }
            
            // Create the FCM message
            const message = {
                notification: {
                    title: notificationData.title,
                    body: notificationData.body
                },
                data: notificationData.data || {},
                token: fcmToken,
                // iOS specific settings
                apns: {
                    payload: {
                        aps: {
                            alert: {
                                title: notificationData.title,
                                body: notificationData.body
                            },
                            sound: 'default',
                            badge: 1
                        }
                    }
                }
            };
            
            // Send the FCM message
            const fcmPromise = admin.messaging().send(message)
                .then((response) => {
                    console.log(`📱 🚀 ☁️ ✅ Successfully sent scheduled push notification to ${notificationData.userId}:`, response);
                    batch.update(doc.ref, { 
                        processed: true, 
                        sentAt: admin.firestore.FieldValue.serverTimestamp(),
                        messageId: response 
                    });
                })
                .catch((error) => {
                    console.error(`📱 🚀 ☁️ ❌ Error sending scheduled push notification to ${notificationData.userId}:`, error);
                    batch.update(doc.ref, { 
                        processed: true, 
                        failed: true, 
                        error: error.message,
                        failedAt: admin.firestore.FieldValue.serverTimestamp() 
                    });
                });
            
            fcmPromises.push(fcmPromise);
        }
        
        // Wait for all FCM messages to be sent
        await Promise.all(fcmPromises);
        
        // Commit the batch update
        await batch.commit();
        
        console.log('📱 🚀 ☁️ ✅ Finished processing scheduled notifications');
        return null;
        
    } catch (error) {
        console.error('📱 🚀 ☁️ ❌ Error in scheduled notifications function:', error);
        throw error;
    }
});

// Test function to verify Cloud Functions are working
exports.testFunction = onRequest((req, res) => {
    console.log('📱 🚀 ☁️ === TEST FUNCTION CALLED ===');
    res.json({ 
        message: 'Cloud Functions are working!', 
        timestamp: new Date().toISOString(),
        status: 'success' 
    });
}); 