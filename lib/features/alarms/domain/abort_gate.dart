import '../../../core/config/mission_tuning.dart';
import '../../../core/models/abort_state.dart';

/// Acil çıkışta yazılması istenen cümlenin kimliği; metin çeviriden gelir.
enum AbortPhrase { short, long }

/// Belirli bir kademede acil çıkış için istenenler.
class AbortRequirement {
  final bool requiresPhrase;

  /// Yazılması istenen cümlenin **kimliği**; metin çeviriden alınır
  /// (bkz. `AbortPhrase`). [requiresPhrase] false ise null.
  final AbortPhrase? phrase;

  /// Atlanamayan bekleme. 0 = yok.
  final int countdownSeconds;

  const AbortRequirement({
    required this.requiresPhrase,
    required this.phrase,
    required this.countdownSeconds,
  });

  @override
  bool operator ==(Object other) =>
      other is AbortRequirement &&
      requiresPhrase == other.requiresPhrase &&
      phrase == other.phrase &&
      countdownSeconds == other.countdownSeconds;

  @override
  int get hashCode => Object.hash(requiresPhrase, phrase, countdownSeconds);
}

/// Acil çıkışın kademe kuralları.
///
/// Çıkış **her zaman** mümkün olmalı ama alışkanlığa dönüşmemeli. Bu yüzden
/// zorluk artar, tavanla sınırlıdır ve kullanılmayınca geriler.
class AbortGate {
  const AbortGate._();

  /// Cümleler kalibrasyona açık: uykulu birini uğraştıracak kadar uzun,
  /// uyanık birini bunaltmayacak kadar kısa olmalı. Metinleri çeviride.
  static const AbortPhrase _phraseShort = AbortPhrase.short;
  static const AbortPhrase _phraseLong = AbortPhrase.long;
  static const int _ceilingCountdownSeconds = 15;

  static int _clamp(int level) => level.clamp(0, MissionTuning.abortMaxLevel);

  static bool isAtCeiling(int level) => level >= MissionTuning.abortMaxLevel;

  /// Gerileme uygulanmış güncel kademe. Saklanan kademe ham değerdir; ekranda
  /// ve kararlarda bu fonksiyonun sonucu kullanılır.
  static int effectiveLevel({
    required AbortState state,
    required DateTime now,
  }) {
    final last = state.lastUsedAt;
    if (last == null) return 0;
    final elapsedDays = now.difference(last).inDays;
    if (elapsedDays < 0) return _clamp(state.level);
    final steps = elapsedDays ~/ MissionTuning.abortDecayDays;
    return _clamp(state.level - steps);
  }

  /// Çıkış kullanıldı: kademeyi bir artır, tavanı geçme.
  static AbortState escalate({
    required AbortState state,
    required DateTime now,
  }) {
    final current = effectiveLevel(state: state, now: now);
    return AbortState(level: _clamp(current + 1), lastUsedAt: now);
  }

  static AbortRequirement requirementFor(int level) {
    switch (_clamp(level)) {
      case 0:
        return const AbortRequirement(
          requiresPhrase: false,
          phrase: null,
          countdownSeconds: 0,
        );
      case 1:
        return const AbortRequirement(
          requiresPhrase: true,
          phrase: _phraseShort,
          countdownSeconds: 0,
        );
      case 2:
        return const AbortRequirement(
          requiresPhrase: true,
          phrase: _phraseLong,
          countdownSeconds: 0,
        );
      default:
        return const AbortRequirement(
          requiresPhrase: true,
          phrase: _phraseLong,
          countdownSeconds: _ceilingCountdownSeconds,
        );
    }
  }

  /// Yazılan metin beklenen cümleyle eşleşiyor mu?
  ///
  /// Baştaki/sondaki ve fazla boşluklar affedilir, büyük/küçük harf göz ardı
  /// edilir. Türkçe'de `I → ı` ve `İ → i` olduğu için Dart'ın
  /// locale-bağımsız `toLowerCase`'i tek başına yetmez.
  static bool phraseMatches({
    required String expected,
    required String typed,
  }) => _normalize(expected) == _normalize(typed);

  static String _normalize(String value) => value
      .replaceAll('I', 'ı')
      .replaceAll('İ', 'i')
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}
