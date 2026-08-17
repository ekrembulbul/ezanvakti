/// Acil çıkışın **global** kademesi: tek sayaç, tüm alarmlar ortak.
/// Cezalandırılan davranış "görevden kaçmak", hangi alarmdan kaçıldığı değil.
class AbortState {
  final int level;
  final DateTime? lastUsedAt;

  const AbortState({this.level = 0, this.lastUsedAt});

  Map<String, dynamic> toJson() => {
    'level': level,
    'last_used_at': lastUsedAt?.toIso8601String(),
  };

  /// Bozuk kayıt uygulamayı açılmaz hale getirmemeli; en güvenli değere
  /// (kademe yok) düşer.
  factory AbortState.fromJson(Map<String, dynamic> json) {
    final rawLevel = json['level'];
    final rawDate = json['last_used_at'];
    return AbortState(
      level: rawLevel is int && rawLevel >= 0 ? rawLevel : 0,
      lastUsedAt: rawDate is String ? DateTime.tryParse(rawDate) : null,
    );
  }
}
