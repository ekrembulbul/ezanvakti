import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/quiet_window.dart';
import 'package:ezanvakti/core/models/general_settings.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';

/// Planlayici testleri icin bellek-ici depo.
class NotificationTestStorage implements LocalStorage {

  List<QuietWindow> quietWindows = [];

  @override
  Future<List<QuietWindow>> getQuietWindows() async => quietWindows;

  @override
  Future<void> saveQuietWindows(List<QuietWindow> windows) async =>
      quietWindows = windows;
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
