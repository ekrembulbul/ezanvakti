import 'notification_setting.dart' show PrayerType;

/// Pencerenin neye göre kurulduğu.
enum QuietTrigger {
  /// Yalnızca Cuma öğle vakti.
  fridayDhuhr,

  /// Seçilen vakit, her gün.
  prayer,
}

/// Pencereye düşen bildirime ne yapılacağı.
enum QuietMode {
  /// Bildirim gösterilir ama ses çalmaz.
  silent,

  /// Bildirim hiç planlanmaz.
  skip,
}

/// Bildirimlerin susturulacağı zaman aralığı.
///
/// **iOS'ta telefonu sessize almaz** — bir uygulama sessiz anahtarını ya da
/// Odak modunu değiştiremez. Bu ayar yalnızca uygulamanın kendi bildirimlerini
/// etkiler; alarmlara (AlarmKit) hiç dokunmaz, çünkü kullanıcı alarmı bilerek
/// kurmuştur.
class QuietWindow {
  final String id;
  final QuietTrigger trigger;

  /// [QuietTrigger.prayer] için hedef vakit; Cuma şablonunda null.
  final PrayerType? prayerType;

  /// Pencere: vakitten [minutesBefore] önce başlar, [minutesAfter] sonra biter.
  final int minutesBefore;
  final int minutesAfter;

  final QuietMode mode;
  final bool isActive;

  const QuietWindow({
    required this.id,
    required this.trigger,
    this.prayerType,
    required this.minutesBefore,
    required this.minutesAfter,
    this.mode = QuietMode.silent,
    this.isActive = true,
  });

  /// Cuma namazı şablonu: öğleden 15 dk önce başlar, 60 dk sonra biter.
  factory QuietWindow.fridayDefault() => const QuietWindow(
    id: 'friday',
    trigger: QuietTrigger.fridayDhuhr,
    minutesBefore: 15,
    minutesAfter: 60,
  );

  /// Bu pencere verilen vakti kapsıyor mu (gün kuralı dahil).
  bool matchesPrayer(PrayerType type, DateTime prayerAt) {
    return switch (trigger) {
      QuietTrigger.fridayDhuhr =>
        type == PrayerType.dhuhr && prayerAt.weekday == DateTime.friday,
      QuietTrigger.prayer => type == prayerType,
    };
  }

  /// [fireAt] pencerenin içinde mi (sınırlar dahil).
  bool contains(DateTime fireAt, DateTime prayerAt) {
    final start = prayerAt.subtract(Duration(minutes: minutesBefore));
    final end = prayerAt.add(Duration(minutes: minutesAfter));
    return !fireAt.isBefore(start) && !fireAt.isAfter(end);
  }

  QuietWindow copyWith({
    QuietTrigger? trigger,
    PrayerType? prayerType,
    int? minutesBefore,
    int? minutesAfter,
    QuietMode? mode,
    bool? isActive,
  }) {
    return QuietWindow(
      id: id,
      trigger: trigger ?? this.trigger,
      prayerType: prayerType ?? this.prayerType,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      minutesAfter: minutesAfter ?? this.minutesAfter,
      mode: mode ?? this.mode,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'trigger': trigger.name,
    'prayerType': prayerType?.name,
    'minutesBefore': minutesBefore,
    'minutesAfter': minutesAfter,
    'mode': mode.name,
    'isActive': isActive,
  };

  /// Bozuk alanlar güvenli varsayılana düşer; tek kötü kayıt tüm listeyi
  /// okunamaz hale getirmesin.
  factory QuietWindow.fromJson(Map<String, dynamic> json) => QuietWindow(
    id: json['id'] as String,
    trigger: QuietTrigger.values.firstWhere(
      (value) => value.name == json['trigger'],
      orElse: () => QuietTrigger.prayer,
    ),
    prayerType: PrayerType.values
        .where((value) => value.name == json['prayerType'])
        .firstOrNull,
    minutesBefore: json['minutesBefore'] as int? ?? 0,
    minutesAfter: json['minutesAfter'] as int? ?? 0,
    mode: QuietMode.values.firstWhere(
      (value) => value.name == json['mode'],
      orElse: () => QuietMode.silent,
    ),
    isActive: json['isActive'] as bool? ?? true,
  );
}
