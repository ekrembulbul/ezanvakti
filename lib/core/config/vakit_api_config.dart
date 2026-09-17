/// vakit-api sunucu adresi.
///
/// Derleme zamanında verilir: `--dart-define=VAKIT_API_BASE_URL=https://api.<domain>`.
/// Varsayılan yerel geliştirme sunucusudur (Android emülatöründe host için
/// `http://10.0.2.2:8080` geç). Sürüm derlemeleri bu değeri mutlaka geçer.
class VakitApiConfig {
  const VakitApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'VAKIT_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );
}
