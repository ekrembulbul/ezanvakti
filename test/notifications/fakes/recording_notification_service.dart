import 'package:ezanvakti/core/interfaces/notification_service.dart';

typedef RecordedNotification = ({
  String id,
  DateTime scheduledTime,
  String title,
  String body,
  String? soundId,
  bool silent,
  bool timeSensitive,
});

/// Planlanan bildirimleri butun argumanlariyla kaydeden servis.
class RecordingNotificationService implements NotificationService {
  final List<RecordedNotification> calls = [];
  int cancelAllCount = 0;

  @override
  Future<void> scheduleNotification({
    required String id,
    required DateTime scheduledTime,
    required String title,
    required String body,
    String? soundId,
    bool silent = false,
    bool timeSensitive = true,
  }) async {
    calls.add((
      id: id,
      scheduledTime: scheduledTime,
      title: title,
      body: body,
      soundId: soundId,
      silent: silent,
      timeSensitive: timeSensitive,
    ));
  }

  @override
  Future<void> cancelAllNotifications() async => cancelAllCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
