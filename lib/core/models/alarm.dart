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
  /// [isOnce] açıkken yok sayılır; kullanıcı tekrara dönerse seçimi korunur.
  final Set<int> weekdays;

  /// Tek seferlik ("Bir kez") alarm: yalnız [onceDate] gününün çalışı kurulur;
  /// çalıp zincir süresi geçince planlayıcı alarmı kendisi kapatır
  /// (docs/adr/0007). Boş [weekdays] "her gün" demek olduğu için tek seferlik
  /// ayrı bir bayrakla tutulur.
  final bool isOnce;

  /// Tek seferlik alarmın **kaynak vakit günü** (saatsiz). Çıpalı alarmda
  /// vaktin hangi günün tablosundan okunacağını belirler; ofset gece yarısını
  /// geçirse de gün budur. `null` = henüz hesaplanamadı (vakit verisi yok).
  final DateTime? onceDate;

  /// Gömülü ses kimliği (örn. 'adhan') ya da özel ses işareti (`custom:<uri>`).
  final String soundId;
  final bool vibrate;

  /// Ses sıfırdan değil, düşük bir seviyeden başlayıp kısa sürede tam
  /// seviyeye çıksın mı? **Yalnızca Android'de** etkili: iOS'ta alarm
  /// sistemin (AlarmKit) elinde ve ses seviyesine erişim yok.
  final bool fadeIn;
  final bool snoozeEnabled;
  final int snoozeMinutes;

  /// Alarmı kapatmak için gereken görev. [AlarmMission.none] ise alarm
  /// bugünkü gibi doğrudan kapanır.
  final AlarmMission mission;

  /// Görev zorluğu (1–3). Yükseldikçe süre değil **iş miktarı** artar.
  final int missionLevel;

  /// QR görevinde okutulması gereken kod. Alarm kurulurken okutularak ya da
  /// elle yazılarak kaydedilir.
  final String? qrPayload;

  /// Uygulama içi erteleme üst sınırı. `null` = sınırsız. Görev açıkken
  /// `null` bırakılamaz; kaydederken en büyük sonlu seçeneğe düşürülür.
  final int? maxSnoozes;

  /// Alarm çalarken telefonun alarm ses seviyesi (%10–100). `null` = telefonun
  /// o anki alarm seviyesi. **Yalnızca Android'de** etkili; iOS'ta AlarmKit
  /// seviye API'si vermiyor.
  final int? volume;

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
    this.isOnce = false,
    this.onceDate,
    this.soundId = 'default',
    this.vibrate = true,
    this.fadeIn = false,
    this.snoozeEnabled = true,
    this.snoozeMinutes = 5,
    this.mission = AlarmMission.none,
    this.missionLevel = 1,
    this.qrPayload,
    this.maxSnoozes,
    this.volume,
  });

  bool get repeats => weekdays.isNotEmpty;

  bool firesOnWeekday(int weekday) =>
      weekdays.isEmpty || weekdays.contains(weekday);

  /// [day] (kaynak vakit günü) bu alarmın çalış günü mü? Tek seferlikte
  /// yalnız [onceDate]; tekrarlıda gün kümesi.
  bool firesOnDay(DateTime day) {
    if (!isOnce) return firesOnWeekday(day.weekday);
    final target = onceDate;
    return target != null &&
        target.year == day.year &&
        target.month == day.month &&
        target.day == day.day;
  }

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
      'once': isOnce ? 1 : 0,
      'once_date': onceDate == null ? null : _formatOnceDate(onceDate!),
      'sound_id': soundId,
      'vibrate': vibrate ? 1 : 0,
      'fade_in': fadeIn ? 1 : 0,
      'snooze_enabled': snoozeEnabled ? 1 : 0,
      'snooze_minutes': snoozeMinutes,
      'mission': mission.name,
      'mission_level': missionLevel,
      'qr_payload': qrPayload,
      'max_snoozes': maxSnoozes,
      'volume': volume,
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
      isOnce: (map['once'] as int? ?? 0) == 1,
      onceDate: _parseOnceDate(map['once_date']),
      soundId: _migrateSoundId(map['sound_id'] as String?),
      vibrate: (map['vibrate'] as int? ?? 1) == 1,
      fadeIn: (map['fade_in'] as int? ?? 0) == 1,
      snoozeEnabled: (map['snooze_enabled'] as int? ?? 1) == 1,
      snoozeMinutes: map['snooze_minutes'] as int? ?? 5,
      mission: AlarmMission.values.firstWhere(
        (e) => e.name == map['mission'],
        orElse: () => AlarmMission.none,
      ),
      missionLevel: map['mission_level'] as int? ?? 1,
      qrPayload: map['qr_payload'] as String?,
      maxSnoozes: map['max_snoozes'] as int?,
      volume: _normalizeVolume(map['volume']),
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
    bool? isOnce,
    DateTime? onceDate,

    /// `onceDate` null'a çekilemiyor (`??`); temizlemek için.
    bool clearOnceDate = false,
    String? soundId,
    bool? vibrate,
    bool? fadeIn,
    bool? snoozeEnabled,
    int? snoozeMinutes,
    AlarmMission? mission,
    int? missionLevel,
    String? qrPayload,
    int? maxSnoozes,
    int? volume,
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
      isOnce: isOnce ?? this.isOnce,
      onceDate: clearOnceDate ? null : (onceDate ?? this.onceDate),
      soundId: soundId ?? this.soundId,
      vibrate: vibrate ?? this.vibrate,
      fadeIn: fadeIn ?? this.fadeIn,
      snoozeEnabled: snoozeEnabled ?? this.snoozeEnabled,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      mission: mission ?? this.mission,
      missionLevel: missionLevel ?? this.missionLevel,
      qrPayload: qrPayload ?? this.qrPayload,
      maxSnoozes: maxSnoozes ?? this.maxSnoozes,
      volume: volume ?? this.volume,
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
          isOnce == other.isOnce &&
          onceDate == other.onceDate &&
          soundId == other.soundId &&
          vibrate == other.vibrate &&
          fadeIn == other.fadeIn &&
          snoozeEnabled == other.snoozeEnabled &&
          snoozeMinutes == other.snoozeMinutes &&
          mission == other.mission &&
          missionLevel == other.missionLevel &&
          qrPayload == other.qrPayload &&
          maxSnoozes == other.maxSnoozes &&
          volume == other.volume;

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
    // Object.hash en çok 20 değer alıyor.
    Object.hash(isOnce, onceDate),
    soundId,
    vibrate,
    fadeIn,
    snoozeEnabled,
    snoozeMinutes,
    mission,
    missionLevel,
    qrPayload,
    maxSnoozes,
    volume,
  );

  static bool _setEquals(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}

/// Projede hiçbir ses dosyası yok; `adhan` ve `alarm` zaten sessizce sistem
/// varsayılanına düşüyordu (`AppDelegate.swift:415-418`). Seçenekler
/// seçiciden kaldırıldığı için kayıtlı değerler de eşleniyor — yoksa eski
/// alarmlar seçicide "Özel ses" diye görünürdü.
String _migrateSoundId(String? stored) {
  if (stored == null || stored.isEmpty) return 'default';
  if (stored == 'adhan' || stored == 'alarm') return 'default';
  return stored;
}

/// Tek seferlik hedef gün `yyyy-MM-dd` saklanır: saat ve saat dilimi taşımaz,
/// gün yerel takvimde okunur.
String _formatOnceDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// Bozuk ya da geçersiz tarih `null` okunur: planlayıcı onu "hesaplanamadı"
/// sayar, alarmı ne kurar ne kapatır.
DateTime? _parseOnceDate(Object? value) {
  if (value is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  // DateTime taşmayı sessizce ileri kaydırır (13. ay); geri dönüş tutmazsa bozuk.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// Bozuk ya da aralık dışı değer telefonun seviyesine düşer.
int? _normalizeVolume(Object? value) =>
    value is int && value >= 10 && value <= 100 ? value : null;
