import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_badge_plus/app_badge_plus.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static int badgeCount = 0;

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    final settings = InitializationSettings(
      android: android,
      linux: LinuxInitializationSettings(defaultActionName: 'open'),
    );

    await _plugin.initialize(settings);
  }

  static Future<void> showGameMessage(String message) async {
    badgeCount++;

    await AppBadgePlus.updateBadge(badgeCount);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'scrabble_game',
        'Scrabble',
        channelDescription: 'Coups reçus',
        importance: Importance.high,
        priority: Priority.high,
      ),

      linux: LinuxNotificationDetails(),
    );

    await _plugin.show(badgeCount, 'Scrabble', '$message', details);
  }

  static Future<void> clearBadge() async {
    badgeCount = 0;

    await AppBadgePlus.updateBadge(0);
  }
}
