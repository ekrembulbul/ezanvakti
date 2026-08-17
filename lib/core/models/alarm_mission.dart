/// Alarmın kapatılabilmesi için tamamlanması gereken görev.
///
/// [none] bugünkü davranıştır: alarm kaydırılarak doğrudan kapanır. Diğerleri
/// kapatmayı bir göreve bağlar; kapı yalnızca kapatmada durur, erteleme görev
/// istemez.
enum AlarmMission { none, math, shake, qr }

extension AlarmMissionX on AlarmMission {
  /// Bu görev, kapatmanın önüne bir kapı koyuyor mu?
  bool get requiresGate => this != AlarmMission.none;
}
