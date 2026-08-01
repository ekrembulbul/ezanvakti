import '../models/prayer_time.dart';

/// Günün, palet değişimini belirleyen dört dilimi.
///
/// Sınırlar: [morning] İmsak→Öğle, [afternoon] Öğle→İkindi,
/// [evening] İkindi→**Yatsı**, [night] Yatsı→(ertesi gün) İmsak.
///
/// Gece Akşam'da değil Yatsı'da başlar: akşam ezanı ile yatsı arasında
/// gökyüzü hâlâ aydınlıktır.
enum DayPhase { morning, afternoon, evening, night }

/// Vakit verisi olmadığında kullanılan dilim.
///
/// İlk açılış, onboarding ve önbelleği boş offline durumları bu palette
/// gösterilir; uygulama ikonu da aynı ailedendir.
const DayPhase fallbackDayPhase = DayPhase.evening;

/// [now] anının hangi dilime düştüğünü döner.
///
/// Sınır anları bir sonraki dilime aittir: tam Öğle vaktinde
/// [DayPhase.afternoon] döner. [today] yoksa [fallbackDayPhase] döner.
DayPhase resolveDayPhase({
  PrayerTime? today,
  PrayerTime? tomorrow,
  required DateTime now,
}) {
  if (today == null) return fallbackDayPhase;

  // Gece yarısı ile İmsak arası: dünün Yatsı'sından süregelen gece. Ayrı bir
  // "dün" verisine ihtiyaç yok, bu aralık tanım gereği gecedir.
  if (now.isBefore(today.fajr)) return DayPhase.night;

  if (now.isBefore(today.dhuhr)) return DayPhase.morning;
  if (now.isBefore(today.asr)) return DayPhase.afternoon;
  if (now.isBefore(today.isha)) return DayPhase.evening;
  return DayPhase.night;
}

/// Bir sonraki dilim sınırının zamanı. Çağıran bu ana tek seferlik bir `Timer`
/// kurar; dakikalık yoklamaya gerek kalmaz.
///
/// Gece diliminde sınır ertesi günün İmsak'ıdır; [tomorrow] yoksa [today]'in
/// İmsak'ına 24 saat eklenir. [today] yoksa `null` döner.
DateTime? nextDayPhaseBoundary({
  PrayerTime? today,
  PrayerTime? tomorrow,
  required DateTime now,
}) {
  if (today == null) return null;

  for (final boundary in [today.fajr, today.dhuhr, today.asr, today.isha]) {
    if (now.isBefore(boundary)) return boundary;
  }

  // Yatsı geçildi: sıradaki sınır ertesi günün İmsak'ı.
  return tomorrow?.fajr ?? today.fajr.add(const Duration(days: 1));
}
