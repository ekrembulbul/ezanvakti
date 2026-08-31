enum PrayerType { fajr, sunrise, dhuhr, asr, maghrib, isha }

/// Bir vakit için kurulmuş bildirim.
///
/// Kimliği **(vakit, kaç dakika önce, günler)** üçlüsüdür: aynı vakit ve
/// sapmada hem "her gün" hem "yalnızca Cuma" satırı bulunabilir.
class NotificationSetting {
  final PrayerType prayerType;
  final bool isActive;
  final int minutesBefore;

  /// Bildirim sesi: `null` = sistem varsayılanı. Bkz. `NotificationSounds`.
  final String? soundId;

  /// Tekrar günleri (1=Pazartesi .. 7=Pazar). Boş küme = her gün.
  /// Kodlama Alarm ile birebir aynı.
  final Set<int> weekdays;

  /// Kullanıcının verdiği ad; doluysa bildirim başlığında kullanılır
  /// ("Cuma namazı" gibi).
  final String? label;

  const NotificationSetting({
    required this.prayerType,
    required this.isActive,
    this.minutesBefore = 0,
    this.soundId,
    this.weekdays = const {},
    this.label,
  });

  /// Boş gün kümesi "her gün" demek.
  bool firesOnWeekday(int weekday) =>
      weekdays.isEmpty || weekdays.contains(weekday);

  /// Belirli günlere kısıtlı bir satır mı — planlayıcı çakışmada spesifik
  /// olanı öne alır.
  bool get isDayScoped => weekdays.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'prayerType': prayerType.name,
      'isActive': isActive,
      'minutesBefore': minutesBefore,
      'soundId': soundId,
      'weekdays': weekdaysCsv,
      'label': label,
    };
  }

  /// Depolama biçimi: sıralı CSV ("1,5"). Boş küme boş string.
  String get weekdaysCsv => (weekdays.toList()..sort()).join(',');

  static Set<int> parseWeekdays(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    return raw
        .split(',')
        .where((part) => part.isNotEmpty)
        .map(int.parse)
        .toSet();
  }

  factory NotificationSetting.fromJson(Map<String, dynamic> json) {
    return NotificationSetting(
      prayerType: PrayerType.values.firstWhere(
        (e) => e.name == json['prayerType'],
      ),
      isActive: json['isActive'] as bool,
      minutesBefore: json['minutesBefore'] as int? ?? 0,
      soundId: json['soundId'] as String?,
      weekdays: parseWeekdays(json['weekdays'] as String?),
      label: json['label'] as String?,
    );
  }

  NotificationSetting copyWith({
    PrayerType? prayerType,
    bool? isActive,
    int? minutesBefore,
    String? soundId,
    Set<int>? weekdays,
    String? label,
  }) {
    return NotificationSetting(
      prayerType: prayerType ?? this.prayerType,
      isActive: isActive ?? this.isActive,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      soundId: soundId ?? this.soundId,
      weekdays: weekdays ?? this.weekdays,
      label: label ?? this.label,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationSetting &&
          runtimeType == other.runtimeType &&
          prayerType == other.prayerType &&
          isActive == other.isActive &&
          minutesBefore == other.minutesBefore &&
          soundId == other.soundId &&
          weekdaysCsv == other.weekdaysCsv &&
          label == other.label;

  @override
  int get hashCode => Object.hash(
    prayerType,
    isActive,
    minutesBefore,
    soundId,
    weekdaysCsv,
    label,
  );
}
