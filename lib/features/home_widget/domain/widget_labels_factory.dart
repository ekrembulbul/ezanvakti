import '../../../core/models/notification_setting.dart' show PrayerType;
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extensions.dart';
import 'widget_snapshot.dart';

/// Çeviri örneğinden widget etiketlerini üretir.
///
/// Widget kendi süreçinde çalıştığı ve `AppLocalizations`a erişemediği için
/// metinler snapshot'la birlikte gönderiliyor.
WidgetLabels widgetLabelsFrom(AppLocalizations l10n) => WidgetLabels(
  fajr: l10n.prayerName(PrayerType.fajr),
  sunrise: l10n.prayerName(PrayerType.sunrise),
  dhuhr: l10n.prayerName(PrayerType.dhuhr),
  asr: l10n.prayerName(PrayerType.asr),
  maghrib: l10n.prayerName(PrayerType.maghrib),
  isha: l10n.prayerName(PrayerType.isha),
  tomorrow: l10n.widgetTomorrow,
  stale: l10n.widgetStale,
  openApp: l10n.widgetOpenApp,
  updateApp: l10n.widgetUpdateApp,
  // Şablonlar yer tutucularıyla gönderilir; Swift tarafı dolduruyor.
  siriAnswer: l10n.siriAnswer('{prayer}', '{time}', '{remaining}'),
  durationHourMinute: l10n.durationHourMinute('{hours}', '{minutes}'),
  durationHour: l10n.durationHour('{hours}'),
  durationMinute: l10n.durationMinute('{minutes}'),
);
