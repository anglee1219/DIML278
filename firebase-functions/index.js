const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

// Cloud Function to send push notifications when a document is created
exports.sendPushNotification = onDocumentCreated('notificationRequests/{requestId}', async (event) => {
    const notificationData = event.data.data();
    const requestId = event.params.requestId;
    
    console.log('📱 🚀 ☁️ === CLOUD FUNCTION TRIGGERED ===');
    console.log('📱 🚀 ☁️ Request ID:', requestId);
    console.log('📱 🚀 ☁️ Notification data:', JSON.stringify(notificationData, null, 2));
    
    // Check if notification has already been processed
    if (notificationData.processed === true) {
        console.log('📱 🚀 ☁️ Notification already processed, skipping');
        return null;
    }
    
    const { fcmToken, title, body, data, targetUserId, notificationType } = notificationData;
    
    if (!fcmToken) {
        console.log('📱 🚀 ☁️ ❌ No FCM token provided');
        // Mark as failed
        await admin.firestore().collection('notificationRequests').doc(requestId).update({
            processed: true,
            failed: true,
            error: 'No FCM token provided',
            processedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return null;
    }
    
    console.log('📱 🚀 ☁️ Processing notification for user:', targetUserId);
    console.log('📱 🚀 ☁️ Notification type:', notificationType);
    console.log('📱 🚀 ☁️ FCM Token (last 8):', fcmToken.slice(-8));
    
    // Ensure data is properly formatted as strings for FCM
    let formattedData = {};
    if (data && typeof data === 'object') {
        Object.keys(data).forEach(key => {
            formattedData[key] = String(data[key]);
        });
    }
    
    // Create the FCM message
    const message = {
        notification: {
            title: title || 'DIML Notification',
            body: body || 'You have a new notification'
        },
        data: formattedData,
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
        console.log('📱 🚀 ☁️ FCM message details:', JSON.stringify(message, null, 2));
        
        const response = await admin.messaging().send(message);
        console.log('📱 🚀 ☁️ ✅ Successfully sent push notification:', response);
        console.log('📱 🚀 ☁️ ✅ Notification sent to user:', targetUserId);
        console.log('📱 🚀 ☁️ ✅ Response message ID:', response);
        
        // Mark as processed successfully
        await event.data.ref.update({ 
            processed: true, 
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            messageId: response,
            targetUserId: targetUserId,
            success: true
        });
        
        return response;
    } catch (error) {
        console.error('📱 🚀 ☁️ ❌ Error sending push notification:', error);
        console.error('📱 🚀 ☁️ ❌ Error code:', error.code);
        console.error('📱 🚀 ☁️ ❌ Error message:', error.message);
        console.error('📱 🚀 ☁️ ❌ Failed for user:', targetUserId);
        console.error('📱 🚀 ☁️ ❌ FCM token (last 8):', fcmToken.slice(-8));
        
        // Mark as failed with detailed error info
        await event.data.ref.update({ 
            processed: true, 
            failed: true, 
            error: error.message,
            errorCode: error.code,
            targetUserId: targetUserId,
            failedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        // Don't throw the error - just log it and mark as failed
        return null;
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
            .where('scheduledFor', '<=', now)
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
            
            // Get user's current FCM token (try targetUserId first, then userId for backward compatibility)
            const userId = notificationData.targetUserId || notificationData.userId;
            const userDoc = await admin.firestore()
                .collection('users')
                .doc(userId)
                .get();
            
            if (!userDoc.exists) {
                console.log(`📱 🚀 ☁️ ⚠️ User ${userId} not found`);
                batch.update(doc.ref, { 
                    processed: true, 
                    failed: true, 
                    error: 'User not found',
                    processedAt: admin.firestore.FieldValue.serverTimestamp() 
                });
                continue;
            }
            
            const userData = userDoc.data();
            // Try to get FCM token from the notification data first (more reliable), then from user data
            const fcmToken = notificationData.fcmToken || userData.fcmToken;
            
            if (!fcmToken) {
                console.log(`📱 🚀 ☁️ ⚠️ No FCM token for user ${userId}`);
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
                    console.log(`📱 🚀 ☁️ ✅ Successfully sent scheduled push notification to ${userId}:`, response);
                    console.log(`📱 🚀 ☁️ ✅ Notification type: ${notificationData.notificationType || 'unknown'}`);
                    batch.update(doc.ref, { 
                        processed: true, 
                        sentAt: admin.firestore.FieldValue.serverTimestamp(),
                        messageId: response,
                        targetUserId: userId
                    });
                })
                .catch((error) => {
                    console.error(`📱 🚀 ☁️ ❌ Error sending scheduled push notification to ${userId}:`, error);
                    batch.update(doc.ref, { 
                        processed: true, 
                        failed: true, 
                        error: error.message,
                        failedAt: admin.firestore.FieldValue.serverTimestamp(),
                        targetUserId: userId
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