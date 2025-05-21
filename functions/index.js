/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentWritten} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

// Initialize Firebase Admin SDK
admin.initializeApp();

// Send article notification to all users
exports.sendArticleNotification = onCall({
  maxInstances: 10,
  timeoutSeconds: 60,
  memory: "256MiB",
}, async (request) => {
  try {
    const { articleId, title, body, type } = request.data;
    
    if (!articleId || !title || !body) {
      throw new HttpsError('invalid-argument', 'Article ID, title, and body are required');
    }
    
    logger.info(`Sending article notification for ${articleId}`);
    
    // Get the article data
    const articleDoc = await admin.firestore().collection('articles').doc(articleId).get();
    if (!articleDoc.exists) {
      throw new HttpsError('not-found', 'Article not found');
    }
    
    const article = articleDoc.data();
    
    // Get all users
    const usersSnapshot = await admin.firestore().collection('users').get();
    
    const fcmTokensSet = new Set();
    const notificationPromises = [];
    
    // Add notification to each user's collection and collect FCM tokens
    usersSnapshot.forEach(userDoc => {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      // Skip the article author
      if (userId === article.authorId) {
        return;
      }
      
      // Collect unique FCM tokens
      if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
        userData.fcmTokens.forEach(token => fcmTokensSet.add(token));
      }
      
      // Create a notification for the user
      const notificationRef = admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc();
        
      const notification = {
        id: notificationRef.id,
        type: 'article',
        title: 'New Article Available',
        body: `"${article.title}" has been published. Check it out!`,
        articleId: articleId,
        isRead: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      notificationPromises.push(notificationRef.set(notification));
    });
    
    // Wait for all notifications to be created
    await Promise.all(notificationPromises);
    
    // Convert Set to Array
    const fcmTokens = Array.from(fcmTokensSet);
    
    // Send FCM messages if there are tokens
    if (fcmTokens.length > 0) {
      // Send in batches of 500 (FCM limit)
      const batchSize = 500;
      for (let i = 0; i < fcmTokens.length; i += batchSize) {
        const batch = fcmTokens.slice(i, i + batchSize);
        
        const message = {
          notification: {
            title: title || 'New Article Available',
            body: body || `"${article.title}" has been published. Check it out!`,
          },
          data: {
            articleId: articleId,
            type: type || 'article',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            screen: 'article_detail',
          },
          tokens: batch,
          android: {
            notification: {
              tag: articleId, // Group notifications by articleId on Android
            },
          },
          apns: {
            headers: {
              'apns-collapse-id': articleId, // Group notifications by articleId on iOS
            },
          },
        };
        
        try {
          const response = await admin.messaging().sendMulticast(message);
          logger.info(`Successfully sent notifications: ${response.successCount}/${batch.length}`);
        } catch (error) {
          logger.error('Error sending notifications:', error);
        }
      }
    }
    
    // Also send to the 'articles' topic for users who might not be registered yet
    await admin.messaging().send({
      notification: {
        title: title || 'New Article Available',
        body: body || `"${article.title}" has been published. Check it out!`,
      },
      data: {
        articleId: articleId,
        type: type || 'article',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        screen: 'article_detail',
      },
      topic: 'articles',
      android: {
        notification: {
          tag: articleId,
        },
      },
      apns: {
        headers: {
          'apns-collapse-id': articleId,
        },
      },
    });
    
    return { success: true, message: 'Article notifications sent successfully' };
  } catch (error) {
    logger.error('Error in sendArticleNotification:', error);
    throw new HttpsError('internal', error.message);
  }
});

