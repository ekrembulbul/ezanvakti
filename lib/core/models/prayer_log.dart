import 'notification_setting.dart' show PrayerType;

/// Bir vaktin o günkü durumu.
enum PrayerStatus {
  /// Vaktinde kılındı.
  done,

  /// Kazaya kaldı (sonradan kılınacak ya da kılındı).
  qada,

  /// Kaçırıldı ve kaza olarak da işaretlenmedi.
  missed,
}

extension PrayerStatusX on PrayerStatus {
  String get storageValue => switch (this) {
    PrayerStatus.done => 'done',
    PrayerStatus.qada => 'qada',
    PrayerStatus.missed => 'missed',
  };

  String get label => switch (this) {
    PrayerStatus.done => 'Kıldım',
    PrayerStatus.qada => 'Kaza',
    PrayerStatus.missed => 'Kaçtı',
  };

  static PrayerStatus? fromStorage(String? value) {
    if (value == null) return null;
    for (final status in PrayerStatus.values) {
      if (status.storageValue == value) return status;
    }
    return null;
  }
}

/// Takip edilen vakitler: güneş bir namaz vakti değil, ızgarada yer almaz.
const List<PrayerType> trackedPrayerTypes = [
  PrayerType.fajr,
  PrayerType.dhuhr,
  PrayerType.asr,
  PrayerType.maghrib,
  PrayerType.isha,
];

/// Kaza sayacının üst sınırı. Sayaç bir ömrü kapsayabilir ama sınırsız
/// bırakmak kazara girilen bir değeri geri almayı zorlaştırır.
const int kMaxQadaCount = 99999;

/// Izgaradaki dokunuş döngüsü: boş → kıldım → kaza → boş.
///
/// "Kaçtı" döngüde yok; kullanıcı bir vakti kaçırdığını işaretlemek yerine
/// boş bırakır. Kayıt varsa da döngü kıldımdan devam eder.
PrayerStatus? nextPrayerStatus(PrayerStatus? current) => switch (current) {
  null => PrayerStatus.done,
  PrayerStatus.done => PrayerStatus.qada,
  PrayerStatus.qada => null,
  PrayerStatus.missed => PrayerStatus.done,
};

/// Kayıt anahtarı: `yyyy-MM-dd|prayerType`. Gün içi saat anahtarı etkilemez.
String prayerLogKey(DateTime date, PrayerType prayerType) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day|${prayerType.name}';
}

/// Kaza sayacını geçerli aralığa kırpar.
int clampQadaCount(int value) => value.clamp(0, kMaxQadaCount);
