import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/general_settings.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';

/// Planlayici testleri icin bellek-ici depo.
class NotificationTestStorage implements LocalStorage {
  List<NotificationSetting> settings = [];
  GeneralSettings general = const GeneralSettings();

  @override
  Future<List<NotificationSetting>> getNotificationSettings() async => settings;

  @override
  Future<GeneralSettings> getGeneralSettings() async => general;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('NotificationTestStorage.${invocation.memberName}');
}
