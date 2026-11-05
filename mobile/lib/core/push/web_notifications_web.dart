import 'package:web/web.dart' as web;

String get notificationPermission => web.Notification.permission;

void showNotification(String title, String body) {
  if (web.Notification.permission != 'granted') return;

  web.Notification(
    title,
    web.NotificationOptions(body: body, icon: '/icons/Icon-192.png'),
  );
}
