import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../../../core/interfaces/widget_publisher.dart';
import '../../../core/models/appearance_settings.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/widget_appearance.dart';
import '../domain/widget_snapshot.dart';

/// Snapshot'ı widget deposuna yazıp yeniden çizim tetikleyen ince kabuk.
///
/// iOS'ta App Group + WidgetKit reload; Android'de `home_widget`'ın
/// SharedPreferences deposu + sağlayıcıya güncelleme yayını. Android sağlayıcısı
/// yayını aldığında widget'ları **ve** sabit "sıradaki vakit" satırını tazeler.
///
/// Payload **tek key altında tek JSON string** olarak yazılır: çok sayıda düz
/// key, kısmi yazımda widget'a tutarsız veri gösterirdi.
///
/// Platform ayrımı bilerek burada değil, DI'da yapılır — guard sınıfın içinde
/// olsaydı test host'u macOS'ta koştuğu için bu sınıf hiç sınanamazdı.
class HomeWidgetPublisher implements WidgetPublisher {
  static const String appGroupId = 'group.com.ekrembulbul.ezanvakti';
  static const String snapshotKey = 'ezanvakti_snapshot';

  /// Swift tarafındaki `SnapshotStore.timeFormatKey` ile birebir aynı.
  static const String timeFormatKey = 'ezanvakti_time_format';

  /// Swift tarafındaki `SnapshotStore.appearanceKey` ile birebir aynı.
  static const String appearanceKey = 'ezanvakti_appearance';

  /// Swift tarafındaki `kind` ile birebir aynı olmalı; aksi halde reload
  /// sessizce hiçbir widget'a ulaşmaz.
  static const String widgetKind = 'EzanVaktiWidget';

  /// Android sağlayıcısının tam sınıf adı (`EzanWidgetProvider.kt`).
  static const String androidProvider =
      'com.ekrembulbul.ezanvakti.widget.EzanWidgetProvider';

  /// Kotlin `WidgetStore` ile birebir aynı.
  static const String nextPrayerNotificationKey =
      'ezanvakti_next_prayer_notification';

  final AppLogger _logger;

  HomeWidgetPublisher({required AppLogger logger}) : _logger = logger;

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    await HomeWidget.setAppGroupId(appGroupId);
    await HomeWidget.saveWidgetData<String>(
      snapshotKey,
      jsonEncode(snapshot.toJson()),
    );
    await _reload();

    _logger.debug('Widget snapshot published: ${snapshot.days.length} days');
  }

  @override
  Future<void> publishTimeFormat(String storageValue) async {
    await HomeWidget.setAppGroupId(appGroupId);
    await HomeWidget.saveWidgetData<String>(timeFormatKey, storageValue);
    await _reload();
    _logger.debug('Widget time format published: $storageValue');
  }

  @override
  Future<void> publishAppearance(AppearanceSettings settings) async {
    await HomeWidget.setAppGroupId(appGroupId);
    await HomeWidget.saveWidgetData<String>(
      appearanceKey,
      jsonEncode(widgetAppearanceJson(settings)),
    );
    await _reload();
    _logger.debug('Widget appearance published: $settings');
  }

  @override
  Future<void> publishNextPrayerNotification(bool enabled) async {
    await HomeWidget.setAppGroupId(appGroupId);
    await HomeWidget.saveWidgetData<String>(
      nextPrayerNotificationKey,
      enabled.toString(),
    );
    await _reload();
    _logger.debug('Next prayer notification published: $enabled');
  }

  /// İki platformun yeniden çizimi tek çağrıda; paket her platformda yalnız
  /// kendi adını kullanır.
  Future<void> _reload() => HomeWidget.updateWidget(
    iOSName: widgetKind,
    qualifiedAndroidName: androidProvider,
  );
}

/// iOS ve Android dışındaki platformlarda (masaüstü, test) kullanılır;
/// yayınlama sessizce atlanır.
class NoopWidgetPublisher implements WidgetPublisher {
  const NoopWidgetPublisher();

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {}

  @override
  Future<void> publishTimeFormat(String storageValue) async {}

  @override
  Future<void> publishAppearance(AppearanceSettings settings) async {}

  @override
  Future<void> publishNextPrayerNotification(bool enabled) async {}
}