// Auto-publish article notification when a article is published
exports.autoNotifyNewArticle = onDocumentCreated({
  document: "articles/{articleId}",
  region: "us-central1",
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    logger.info("No data associated with the event");
    return;
  }
  
  const article = snapshot.data();
  const articleId = snapshot.id;
  
  // Only send notification if the article is published
  if (!article.isPublished) {
    return;
  }
  
  try {
    // Call the sendArticleNotification function
    await admin.firestore().collection('system').doc('functions').set({
      operation: 'sendArticleNotification',
      params: {
        articleId: articleId,
        title: 'New Article Available',
        body: `"${article.title}" has been published. Check it out!`,
        type: 'article',
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    logger.info(`Triggered article notification for ${articleId}`);
  } catch (error) {
    logger.error('Error triggering article notification:', error);
  }
});

// Send poll notification to all users
exports.sendPollNotification = onCall({
  maxInstances: 10,
  timeoutSeconds: 60,
  memory: "256MiB",
}, async (request) => {
  try {
    const { pollId, title, body, type } = request.data;
    
    if (!pollId || !title || !body || !type) {
      throw new HttpsError('invalid-argument', 'Poll ID, title, body, and type are required');
    }
    
    logger.info(`Sending poll notification for ${pollId} of type ${type}`);
    
    // Get the poll data
    const pollDoc = await admin.firestore().collection('polls').doc(pollId).get();
    if (!pollDoc.exists) {
      throw new HttpsError('not-found', 'Poll not found');
    }
    
    const poll = pollDoc.data();
    
    // Get all users
    const usersSnapshot = await admin.firestore().collection('users').get();
    
    const fcmTokensSet = new Set();
    const notificationPromises = [];
    
    // Add notification to each user's collection and collect FCM tokens
    usersSnapshot.forEach(userDoc => {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      // Skip the poll creator for certain notification types
      if (type === 'newPoll' && userId === poll.creatorId) {
        return;
      }
      
      // Collect unique FCM tokens
      if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
        userData.fcmTokens.forEach(token => fcmTokensSet.add(token));
      }
      
      // Create a notification for the user
      const notificationRef = admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc();
        
      const notification = {
        id: notificationRef.id,
        type: type,
        title: title,
        message: body,
        pollId: pollId,
        isRead: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        data: {
          pollId: pollId,
          type: type,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          screen: 'poll_detail' // Changed from 'polls' to 'poll_detail' for consistency
        }
      };
      
      notificationPromises.push(notificationRef.set(notification));
    });
    
    // Wait for all notifications to be created
    await Promise.all(notificationPromises);
    
    // Convert Set to Array
    const fcmTokens = Array.from(fcmTokensSet);
    
    // Send FCM messages if there are tokens
    if (fcmTokens.length > 0) {
      // Send in batches of 500 (FCM limit)
      const batchSize = 500;
      for (let i = 0; i < fcmTokens.length; i += batchSize) {
        const batch = fcmTokens.slice(i, i + batchSize);
        
        const message = {
          notification: {
            title: title || 'New Poll Available',
            body: body || `A new poll "${poll.title}" has been published. Vote now!`,
          },
          data: {
            pollId: pollId,
            type: type || 'poll',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            screen: 'poll_detail', // Changed from 'polls' to 'poll_detail'
          },
          tokens: batch,
          android: {
            notification: {
              tag: pollId, 
            },
          },
          apns: {
            headers: {
              'apns-collapse-id': pollId, 
            },
          },
        };
        
        try {
          const response = await admin.messaging().sendMulticast(message);
          logger.info(`Successfully sent notifications: ${response.successCount}/${batch.length}`);
        } catch (error) {
          logger.error('Error sending notifications:', error);
        }
      }
    }
    
    // Also send to the 'polls' topic for users who might not be registered yet
    // This callable function sends to the generic topic. 
    // Scoping is handled by autoPollNotifications calling sendPollNotificationToUsers helper.
    await admin.messaging().send({
      notification: {
        title: title || 'New Poll Available',
        body: body || `A new poll "${poll.title}" has been published. Vote now!`,
      },
      data: {
        pollId: pollId,
        type: type || 'poll',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        screen: 'poll_detail', // Changed from 'polls' to 'poll_detail'
      },
      topic: 'polls',
      android: {
        notification: {
          tag: pollId,
        },
      },
      apns: {
        headers: {
          'apns-collapse-id': pollId,
        },
      },
    });
    
    return { success: true, message: 'Poll notifications sent successfully' };
  } catch (error) { // ADDED CATCH BLOCK
    logger.error('Error in sendPollNotification:', error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError('internal', error.message || 'Internal server error');
  }
});

// Auto-notify when a poll is created, about to expire, or results are ready
exports.autoPollNotifications = onDocumentCreated({
  document: "polls/{pollId}",
  region: "us-central1",
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    logger.info("No data associated with the event");
    return;
  }
  
  const pollData = snapshot.data(); // Renamed to pollData to avoid conflict
  const pollId = snapshot.id;
  
  try {
    // Directly send new poll notification instead of using system/functions
    await sendPollNotificationToUsers(
      pollId,
      'New Poll Available',
      `A new poll "${pollData.title}" is now available for voting.`,
      'newPoll',
      pollData // Pass the full poll object
    );
    
    logger.info(`Triggered new poll notification for ${pollId}`);
    
    // Schedule deadline notification if there's an end date
    if (pollData.expiresAt) { // Assuming expiresAt is the correct field
      const endDate = pollData.expiresAt.toDate();
      const notifyBefore = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
      const notifyAt = new Date(endDate.getTime() - notifyBefore);
      
      if (notifyAt > new Date()) {
        // Store the scheduled notification
        await admin.firestore().collection('scheduledNotifications').doc().set({
          pollId: pollId,
          type: 'pollDeadline',
          scheduledFor: notifyAt,
          title: 'Poll Closing Soon',
          body: `The poll "${pollData.title}" will close in 24 hours.`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          // Store necessary poll scoping info for when the scheduled notification is processed
          pollIsAllClasses: pollData.isAllClasses,
          pollClassScopes: pollData.classScopes || [], 
          pollTitle: pollData.title, // Store title for constructing message later
          pollCreatedBy: pollData.createdBy, // Store creator to avoid self-notification if needed
          data: {
            pollId: pollId,
            type: 'pollDeadline',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            screen: 'poll_detail'
          }
        });
        
        logger.info(`Scheduled deadline notification for poll ${pollId}`);
      }
    }
  } catch (error) {
    logger.error('Error triggering poll notifications:', error);
  }
});

// Helper function to check user notification preferences
async function shouldNotifyUser(userId, notificationType) {
  try {
    const userPrefs = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    if (!userPrefs.exists) return true; // Default to true if no preferences set
    
    const data = userPrefs.data();
    switch (notificationType) {
      case 'newPoll':
        return data.notifyNewPoll ?? true;
      case 'pollDeadline':
        return data.notifyPollDeadline ?? true;
      case 'pollResults':
        return data.notifyPollResults ?? true;
      case 'proposalEndorsement':
        return data.notifyProposalEndorsement ?? true;
      case 'proposalEndorsementComplete':
        return data.notifyProposalEndorsementComplete ?? true;
      case 'proposalReply':
        return data.notifyProposalReply ?? true;
      case 'article':
        return data.notifyArticle ?? true;
      case 'newEvent':
        return data.notifyNewEvent ?? true;
      case 'eventReminder':
        return data.notifyEventReminder ?? true;
      default:
        return true;
    }
  } catch (error) {
    logger.error('Error checking notification preferences:', error);
    return true; // Default to true on error
  }
}

// Helper function to send poll notifications
async function sendPollNotificationToUsers(pollId, title, body, type, poll) {
  // Get all users
  const usersSnapshot = await admin.firestore().collection('users').get();
  
  const fcmTokensSet = new Set();
  const notificationPromises = [];
  
  // Add notification to each user's collection and collect FCM tokens
  const userPromises = usersSnapshot.docs.map(async userDoc => {
    const userData = userDoc.data();
    const userId = userDoc.id;
    
    // Skip the poll creator for new poll notifications
    if (type === 'newPoll' && userId === poll.createdBy) {
      return;
    }
    
    // Check if user wants this type of notification
    const shouldNotify = await shouldNotifyUser(userId, type);
    if (!shouldNotify) return;

    // Apply class scoping
    if (poll.isAllClasses === false) {
      if (!poll.classScopes || !Array.isArray(poll.classScopes) || !userData.classYear || !poll.classScopes.includes(userData.classYear)) {
        // logger.info(`Skipping user ${userId} for poll ${pollId} due to class scope mismatch. User class: ${userData.classYear}, Poll scopes: ${poll.classScopes}`);
        return; // Skip user if not in poll's class scopes
      }
    }
    
    // Collect unique FCM tokens
    if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
      userData.fcmTokens.forEach(token => fcmTokensSet.add(token));
    }
    
    // Create a notification for the user
    const notificationRef = admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .doc();
      
    const notification = {
      id: notificationRef.id,
      type: type,
      title: title,
      message: body,
      pollId: pollId,
      isRead: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      data: {
        pollId: pollId,
        type: type,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        screen: 'poll_detail'
      }
    };
    
    return notificationRef.set(notification);
  });
  
  // Wait for all notifications to be created
  await Promise.all(userPromises);

  // Rest of the function remains the same...
  // Convert Set to Array
  const fcmTokens = Array.from(fcmTokensSet);
  
  // Send FCM messages if there are tokens
  if (fcmTokens.length > 0) {
    // Send in batches of 500 (FCM limit)
    const batchSize = 500;
    for (let i = 0; i < fcmTokens.length; i += batchSize) {
      const batch = fcmTokens.slice(i, i + batchSize);
      
      const message = {
        notification: {
          title: title,
          body: body,
        },
        data: {
          pollId: pollId,
          type: type,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          screen: 'poll_detail',
        },
        tokens: batch,
        android: {
          notification: {
            tag: pollId, // Group notifications by pollId on Android
          },
        },
        apns: {
          headers: {
            'apns-collapse-id': pollId, // Group notifications by pollId on iOS
          },
        },
      };
      
      try {
        const response = await admin.messaging().sendMulticast(message);
        logger.info(`Successfully sent notifications: ${response.successCount}/${batch.length}`);
      } catch (error) {
        logger.error('Error sending notifications:', error);
      }
    }
  }
  
  // Also send to the 'polls' topic for users who might not be registered yet
  // Only send to generic topic if it's for all classes
  if (poll.isAllClasses === true) {
    await admin.messaging().send({
      notification: {
        title: title,
        body: body,
      },
      data: {
        pollId: pollId,
        type: type,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        screen: 'poll_detail',
      },
      topic: 'polls',
      // Grouping for topic messages (less critical but good for consistency if devices support it for topics)
      android: {
        notification: {
          tag: pollId,
        },
      },
      apns: {
        headers: {
          'apns-collapse-id': pollId,
        },
      },
    });
  }
}

