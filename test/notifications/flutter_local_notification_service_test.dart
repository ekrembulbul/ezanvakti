import 'package:ezanvakti/features/notifications/data/flutter_local_notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Eklentinin yalnız iptal yollarını kaydeden sahtesi.
class _RecordingPlugin extends Fake implements FlutterLocalNotificationsPlugin {
  _RecordingPlugin(this.pending);

  final List<PendingNotificationRequest> pending;
  final List<int> cancelledIds = [];
  int cancelAllCalls = 0;

  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => pending;

  @override
  Future<void> cancel(int id, {String? tag}) async => cancelledIds.add(id);

  @override
  Future<void> cancelAll() async => cancelAllCalls++;
}

void main() {
  const pending = [
    PendingNotificationRequest(101, 'Öğle', null, null),
    PendingNotificationRequest(202, 'İkindi', null, null),
  ];

  group('cancelAllNotifications', () {
    test('Android: yalnız planlanmış bildirimleri iptal eder, ekrandakilere '
        '(sıradaki vakit kalıcı bildirimi dahil) dokunmaz', () async {
      final plugin = _RecordingPlugin(pending);
      final service = FlutterLocalNotificationService(
        plugin: plugin,
        isAndroid: true,
      );

      await service.cancelAllNotifications();

      expect(plugin.cancelAllCalls, 0);
      expect(plugin.cancelledIds, [101, 202]);
    });

    test('iOS: davranış değişmez, hepsi tek çağrıyla temizlenir', () async {
      final plugin = _RecordingPlugin(pending);
      final service = FlutterLocalNotificationService(
        plugin: plugin,
        isAndroid: false,
      );

      await service.cancelAllNotifications();

      expect(plugin.cancelAllCalls, 1);
      expect(plugin.cancelledIds, isEmpty);
    });
  });
}
