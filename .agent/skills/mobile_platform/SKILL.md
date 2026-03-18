# Mobile Platform (iOS & Android)

---

## 1. Android Configuration

### Theory
Android requires explicit permission declarations in `AndroidManifest.xml`. FeedFlow needs three critical ones:
- `INTERNET` — to fetch RSS feeds and call Supabase
- `RECEIVE_BOOT_COMPLETED` — so workmanager can re-register background tasks after device restart
- `POST_NOTIFICATIONS` — required on Android 13+ (API 33) to show push notifications

The `<application>` block also needs the workmanager initializer declared as a service.

### Code Examples

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  <!-- Exact alarm for precise notification timing (optional) -->
  <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>

  <application
    android:label="FeedFlow"
    android:icon="@mipmap/ic_launcher">

    <activity
      android:name=".MainActivity"
      android:exported="true"
      android:launchMode="singleTop">
      <!-- Deep link intent filter -->
      <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="feedflow" android:host="article"/>
      </intent-filter>
    </activity>

    <!-- WorkManager initializer -->
    <provider
      android:name="androidx.startup.InitializationProvider"
      android:authorities="${applicationId}.androidx-startup"
      android:exported="false">
      <meta-data
        android:name="androidx.work.WorkManagerInitializer"
        android:value="androidx.startup"/>
    </provider>

  </application>
</manifest>
```

```kotlin
// android/app/build.gradle — ensure minSdk is 26+
android {
    defaultConfig {
        minSdk = 26
        targetSdk = 34
    }
}
```

---

## 2. iOS Configuration

### Theory
iOS is stricter about permissions. You must declare usage descriptions in `Info.plist` — Apple rejects apps that request permissions without a human-readable reason string. For FeedFlow:
- `NSAppTransportSecurity` — allows HTTP URLs in the in-app browser (RSS feeds often use HTTP)
- Notification permission — requested at runtime via the notifications plugin
- Background fetch — enables workmanager background execution on iOS

### Code Examples

```xml
<!-- ios/Runner/Info.plist -->
<dict>
  <!-- Allow HTTP for RSS feeds that don't use HTTPS -->
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
  </dict>

  <!-- Background fetch for workmanager -->
  <key>UIBackgroundModes</key>
  <array>
    <string>fetch</string>
    <string>processing</string>
  </array>

  <!-- Deep linking URL scheme -->
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>feedflow</string>
      </array>
    </dict>
  </array>
</dict>
```

```swift
// ios/Runner/AppDelegate.swift
import Flutter
import UIKit
import workmanager

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Register workmanager for iOS background tasks
    WorkmanagerPlugin.registerTask(withIdentifier: "feedflow.backgroundSync")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

---

## 3. workmanager — Background Sync

### Theory
`workmanager` schedules periodic background tasks that run even when the app is closed. Key points:
- On Android it uses `WorkManager` (Jetpack). On iOS it uses `BGTaskScheduler`.
- Tasks run in a **separate Dart isolate** — you must re-initialise all dependencies (Isar, Supabase, dio) inside the task because the main app's singletons are not available.
- `ExistingWorkPolicy.replace` ensures only one sync task is ever scheduled, preventing duplicates.

### Code Examples

```dart
// main.dart — register the dispatcher before runApp
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await scheduleBackgroundSync();
  runApp(const ProviderScope(child: FeedFlowApp()));
}

Future<void> scheduleBackgroundSync() async {
  await Workmanager().registerPeriodicTask(
    'feedflow.backgroundSync',
    'backgroundSync',
    frequency: const Duration(hours: 1), // minimum 15 min on Android
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}

// background_sync_service.dart — runs in isolated context
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // Re-init everything — different isolate
    final isar = await Isar.open([
      FeedSourceSchema, ArticleSchema, AppSettingsSchema
    ]);
    final dio = Dio();
    final syncService = BackgroundSyncService(isar: isar, dio: dio);
    await syncService.syncAllFeeds();
    return true;
  });
}
```

---

## 4. flutter_local_notifications — Push Notifications

### Theory
`flutter_local_notifications` fires on-device notifications — no server required. Key setup:
- **Android** requires a notification channel (introduced in Android 8). Each channel has its own importance level, sound, and vibration settings.
- **iOS** requires runtime permission request before showing any notification.
- Notification payloads carry a `payload` string — use this to pass the article ID for deep linking.

### Code Examples

```dart
// notification_service.dart
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onTap,
    );

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      'feedflow_new_articles',
      'New Articles',
      description: 'Notifications for new RSS articles',
      importance: Importance.high,
    );
    await _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  }

  static Future<void> showNewArticle(Article article) async {
    await _plugin.show(
      article.id,
      article.feedSourceName,
      article.title,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'feedflow_new_articles',
          'New Articles',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'article:${article.id}', // used for deep link on tap
    );
  }

  // Navigate to article when notification is tapped
  static void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.startsWith('article:')) {
      final id = payload.split(':').last;
      router.push('/article/$id');
    }
  }
}
```

---

## 5. Deep Linking

### Theory
Deep links let a notification tap open a specific screen. FeedFlow uses a custom URL scheme (`feedflow://article/42`). GoRouter handles the routing once the app receives the link.

### Code Examples

```dart
// GoRouter deep link config (already shown in Skill 1)
// In main.dart, pass the router to MaterialApp.router
MaterialApp.router(
  routerConfig: router,
  // GoRouter handles deep links automatically via the scheme registered
  // in AndroidManifest and Info.plist
)

// To trigger a deep link from notification payload:
void handleNotificationTap(String payload) {
  // payload = 'article:42'
  final id = payload.split(':').last;
  router.push('/article/$id');
}
```

---

## Resources

| Topic | Link |
|---|---|
| Android permissions | https://developer.android.com/guide/topics/permissions/overview |
| iOS Info.plist keys | https://developer.apple.com/documentation/bundleresources/information_property_list |
| workmanager pub | https://pub.dev/packages/workmanager |
| flutter_local_notifications | https://pub.dev/packages/flutter_local_notifications |
| GoRouter deep linking | https://pub.dev/documentation/go_router/latest/topics/Deep%20linking-topic.html |
| Background execution limits | https://developer.android.com/about/versions/oreo/background |