// Helper function to send proposal notifications
async function sendProposalNotificationToUsers(proposalId, title, body, type, proposal, replyPreview = null, replyAuthor = null, replyId = null) { // Added replyId
  // Get all users
  const usersSnapshot = await admin.firestore().collection('users').get();
  
  const fcmTokensSet = new Set();
  const notificationPromises = [];
  
  // Add notification to each user's collection and collect FCM tokens
  const userPromises = usersSnapshot.docs.map(async userDoc => {
    const userData = userDoc.data();
    const userId = userDoc.id;
    
    // Determine if this user should receive the notification
    let shouldReceive = false;
    
    switch (type) {
      case 'proposalEndorsement':
      case 'proposalEndorsementComplete':
        // Only send to proposal author
        shouldReceive = userId === proposal.authorId;
        break;
      case 'proposalReply':
        // Send to proposal author and other participants in the thread
        shouldReceive = userId === proposal.authorId || 
          (proposal.participants && proposal.participants.includes(userId));
        break;
      default:
        shouldReceive = true;
    }
    
    if (!shouldReceive) return;
    
    // Check if user wants this type of notification
    const shouldNotify = await shouldNotifyUser(userId, type);
    if (!shouldNotify) return;
    
    // Collect unique FCM tokens
    if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
      userData.fcmTokens.forEach(token => fcmTokensSet.add(token));
    }
    
    // Create a notification for the user
    const notificationRef = admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .doc();
      
    const notification = {
      id: notificationRef.id,
      type: type,
      message: body,
      proposalId: proposalId,
      isRead: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      data: {
        proposalId: proposalId,
        type: type,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        screen: 'proposal_detail',
        ...(replyPreview && { replyPreview }),
        ...(replyAuthor && { replyAuthor }),
        ...(replyId && { replyId }) // Include replyId in in-app notification data
      }
    };
    
    return notificationRef.set(notification);
  });
  
  // Wait for all notifications to be created
  await Promise.all(userPromises);

  // Rest of the function remains the same...
  // Convert Set to Array
  const fcmTokens = Array.from(fcmTokensSet);
  
  // Send FCM messages if there are tokens
  if (fcmTokens.length > 0) {
    // Send in batches of 500 (FCM limit)
    const batchSize = 500;
    for (let i = 0; i < fcmTokens.length; i += batchSize) {
      const batch = fcmTokens.slice(i, i + batchSize);
      
      const message = {
        notification: {
          title: title,
          body: body,
        },
        data: {
          proposalId: proposalId,
          type: type,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          screen: 'proposal_detail',
          ...(replyPreview && { replyPreview }),
          ...(replyAuthor && { replyAuthor }),
          ...(replyId && { replyId }) // Include replyId in FCM data payload
        },
        tokens: batch,
        android: {
          notification: {
            tag: proposalId, // Group notifications by proposalId on Android
          },
        },
        apns: {
          headers: {
            'apns-collapse-id': proposalId, // Group notifications by proposalId on iOS
          },
        },
      };
      
      try {
        const response = await admin.messaging().sendMulticast(message);
        logger.info(`Successfully sent notifications: ${response.successCount}/${batch.length}`);
      } catch (error) {
        logger.error('Error sending notifications:', error);
      }
    }
  }
  
  // Also send to the topic
  await admin.messaging().send({
    notification: {
      title: title,
      body: body,
    },
    data: {
      proposalId: proposalId,
      type: type,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      screen: 'proposal_detail',
      ...(replyPreview && { replyPreview }),
      ...(replyAuthor && { replyAuthor }),
      ...(replyId && { replyId }) // Include replyId in topic message data payload
    },
    topic: 'proposals',
    android: {
      notification: {
        tag: proposalId,
      },
    },
    apns: {
      headers: {
        'apns-collapse-id': proposalId,
      },
    },
  });
}

