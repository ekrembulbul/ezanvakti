import 'alarm_mission.dart';
import 'notification_setting.dart' show PrayerType;

/// Alarm türü: sabit saat ya da bir namaz vaktine çıpalı (ofsetli).
enum AlarmKind { fixed, anchored }

/// Sesli/kalıcı alarm tanımı. Bildirimden farkı: kapatılana kadar çalar,
/// (platform destekliyorsa) sessiz modu deler, ertelenebilir.
///
/// - [AlarmKind.fixed]: [hour]/[minute] sabit saatinde çalar.
/// - [AlarmKind.anchored]: [anchor] vaktinin [offsetMinutes] kadar önce
///   (negatif) / sonra (pozitif) çalar; vakit her gün kaydıkça otomatik güncellenir.
class Alarm {
  final String id;
  final AlarmKind kind;
  final String label;
  final bool isActive;

  // Sabit (fixed) için:
  final int hour; // 0-23
  final int minute; // 0-59

  // Çıpalı (anchored) için:
  final PrayerType anchor;
  final int offsetMinutes; // negatif = önce, pozitif = sonra

  // Ortak:
  /// Tekrar günleri (1=Pazartesi .. 7=Pazar). Boş küme = her gün.
  final Set<int> weekdays;

  /// Gömülü ses kimliği (örn. 'adhan') ya da özel ses işareti (`custom:<uri>`).
  final String soundId;
  final bool vibrate;
  final bool snoozeEnabled;
  final int snoozeMinutes;

  /// Alarmı kapatmak için gereken görev. [AlarmMission.none] ise alarm
  /// bugünkü gibi doğrudan kapanır.
  final AlarmMission mission;

  /// Görev zorluğu (1–3). Yükseldikçe süre değil **iş miktarı** artar.
  final int missionLevel;

  /// Uygulama içi erteleme üst sınırı. `null` = sınırsız. Görev açıkken
  /// `null` bırakılamaz; kaydederken en büyük sonlu seçeneğe düşürülür.
  final int? maxSnoozes;

  const Alarm({
    required this.id,
    required this.kind,
    this.label = '',
    this.isActive = true,
    this.hour = 0,
    this.minute = 0,
    this.anchor = PrayerType.fajr,
    this.offsetMinutes = 0,
    this.weekdays = const {},
    this.soundId = 'adhan',
    this.vibrate = true,
    this.snoozeEnabled = true,
    this.snoozeMinutes = 5,
    this.mission = AlarmMission.none,
    this.missionLevel = 1,
    this.maxSnoozes,
  });

  bool get repeats => weekdays.isNotEmpty;

  bool firesOnWeekday(int weekday) =>
      weekdays.isEmpty || weekdays.contains(weekday);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kind': kind.name,
      'label': label,
      'is_active': isActive ? 1 : 0,
      'hour': hour,
      'minute': minute,
      'anchor': anchor.name,
      'offset_minutes': offsetMinutes,
      'weekdays': (weekdays.toList()..sort()).join(','),
      'sound_id': soundId,
      'vibrate': vibrate ? 1 : 0,
      'snooze_enabled': snoozeEnabled ? 1 : 0,
      'snooze_minutes': snoozeMinutes,
      'mission': mission.name,
      'mission_level': missionLevel,
      'max_snoozes': maxSnoozes,
    };
  }

  factory Alarm.fromMap(Map<String, dynamic> map) {
    final weekdaysRaw = (map['weekdays'] as String?) ?? '';
    final weekdays = weekdaysRaw.isEmpty
        ? <int>{}
        : weekdaysRaw
              .split(',')
              .where((s) => s.isNotEmpty)
              .map(int.parse)
              .toSet();
    return Alarm(
      id: map['id'] as String,
      kind: AlarmKind.values.firstWhere((e) => e.name == map['kind']),
      label: (map['label'] as String?) ?? '',
      isActive: (map['is_active'] as int? ?? 1) == 1,
      hour: map['hour'] as int? ?? 0,
      minute: map['minute'] as int? ?? 0,
      anchor: PrayerType.values.firstWhere(
        (e) => e.name == map['anchor'],
        orElse: () => PrayerType.fajr,
      ),
      offsetMinutes: map['offset_minutes'] as int? ?? 0,
      weekdays: weekdays,
      soundId: (map['sound_id'] as String?) ?? 'adhan',
      vibrate: (map['vibrate'] as int? ?? 1) == 1,
      snoozeEnabled: (map['snooze_enabled'] as int? ?? 1) == 1,
      snoozeMinutes: map['snooze_minutes'] as int? ?? 5,
      mission: AlarmMission.values.firstWhere(
        (e) => e.name == map['mission'],
        orElse: () => AlarmMission.none,
      ),
      missionLevel: map['mission_level'] as int? ?? 1,
      maxSnoozes: map['max_snoozes'] as int?,
    );
  }

  Alarm copyWith({
    String? id,
    AlarmKind? kind,
    String? label,
    bool? isActive,
    int? hour,
    int? minute,
    PrayerType? anchor,
    int? offsetMinutes,
    Set<int>? weekdays,
    String? soundId,
    bool? vibrate,
    bool? snoozeEnabled,
    int? snoozeMinutes,
    AlarmMission? mission,
    int? missionLevel,
    int? maxSnoozes,
  }) {
    return Alarm(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      isActive: isActive ?? this.isActive,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      anchor: anchor ?? this.anchor,
      offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      weekdays: weekdays ?? this.weekdays,
      soundId: soundId ?? this.soundId,
      vibrate: vibrate ?? this.vibrate,
      snoozeEnabled: snoozeEnabled ?? this.snoozeEnabled,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      mission: mission ?? this.mission,
      missionLevel: missionLevel ?? this.missionLevel,
      maxSnoozes: maxSnoozes ?? this.maxSnoozes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Alarm &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          kind == other.kind &&
          label == other.label &&
          isActive == other.isActive &&
          hour == other.hour &&
          minute == other.minute &&
          anchor == other.anchor &&
          offsetMinutes == other.offsetMinutes &&
          _setEquals(weekdays, other.weekdays) &&
          soundId == other.soundId &&
          vibrate == other.vibrate &&
          snoozeEnabled == other.snoozeEnabled &&
          snoozeMinutes == other.snoozeMinutes &&
          mission == other.mission &&
          missionLevel == other.missionLevel &&
          maxSnoozes == other.maxSnoozes;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    label,
    isActive,
    hour,
    minute,
    anchor,
    offsetMinutes,
    Object.hashAllUnordered(weekdays),
    soundId,
    vibrate,
    snoozeEnabled,
    snoozeMinutes,
    mission,
    missionLevel,
    maxSnoozes,
  );

  static bool _setEquals(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}
