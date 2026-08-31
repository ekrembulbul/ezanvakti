import '../../../core/interfaces/widget_publisher.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/models/location.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/utils/app_logger.dart';
import 'widget_snapshot.dart';
import 'widget_snapshot_builder.dart';

/// Snapshot üretip yayınlar; hata çıkarsa **yutmaz ama yukarı da sızdırmaz**.
///
/// Vakit gösterimi widget yüzünden bozulmamalı: yayınlama patlarsa widget bir
/// önceki snapshot'ıyla çalışmaya devam eder, kullanıcı akışı kesilmez.
///
/// `HomePage` içine gömülmedi çünkü bu kural ancak ayrı bir birimken doğrudan
/// sınanabilir.
Future<void> publishWidgetSnapshot({
  required WidgetPublisher publisher,
  required AppLogger logger,
  required Location? location,
  required List<PrayerTime> prayerTimes,
  required DateTime now,
  WidgetLabels? labels,
  AppLocalizations? l10n,
}) async {
  if (location == null) return;

  try {
    await publisher.publish(
      WidgetSnapshotBuilder.build(
        location: location,
        prayerTimes: prayerTimes,
        now: now,
        labels: labels,
        l10n: l10n,
      ),
    );
  } catch (e, stackTrace) {
    logger.warning('Widget snapshot publish failed', e, stackTrace);
  }
}
