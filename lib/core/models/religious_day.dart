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

/// Dini günlerin dile bağlı olmayan kimlikleri.
enum ReligiousDayId {
  newYear,
  ashura,
  mawlid,
  regaib,
  miraj,
  baraat,
  ramadanStart,
  qadr,
  eidFitr,
  arafah,
  eidAdha,
}

/// Bir dini gün: miladi tarihi, kimliği ve nasıl belirlendiği.
///
/// Ad **taşımaz**: metin çeviriden gelir. Ada göre eşleşme yapan kod
/// çeviri gelince sessizce bozulurdu.
class ReligiousDay {
  /// Miladi karşılık (gün başına yuvarlanmış).
  final DateTime date;

  final ReligiousDayId id;
  final ReligiousDayKind kind;

  /// Tarih hicri takvimden **hesaplandı** mı. Diyanet ilanları astronomik
  /// gözleme dayandığı için hesaplanan tarih bir gün sapabilir; arayüz bunu
  /// kullanıcıya söylemek zorunda.
  final bool isEstimated;

  const ReligiousDay({
    required this.date,
    required this.id,
    required this.kind,
    this.isEstimated = true,
  });

  /// Kandil ve bayram geceleri akşam namazıyla başlar; hatırlatma o akşama
  /// konur.
  bool get startsAtMaghrib => kind == ReligiousDayKind.kandil;
}