// Add a new function to handle scheduled poll notifications
exports.processScheduledNotifications = onSchedule({
  schedule: "every 5 minutes",
  region: "us-central1",
  memory: "256MiB",
  maxInstances: 1,
}, async (event) => {
  try {
    const now = admin.firestore.Timestamp.now();
    
    // Get notifications that are due
    const scheduledNotificationsSnapshot = await admin.firestore()
      .collection('scheduledNotifications')
      .where('scheduledFor', '<=', now)
      .get();
    
    const notificationPromises = [];
    
    scheduledNotificationsSnapshot.forEach(doc => {
      const scheduledNotification = doc.data();
      
      if (scheduledNotification.type === 'pollDeadline') {
        const pseudoPoll = {
            id: scheduledNotification.pollId,
            title: scheduledNotification.pollTitle, 
            isAllClasses: scheduledNotification.pollIsAllClasses,
            classScopes: scheduledNotification.pollClassScopes,
            createdBy: scheduledNotification.pollCreatedBy, 
        };
        notificationPromises.push(
          sendPollNotificationToUsers(
            scheduledNotification.pollId,
            scheduledNotification.title,
            scheduledNotification.body,
            scheduledNotification.type,
            pseudoPoll 
          ).then(() => {
            return doc.ref.delete();
          })
        );
      } else if (scheduledNotification.type === 'eventReminder') {
        // Construct a minimal event object for sendEventNotificationToUsers (if a similar helper exists)
        // For now, we'll adapt sendPollNotificationToUsers or create a new helper if needed.
        // This part assumes you might create a sendEventNotificationToUsers helper or adapt existing ones.
        // For simplicity, let's log it for now and you can implement the sending logic.
        // logger.info(`Processing scheduled event reminder for event ${scheduledNotification.eventId}`);
        // Example of how it might look if you had a generic sender or specific event sender
        const pseudoEvent = {
            id: scheduledNotification.eventId,
            title: scheduledNotification.eventTitle,
            isAllClasses: scheduledNotification.eventIsAllClasses,
            classScopes: scheduledNotification.eventClassScopes,
            createdBy: scheduledNotification.eventCreatedBy,
        };
        // Assuming a new or adapted helper function: sendEventNotificationToRelevantUsers
        notificationPromises.push(
          sendEventNotificationToScopedUsers(
            scheduledNotification.eventId,
            scheduledNotification.title,
            scheduledNotification.body,
            scheduledNotification.type,
            pseudoEvent
          ).then(() => {
            return doc.ref.delete();
          })
        );
      }
    });
    
    await Promise.all(notificationPromises);
    logger.info(`Processed ${notificationPromises.length} scheduled notifications.`);
    
  } catch (error) {
    logger.error('Error processing scheduled notifications:', error);
  }
});

