import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:cloud_functions/cloud_functions.dart';
import '../config/router_config.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../models/notification.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Channel IDs
  static const String pollChannelId = 'poll_notifications';
  static const String proposalChannelId = 'proposal_notifications';
  static const String articleChannelId = 'article_notifications';
  static const String eventChannelId = 'event_notifications';

  Future<void> initialize() async {
    // Skip notification initialization for web platform
    if (kIsWeb) {
      debugPrint('Skipping notification initialization for web platform');
      return;
    }

    // Request notification permissions only for mobile platforms
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Create notification channels for Android
    if (!kIsWeb && Platform.isAndroid) {
      await _createNotificationChannels();
    }

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    // Get FCM token and save it
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmTokens': FieldValue.arrayUnion([token]),
        });
      }
    }

    // Subscribe to topics for broadcast messages
    await _firebaseMessaging.subscribeToTopic('polls');
    await _firebaseMessaging.subscribeToTopic('articles');
    await _firebaseMessaging.subscribeToTopic('proposals');
    await _firebaseMessaging.subscribeToTopic('events');

    // Set up Firebase Messaging handlers
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request notification permissions on Android
    if (!kIsWeb && Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> _createNotificationChannels() async {
    // Poll notifications channel
    const AndroidNotificationChannel pollChannel = AndroidNotificationChannel(
      pollChannelId,
      'Poll Notifications',
      description: 'Notifications for new polls and poll deadlines',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      ledColor: Color(0xFF2234FF),
    );

    // Proposal notifications channel
    const AndroidNotificationChannel proposalChannel = AndroidNotificationChannel(
      proposalChannelId,
      'Proposal Notifications',
      description: 'Notifications for proposal endorsements and replies',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      ledColor: Color(0xFF9C27B0),
    );

    // Add article channel
    const AndroidNotificationChannel articleChannel = AndroidNotificationChannel(
      articleChannelId,
      'Article Notifications',
      description: 'Notifications for new articles',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      ledColor: Color(0xFF4CAF50),
    );

    // Add event channel
    const AndroidNotificationChannel eventChannel = AndroidNotificationChannel(
      eventChannelId,
      'Event Notifications',
      description: 'Notifications for new events and event reminders',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      ledColor: Color(0xFFFFA000),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(pollChannel);
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(proposalChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(articleChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(eventChannel);
  }

  void _handleNotificationTap(NotificationResponse details) {
    if (details.payload != null) {
      final payloadData = Uri.splitQueryString(details.payload!);
      if (payloadData['pollId'] != null) {
        router.go('/?tab=polls&highlight=${payloadData['pollId']}');
      } else if (payloadData['proposalId'] != null) {
        router.go('/proposals/${payloadData['proposalId']}');
      } else if (payloadData['articleId'] != null) {
        router.push('/articles/${payloadData['articleId']}');
      } else if (payloadData['eventId'] != null) {
        router.push('/events/${payloadData['eventId']}');
      }
    }
  }

  Future<void> showPollNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    try {
      // Check notification settings based on type
      final prefs = await SharedPreferences.getInstance();
      final notificationType = payload['type'] as String?;
      bool shouldNotify = true;

      switch (notificationType) {
        case 'newPoll':
          shouldNotify = prefs.getBool('notifyNewPoll') ?? true;
          break;
        case 'pollDeadline':
          shouldNotify = prefs.getBool('notifyPollDeadline') ?? true;
          break;
        case 'pollResults':
          shouldNotify = prefs.getBool('notifyPollResults') ?? true;
          break;
      }

      if (!shouldNotify) return;

      final androidDetails = AndroidNotificationDetails(
        pollChannelId,
        'Poll Notifications',
        channelDescription: 'Notifications for new polls and poll deadlines',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFF2234FF),
      );

      final iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
        payload: Uri(queryParameters: payload.map(
          (key, value) => MapEntry(key, value.toString()),
        )).query,
      );
      debugPrint('Successfully showed notification: $title');
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  Future<void> showPollDeadlineNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    await showPollNotification(
      title: title,
      body: body,
      payload: payload,
    );
  }

  Future<void> showPollExpiredNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    await showPollNotification(
      title: title,
      body: body,
      payload: payload,
    );
  }

  Future<void> showProposalEndorsementNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    try {
      // Check notification settings based on type
      final prefs = await SharedPreferences.getInstance();
      final notificationType = payload['type'] as String?;
      bool shouldNotify = true;

      switch (notificationType) {
        case 'proposalEndorsement':
          shouldNotify = prefs.getBool('notifyProposalEndorsement') ?? true;
          break;
        case 'proposalEndorsementComplete':
          shouldNotify = prefs.getBool('notifyProposalEndorsementComplete') ?? true;
          break;
        case 'proposalReply':
          shouldNotify = prefs.getBool('notifyProposalReply') ?? true;
          break;
      }

      if (!shouldNotify) return;

      final androidDetails = AndroidNotificationDetails(
        proposalChannelId,
        'Proposal Notifications',
        channelDescription: 'Notifications for proposal endorsements and replies',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFF9C27B0),
      );

      final iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
        payload: Uri(queryParameters: payload.map(
          (key, value) => MapEntry(key, value.toString()),
        )).query,
      );
      debugPrint('Successfully showed proposal notification: $title');
    } catch (e) {
      debugPrint('Error showing proposal notification: $e');
    }
  }

  Future<void> showProposalReplyNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    await showProposalEndorsementNotification(
      title: title,
      body: body,
      payload: payload,
    );
  }

  Future<void> showArticleNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    try {
      // Check notification settings
      final prefs = await SharedPreferences.getInstance();
      final shouldNotify = prefs.getBool('notifyArticle') ?? true;
      if (!shouldNotify) return;

      final androidDetails = AndroidNotificationDetails(
        articleChannelId,
        'Article Notifications',
        channelDescription: 'Notifications for new articles',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFF4CAF50),
      );

      final iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
        payload: Uri(queryParameters: payload.map(
          (key, value) => MapEntry(key, value.toString()),
        )).query,
      );
      debugPrint('Successfully showed article notification: $title');
    } catch (e) {
      debugPrint('Error showing article notification: $e');
    }
  }

  Future<void> showEventNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    try {
      // Check notification settings based on type
      final prefs = await SharedPreferences.getInstance();
      final notificationType = payload['type'] as String?;
      bool shouldNotify = true;

      switch (notificationType) {
        case 'newEvent':
          shouldNotify = prefs.getBool('notifyNewEvent') ?? true;
          break;
        case 'eventReminder':
          shouldNotify = prefs.getBool('notifyEventReminder') ?? true;
          break;
      }

      if (!shouldNotify) return;

      final androidDetails = AndroidNotificationDetails(
        eventChannelId,
        'Event Notifications',
        channelDescription: 'Notifications for new events and event reminders',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFFFFA000),
      );

      final iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
        payload: Uri(queryParameters: payload.map(
          (key, value) => MapEntry(key, value.toString()),
        )).query,
      );
      debugPrint('Successfully showed event notification: $title');
    } catch (e) {
      debugPrint('Error showing event notification: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (message.notification != null) {
      switch(message.data['type']) {
        case 'article':
          await showArticleNotification(
            title: message.notification!.title ?? 'New Article Available',
            body: message.notification!.body ?? '',
            payload: message.data,
          );
          break;
        case 'proposalEndorsement':
        case 'proposalEndorsementComplete':
        case 'proposalReply':
          await showProposalEndorsementNotification(
            title: message.notification!.title ?? 'Proposal Update',
            body: message.notification!.body ?? '',
            payload: message.data,
          );
          break;
        case 'newEvent':
        case 'eventReminder':
          await showEventNotification(
            title: message.notification!.title ?? 'Event Update',
            body: message.notification!.body ?? '',
            payload: message.data,
          );
          break;
        default:
          await showPollNotification(
            title: message.notification!.title ?? 'New Poll',
            body: message.notification!.body ?? '',
            payload: message.data,
          );
      }
    }
  }

  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    if (message.data['pollId'] != null) {
      router.go('/?tab=polls&highlight=${message.data['pollId']}');
    } else if (message.data['proposalId'] != null) {
      router.go('/proposals/${message.data['proposalId']}');
    } else if (message.data['articleId'] != null) {
      router.push('/articles/${message.data['articleId']}');
    } else if (message.data['eventId'] != null) {
      router.push('/events/${message.data['eventId']}');
    }
  }

  Stream<List<UserNotification>> getNotifications() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserNotification.fromFirestore(doc))
            .toList());
  }

  Future<void> markAsRead(String notificationId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final batch = _firestore.batch();
    final notifications = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  Future<void> checkForPendingNotifications() async {
    // This is used to check for poll deadlines periodically
    // Implementation is in the PollService
  }
}

// This needs to be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background handler
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  if (message.notification != null) {
    final notification = NotificationService();
    
    // Handle different notification types
    switch(message.data['type']) {
      case 'article':
        await notification.showArticleNotification(
          title: message.notification!.title ?? 'New Article Available',
          body: message.notification!.body ?? '',
          payload: message.data,
        );
        break;
      case 'proposalEndorsement':
      case 'proposalEndorsementComplete':
      case 'proposalReply':
        await notification.showProposalEndorsementNotification(
          title: message.notification!.title ?? 'Proposal Update',
          body: message.notification!.body ?? '',
          payload: message.data,
        );
        break;
      case 'newEvent':
      case 'eventReminder':
        await notification.showEventNotification(
          title: message.notification!.title ?? 'Event Update',
          body: message.notification!.body ?? '',
          payload: message.data,
        );
        break;
      default:
        await notification.showPollNotification(
          title: message.notification!.title ?? 'New Poll',
          body: message.notification!.body ?? '',
          payload: message.data,
        );
    }
  }
}