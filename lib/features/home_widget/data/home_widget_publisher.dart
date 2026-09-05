import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../../../core/interfaces/widget_publisher.dart';
import '../../../core/models/appearance_settings.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/widget_appearance.dart';
import '../domain/widget_snapshot.dart';

/// Snapshot'ı App Group'a yazıp WidgetKit'e reload tetikleyen ince kabuk.
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

  final AppLogger _logger;

  HomeWidgetPublisher({required AppLogger logger}) : _logger = logger;

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    await HomeWidget.setAppGroupId(appGroupId);
    await HomeWidget.saveWidgetData<String>(
      snapshotKey,
      jsonEncode(snapshot.toJson()),
    );
    await HomeWidget.updateWidget(iOSName: widgetKind);

    _logger.debug('Widget snapshot published: ${snapshot.days.length} days');
  }

  @override
  Future<void> publishTimeFormat(String storageValue) async {
    await HomeWidget.setAppGroupId(appGroupId);
    await HomeWidget.saveWidgetData<String>(timeFormatKey, storageValue);
    await HomeWidget.updateWidget(iOSName: widgetKind);
    _logger.debug('Widget time format published: $storageValue');
  }

  @override
  Future<void> publishAppearance(AppearanceSettings settings) async {
    await HomeWidget.setAppGroupId(appGroupId);
    await HomeWidget.saveWidgetData<String>(
      appearanceKey,
      jsonEncode(widgetAppearanceJson(settings)),
    );
    await HomeWidget.updateWidget(iOSName: widgetKind);
    _logger.debug('Widget appearance published: $settings');
  }
}

/// iOS dışı platformlarda kullanılır. Widget yalnızca iOS'ta var; diğer
/// platformlarda yayınlama sessizce atlanır.
class NoopWidgetPublisher implements WidgetPublisher {
  const NoopWidgetPublisher();

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {}

  @override
  Future<void> publishTimeFormat(String storageValue) async {}

  @override
  Future<void> publishAppearance(AppearanceSettings settings) async {}
}