// Helper function to send event notifications with scoping (new or adapted)
async function sendEventNotificationToScopedUsers(eventId, title, body, type, eventDetails) {
  const usersSnapshot = await admin.firestore().collection('users').get();
  const fcmTokensSet = new Set();
  const notificationCreationPromises = []; // Renamed to avoid conflict

  const userProcessingPromises = usersSnapshot.docs.map(async userDoc => {
    const userData = userDoc.data();
    const userId = userDoc.id;

    if (type === 'newEvent' && userId === eventDetails.createdBy) {
      return;
    }

    const shouldNotify = await shouldNotifyUser(userId, type);
    if (!shouldNotify) return;

    if (eventDetails.isAllClasses === false) {
      if (!eventDetails.classScopes || !Array.isArray(eventDetails.classScopes) || !userData.classYear || !eventDetails.classScopes.includes(userData.classYear)) {
        return; 
      }
    }

    if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
      userData.fcmTokens.forEach(token => fcmTokensSet.add(token));
    }

    const notificationRef = admin.firestore()
      .collection('users').doc(userId)
      .collection('notifications').doc();
      
    const notification = {
      id: notificationRef.id,
      type: type,
      title: title,
      message: body, // Changed from 'body' to 'message' to match poll notifications
      eventId: eventId,
      isRead: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      data: {
        eventId: eventId,
        type: type,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        screen: 'event_detail'
      }
    };
    notificationCreationPromises.push(notificationRef.set(notification));
  });

  await Promise.all(userProcessingPromises); // Wait for user processing to complete
  await Promise.all(notificationCreationPromises); // Then wait for notifications to be created

  const fcmTokens = Array.from(fcmTokensSet);
  if (fcmTokens.length > 0) {
    const batchSize = 500;
    for (let i = 0; i < fcmTokens.length; i += batchSize) {
      const batch = fcmTokens.slice(i, i + batchSize);
      const message = {
        notification: { title: title, body: body },
        data: { eventId: eventId, type: type, click_action: 'FLUTTER_NOTIFICATION_CLICK', screen: 'event_detail' },
        tokens: batch,
        android: {
          notification: {
            tag: eventId, // Group notifications by eventId on Android
          },
        },
        apns: {
          headers: {
            'apns-collapse-id': eventId, // Group notifications by eventId on iOS
          },
        },
      };
      try {
        const response = await admin.messaging().sendMulticast(message);
        logger.info(`Successfully sent event notifications: ${response.successCount}/${batch.length}`);
      } catch (error) {
        logger.error('Error sending event notifications:', error);
      }
    }
  }

  if (eventDetails.isAllClasses === true) {
    await admin.messaging().send({
      notification: { title: title, body: body },
      data: { eventId: eventId, type: type, click_action: 'FLUTTER_NOTIFICATION_CLICK', screen: 'event_detail' },
      topic: 'events', // Assuming a generic 'events' topic for all-class events
      android: {
        notification: {
          tag: eventId,
        },
      },
      apns: {
        headers: {
          'apns-collapse-id': eventId,
        },
      },
    });
  }
}

