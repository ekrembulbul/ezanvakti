/// Aladhan API'sinden 200 dışı bir HTTP durum koduyla dönen hatalar.
///
/// Çağıranların geçici hataları (rate limit 429, sunucu 5xx) kalıcı
/// hatalardan ayırt edebilmesi için durum kodunu taşır. Bu sayede üst
/// katman, geçici hatalarda önbelleğe düşmek gibi doğru kararı verebilir.
class ApiException implements Exception {
  final int statusCode;
  final String? context;

  ApiException(this.statusCode, {this.context});

  /// İstek hızı sınırı aşıldı (Too Many Requests).
  bool get isRateLimited => statusCode == 429;

  /// Sunucu kaynaklı geçici hata.
  bool get isServerError => statusCode >= 500;

  /// Yeniden denemenin anlamlı olduğu geçici hatalar.
  bool get isTransient => isRateLimited || isServerError;

  @override
  String toString() {
    final buffer = StringBuffer('ApiException: HTTP $statusCode');
    if (context != null) {
      buffer.write(' ($context)');
    }
    return buffer.toString();
  }
}
