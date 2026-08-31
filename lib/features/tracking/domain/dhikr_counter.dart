/// Kullanıcıya sunulan hazır hedefler; özel hedef ayrıca girilebilir.
const List<int> kDhikrTargets = [33, 99, 100, 500, 1000];

/// Zikirmatiğin anlık durumu. Saf: sayaç mantığı burada, kalıcılık dışarıda.
class DhikrState {
  final int count;
  final int target;

  const DhikrState({required this.count, required this.target});

  /// Sıfır ya da negatif hedef anlamsız; bire çekilir ki tur hesabı sıfıra
  /// bölmesin.
  int get _safeTarget => target < 1 ? 1 : target;

  /// Tamamlanan tur sayısı.
  int get laps => count ~/ _safeTarget;

  /// İçinde bulunulan turdaki sayı.
  int get inLap => count % _safeTarget;

  /// Turu tamamlamak için kalan. Tam tur bitince yeni tur için hedef kadar
  /// kalmış sayılır.
  int get remaining => _safeTarget - inLap;

  DhikrState increment() => DhikrState(count: count + 1, target: target);

  DhikrState decrement() =>
      DhikrState(count: count > 0 ? count - 1 : 0, target: target);

  /// Sayacı sıfırlar; hedef korunur.
  DhikrState reset() => DhikrState(count: 0, target: target);

  DhikrState withTarget(int newTarget) =>
      DhikrState(count: count, target: newTarget);
}
