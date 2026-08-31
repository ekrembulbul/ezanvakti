import 'derived_time.dart';

enum PrayerType { fajr, sunrise, dhuhr, asr, maghrib, isha }

/// Bir vakit için kurulmuş bildirim.
///
/// Kimliği **(vakit, türetilmiş nokta, kaç dakika önce, günler)** dörtlüsüdür:
/// aynı vakit ve sapmada hem "her gün" hem "yalnızca Cuma" satırı, hem de
/// vaktin kendisi ile ondan türeyen bir nokta (ör. öğle ve zeval) yan yana
/// bulunabilir.
class NotificationSetting {
  /// Vakit bildirimlerinde hedef vakit; türetilmiş noktalarda o noktanın
  /// çıpası (bkz. [DerivedTimeKindX.anchor]).
  final PrayerType prayerType;

  /// Dolu ise satır bir türetilmiş noktaya (kerahat, teheccüd…) kuruludur.
  final DerivedTimeKind? derivedKind;
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
    this.derivedKind,
    this.minutesBefore = 0,
    this.soundId,
    this.weekdays = const {},
    this.label,
  });

  bool get isDerived => derivedKind != null;

  /// Boş gün kümesi "her gün" demek.
  bool firesOnWeekday(int weekday) =>
      weekdays.isEmpty || weekdays.contains(weekday);

  /// Belirli günlere kısıtlı bir satır mı — planlayıcı çakışmada spesifik
  /// olanı öne alır.
  bool get isDayScoped => weekdays.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'prayerType': prayerType.name,
      'derivedKind': derivedKind?.storageValue,
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
      derivedKind: DerivedTimeKindX.fromStorage(
        json['derivedKind'] as String?,
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
    DerivedTimeKind? derivedKind,
    bool? isActive,
    int? minutesBefore,
    String? soundId,
    Set<int>? weekdays,
    String? label,
  }) {
    return NotificationSetting(
      prayerType: prayerType ?? this.prayerType,
      derivedKind: derivedKind ?? this.derivedKind,
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
          derivedKind == other.derivedKind &&
          isActive == other.isActive &&
          minutesBefore == other.minutesBefore &&
          soundId == other.soundId &&
          weekdaysCsv == other.weekdaysCsv &&
          label == other.label;

  @override
  int get hashCode => Object.hash(
    prayerType,
    derivedKind,
    isActive,
    minutesBefore,
    soundId,
    weekdaysCsv,
    label,
  );
}
