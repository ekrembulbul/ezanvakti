/// Dini günün türü — arayüzde vurgusunu ve bildirim metnini belirler.
enum ReligiousDayKind {
  /// Kandil geceleri.
  kandil,

  /// Ramazan ve Kurban bayramları.
  bayram,

  /// Ramazan'ın başlangıcı.
  ramadanStart,

  /// Hicri yılbaşı, Aşure, Arefe gibi diğer önemli günler.
  other,
}

/// Bir dini gün: miladi tarihi, adı ve nasıl belirlendiği.
class ReligiousDay {
  /// Miladi karşılık (gün başına yuvarlanmış).
  final DateTime date;

  final String name;
  final ReligiousDayKind kind;

  /// Tarih hicri takvimden **hesaplandı** mı. Diyanet ilanları astronomik
  /// gözleme dayandığı için hesaplanan tarih bir gün sapabilir; arayüz bunu
  /// kullanıcıya söylemek zorunda.
  final bool isEstimated;

  const ReligiousDay({
    required this.date,
    required this.name,
    required this.kind,
    this.isEstimated = true,
  });

  /// Kandil ve bayram geceleri akşam namazıyla başlar; hatırlatma o akşama
  /// konur.
  bool get startsAtMaghrib => kind == ReligiousDayKind.kandil;
}