// Send proposal notification to users
exports.sendProposalNotification = onCall({
  maxInstances: 10,
  timeoutSeconds: 60,
  memory: "256MiB",
}, async (request) => {
  try {
    // Destructure replyId from request.data
    const { proposalId, title, body, type, replyPreview, replyAuthor, replyId, originalReplyContent, proposalTitle } = request.data;
    
    if (!proposalId || !title || !body || !type) {
      throw new HttpsError('invalid-argument', 'Proposal ID, title, body, and type are required');
    }
    
    logger.info(`Sending proposal notification for ${proposalId} of type ${type}`);
    
    // Get the proposal data
    const proposalDoc = await admin.firestore().collection('proposals').doc(proposalId).get();
    if (!proposalDoc.exists) {
      throw new HttpsError('not-found', 'Proposal not found');
    }
    
    const proposal = proposalDoc.data();
    
    // Get all users who should receive this notification
    const usersSnapshot = await admin.firestore().collection('users').get();
    
    const fcmTokensSet = new Set();
    const notificationPromises = [];
    
    // Add notification to each user's collection and collect FCM tokens
    usersSnapshot.forEach(userDoc => {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      // Determine if this user should receive the notification
      let shouldReceive = false;
      
      switch (type) {
        case 'proposalEndorsement':
        case 'proposalEndorsementComplete':
          // Only send to proposal author
          shouldReceive = userId === proposal.authorId;
          break;
        case 'proposalReply':
          // Send to proposal author and other participants in the thread
          shouldReceive = userId === proposal.authorId || 
            (proposal.participants && proposal.participants.includes(userId));
          break;
        default:
          shouldReceive = true;
      }
      
      if (!shouldReceive) return;
      
      // Collect unique FCM tokens
      if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
        userData.fcmTokens.forEach(token => fcmTokensSet.add(token));
      }
      
      // Create a notification for the user
      const notificationRef = admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc();
        
      const notification = {
        id: notificationRef.id,
        type: type,
        message: body,
        proposalId: proposalId,
        isRead: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        data: { // For in-app notification
          proposalId: proposalId,
          type: type,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          screen: 'proposal_detail',
          ...(replyPreview && { replyPreview }),
          ...(replyAuthor && { replyAuthor }),
          ...(replyId && { replyId }), // Include replyId
          ...(originalReplyContent && { originalReplyContent }),
          ...(proposalTitle && { proposalTitle })
        }
      };
      
      notificationPromises.push(notificationRef.set(notification));
    });
    
    // Wait for all notifications to be created
    await Promise.all(notificationPromises);
    
    // Convert Set to Array
    const fcmTokens = Array.from(fcmTokensSet);
    
    // Send FCM messages if there are tokens
    if (fcmTokens.length > 0) {
      // Send in batches of 500 (FCM limit)
      const batchSize = 500;
      for (let i = 0; i < fcmTokens.length; i += batchSize) {
        const batch = fcmTokens.slice(i, i + batchSize);
        
        const message = {
          notification: {
            title: title,
            body: body,
          },
          data: { // For FCM data payload
            proposalId: proposalId,
            type: type,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            screen: 'proposal_detail',
            ...(replyPreview && { replyPreview }),
            ...(replyAuthor && { replyAuthor }),
            ...(replyId && { replyId }), // Include replyId
            ...(originalReplyContent && { originalReplyContent }),
            ...(proposalTitle && { proposalTitle })
          },
          tokens: batch,
          android: {
            notification: {
              tag: proposalId, // Group notifications by proposalId on Android
            },
          },
          apns: {
            headers: {
              'apns-collapse-id': proposalId, // Group notifications by proposalId on iOS
            },
          },
        };
        
        try {
          const response = await admin.messaging().sendMulticast(message);
          logger.info(`Successfully sent notifications: ${response.successCount}/${batch.length}`);
        } catch (error) {
          logger.error('Error sending notifications:', error);
        }
      }
    }
    
    return { success: true, message: 'Proposal notifications sent successfully' };
  } catch (error) {
    logger.error('Error in sendProposalNotification:', error);
    throw new HttpsError('internal', error.message);
  }
});

