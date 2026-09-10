import 'derived_time.dart';
import 'notification_setting.dart' show PrayerType;
import 'reminder_point.dart';

/// Bildirim düzenleme sayfasının "Kaydet" ile döndürdüğü değer.
///
/// [NotificationSetting] değil: ses, aktiflik gibi alanlar sayfada seçilmiyor;
/// ekleme ve güncelleme akışları bunları kendi kurallarıyla tamamlıyor.
class NotificationDraft {
  /// Hedef vakit; hesaplanan noktada o noktanın çıpası.
  final PrayerType prayerType;
  final DerivedTimeKind? derivedKind;
  final int minutesBefore;

  /// Tekrar günleri (1=Pazartesi .. 7=Pazar). Boş küme = her gün.
  final Set<int> weekdays;
  final String? label;

  const NotificationDraft({
    required this.prayerType,
    required this.minutesBefore,
    this.derivedKind,
    this.weekdays = const {},
    this.label,
  }) : assert(minutesBefore >= 0);

  factory NotificationDraft.fromPoint(
    ReminderPoint point, {
    required int minutesBefore,
    Set<int> weekdays = const {},
    String? label,
  }) => NotificationDraft(
    prayerType: point.anchor,
    derivedKind: point.derived,
    minutesBefore: minutesBefore,
    weekdays: weekdays,
    label: label,
  );

  ReminderPoint get point => ReminderPoint.of(prayerType, derivedKind);
}