// Auto-notify for proposal endorsements and replies
exports.autoProposalNotifications = onDocumentWritten({
  document: "proposals/{proposalId}",
  region: "us-central1",
}, async (event) => {
  try {
    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();
    const proposalId = event.params.proposalId;
    
    if (!afterData) return;
    
    // Handle endorsement milestones
    if (beforeData && beforeData.endorsements?.length !== afterData.endorsements?.length) {
      const endorsementCount = afterData.endorsements?.length || 0;
      const requiredEndorsements = afterData.requiredEndorsements || 10;
      const milestone = Math.floor((endorsementCount / requiredEndorsements) * 100);
      
      // Send milestone notifications at 25%, 50%, 75%
      if (milestone === 25 || milestone === 50 || milestone === 75) {
        await admin.firestore().collection('system').doc('functions').set({
          operation: 'sendProposalNotification',
          params: {
            proposalId: proposalId,
            title: 'Endorsement Milestone Reached',
            body: `Your proposal "${afterData.title}" has reached ${milestone}% of required endorsements!`,
            type: 'proposalEndorsement'
          },
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      
      // Send completion notification at 100%
      if (endorsementCount >= requiredEndorsements && 
          (!beforeData.endorsements || beforeData.endorsements.length < requiredEndorsements)) {
        await admin.firestore().collection('system').doc('functions').set({
          operation: 'sendProposalNotification',
          params: {
            proposalId: proposalId,
            title: 'Proposal Fully Endorsed',
            body: `Your proposal "${afterData.title}" has received all required endorsements!`,
            type: 'proposalEndorsementComplete'
          },
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
  } catch (error) {
    logger.error('Error in autoProposalNotifications:', error);
  }
});

// Handle new replies to proposals
exports.handleNewProposalReply = onDocumentCreated({
  document: "proposals/{proposalId}/replies/{replyId}",
  region: "us-central1",
}, async (event) => {
  try {
    const reply = event.data?.data();
    if (!reply) return;
    
    const proposalId = event.params.proposalId;
    const replyId = event.params.replyId; // Capture replyId
    
    // Get the proposal to include its title in the notification
    const proposalDoc = await admin.firestore().collection('proposals').doc(proposalId).get();
    if (!proposalDoc.exists) return;
    const proposal = proposalDoc.data();
    
    // Get the reply author's name
    const authorDoc = await admin.firestore().collection('users').doc(reply.authorId).get();
    const authorName = authorDoc.exists ? authorDoc.data().displayName : 'Someone';
    
    // Format a preview of the reply, truncate if too long
    const replyPreview = reply.content.length > 100 
      ? reply.content.substring(0, 97) + '...'
      : reply.content;

    // Twitter-style notification content
    const proposalTitlePreview = proposal.title.length > 25 ? proposal.title.substring(0, 22) + "..." : proposal.title;
    const notificationTitle = `Reply from ${authorName} on "${proposalTitlePreview}"`;
    const notificationBody = `"${replyPreview}"`;
    
    // Trigger the sendProposalNotification callable function (or helper)
    // Ensure all necessary params, including replyId, are passed
    const notificationParams = {
      proposalId: proposalId,
      title: notificationTitle,
      body: notificationBody,
      type: 'proposalReply',
      replyId: replyId, // Ensure replyId is here
      replyPreview: replyPreview,
      replyAuthor: authorName,
      originalReplyContent: reply.content,
      proposalTitle: proposal.title
    };

    // Option 1: Call a helper function directly if appropriate
    // await sendProposalNotificationToUsers(proposalId, notificationTitle, notificationBody, 'proposalReply', proposal, replyPreview, authorName, replyId);

    // Option 2: Trigger via system/functions document (current approach)
    await admin.firestore().collection('system').doc('functions').set({
      operation: 'sendProposalNotification', // This should trigger the callable function
      params: notificationParams,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    logger.info(`Triggered proposal reply notification for proposal ${proposalId}, reply ${replyId}`);
    
  } catch (error) {
    logger.error('Error in handleNewProposalReply:', error);
  }
});

// Send event notification to all users
exports.sendEventNotification = onCall({
  maxInstances: 10,
  timeoutSeconds: 60,
  memory: "256MiB",
}, async (request) => {
  try {
    const { eventId, title, body, type } = request.data;
    
    if (!eventId || !title || !body) {
      throw new HttpsError('invalid-argument', 'Event ID, title, and body are required');
    }
    
    logger.info(`Sending event notification for ${eventId}`);
    
    // Get the event data
    const eventDoc = await admin.firestore().collection('events').doc(eventId).get();
    if (!eventDoc.exists) {
      throw new HttpsError('not-found', 'Event not found');
    }
    
    const event = eventDoc.data();
    
    // Get all users
    const usersSnapshot = await admin.firestore().collection('users').get();
    
    const fcmTokensSet = new Set();
    const notificationPromises = [];
    
    // Add notification to each user's collection and collect FCM tokens
    usersSnapshot.forEach(userDoc => {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      // Skip the event creator
      if (userId === event.createdBy) {
        return;
      }
      
      // Collect unique FCM tokens
      if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
        userData.fcmTokens.forEach(token => fcmTokensSet.add(token));
      }
      
      // Create a notification for the user
      const notificationRef = admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc();
        
      const notification = {
        id: notificationRef.id,
        type: type || 'event',
        title: title,
        message: body,
        eventId: eventId,
        isRead: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        data: {
          eventId: eventId,
          type: type || 'event',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          screen: 'event_detail',
        }
      };
      
      notificationPromises.push(notificationRef.set(notification));
    });
    
    // Wait for all notifications to be created
    await Promise.all(notificationPromises);
    
    // Convert Set to Array
    const fcmTokens = Array.from(fcmTokensSet);
    
    // Send FCM messages if there are tokens
    if (fcmTokens.length > 0) {
      // Send in batches of 500 (FCM limit)
      const batchSize = 500;
      for (let i = 0; i < fcmTokens.length; i += batchSize) {
        const batch = fcmTokens.slice(i, i + batchSize);
        
        const message = {
          notification: {
            title: title,
            body: body,
          },
          data: {
            eventId: eventId,
            type: type || 'event',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            screen: 'event_detail',
          },
          tokens: batch,
          android: {
            notification: {
              tag: eventId, // Group notifications by eventId on Android
            },
          },
          apns: {
            headers: {
              'apns-collapse-id': eventId, // Group notifications by eventId on iOS
            },
          },
        };
        
        try {
          const response = await admin.messaging().sendMulticast(message);
          logger.info(`Successfully sent notifications: ${response.successCount}/${batch.length}`);
        } catch (error) {
          logger.error('Error sending notifications:', error);
        }
      }
    }
    
    // Also send to the 'events' topic for users who might not be registered yet
    await admin.messaging().send({
      notification: {
        title: title,
        body: body,
      },
      data: {
        eventId: eventId,
        type: type || 'event',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        screen: 'event_detail',
      },
      topic: 'events',
      android: {
        notification: {
          tag: eventId,
        },
      },
      apns: {
        headers: {
          'apns-collapse-id': eventId,
        },
      },
    });
    
    return { success: true, message: 'Event notifications sent successfully' };
  } catch (error) {
    logger.error('Error in sendEventNotification:', error);
    throw new HttpsError('internal', error.message);
  }
});

// Auto-notify when a new event is created
exports.autoNotifyNewEvent = onDocumentCreated({
  document: "events/{eventId}",
  region: "us-central1",
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    logger.info("No data associated with the event");
    return;
  }
  
  const eventData = snapshot.data();
  const eventId = snapshot.id;
  
  try {
    // Get all users
    const usersSnapshot = await admin.firestore().collection('users').get();
    
    const fcmTokensSet = new Set();
    const notificationPromises = [];
    
    // Add notification to each user's collection and collect FCM tokens
    const userPromises = usersSnapshot.docs.map(async userDoc => {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      // Skip the event creator
      if (userId === eventData.createdBy) {
        return;
      }
      
      // Check if user wants this type of notification
      const shouldNotify = await shouldNotifyUser(userId, 'newEvent');
      if (!shouldNotify) return;

      // Apply class scoping for events
      if (eventData.isAllClasses === false) {
        if (!eventData.classScopes || !Array.isArray(eventData.classScopes) || !userData.classYear || !eventData.classScopes.includes(userData.classYear)) {
          // logger.info(`Skipping user ${userId} for event ${eventId} due to class scope mismatch. User class: ${userData.classYear}, Event scopes: ${eventData.classScopes}`);
          return; // Skip user if not in event's class scopes
        }
      }
      
      // Collect unique FCM tokens
      if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
        userData.fcmTokens.forEach(token => fcmTokensSet.add(token));
      }
      
      // Create a notification for the user
      const notificationRef = admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc();
        
      const notification = {
        id: notificationRef.id,
        type: 'newEvent',
        title: 'New Event Added',
        message: `"${eventData.title}" has been added to the calendar.`,
        eventId: eventId,
        isRead: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        data: {
          eventId: eventId,
          type: 'newEvent',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          screen: 'event_detail',
        }
      };
      
      return notificationRef.set(notification);
    });
    
    // Wait for all notifications to be created
    await Promise.all(userPromises);
    
    // Convert Set to Array
    const fcmTokens = Array.from(fcmTokensSet);
    
    // Send FCM messages if there are tokens
    if (fcmTokens.length > 0) {
      // Send in batches of 500 (FCM limit)
      const batchSize = 500;
      for (let i = 0; i < fcmTokens.length; i += batchSize) {
        const batch = fcmTokens.slice(i, i + batchSize);
        
        const message = {
          notification: {
            title: 'New Event Added',
            body: `"${eventData.title}" has been added to the calendar.`,
          },
          data: {
            eventId: eventId,
            type: 'newEvent',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            screen: 'event_detail',
          },
          tokens: batch,
        };
        
        try {
          const response = await admin.messaging().sendMulticast(message);
          logger.info(`Successfully sent notifications: ${response.successCount}/${batch.length}`);
        } catch (error) {
          logger.error('Error sending notifications:', error);
        }
      }
    }
    
    // Also send to the 'events' topic for users who might not be registered yet
    // Only send to generic topic if it's for all classes
    if (eventData.isAllClasses === true) {
      await admin.messaging().send({
        notification: {
          title: 'New Event Added',
          body: `"${eventData.title}" has been added to the calendar.`,
        },
        data: {
          eventId: eventId,
          type: 'newEvent',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          screen: 'event_detail',
        },
        topic: 'events',
        android: {
          notification: {
            tag: eventId,
          },
        },
        apns: {
          headers: {
            'apns-collapse-id': eventId,
          },
        },
      });
    }
    
    // Schedule reminder notification if there's a start date
    if (eventData.startDate) {
      const startDate = eventData.startDate.toDate();
      const notifyBefore = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
      const notifyAt = new Date(startDate.getTime() - notifyBefore);
      
      if (notifyAt > new Date()) {
        // Store the scheduled notification
        await admin.firestore().collection('scheduledNotifications').doc().set({
          eventId: eventId,
          type: 'eventReminder',
          scheduledFor: notifyAt,
          title: 'Event Reminder',
          body: `"${eventData.title}" will start in 24 hours.`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          // Store necessary event scoping info for when the scheduled notification is processed
          eventIsAllClasses: eventData.isAllClasses,
          eventClassScopes: eventData.classScopes || [],
          eventTitle: eventData.title, // Store title for constructing message later
          eventCreatedBy: eventData.createdBy, // Store creator to avoid self-notification if needed 
          data: {
            eventId: eventId,
            type: 'eventReminder',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            screen: 'event_detail',
          }
        });
        
        logger.info(`Scheduled reminder notification for event ${eventId}`);
      }
    }
    
    logger.info(`Triggered event notification for ${eventId}`);
  } catch (error) {
    logger.error('Error triggering event notification:', error);
  }
});
