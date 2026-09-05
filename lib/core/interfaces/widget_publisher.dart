import '../../features/home_widget/domain/widget_snapshot.dart';
import '../models/appearance_settings.dart';

/// Widget'a snapshot yayınlamanın soyutlaması.
///
/// Testlerde fake ile değiştirilir; iOS dışı platformlarda [NoopWidgetPublisher]
/// kullanılır.
abstract class WidgetPublisher {
  /// Kullanıcının 12/24 saat tercihini widget'a taşır. Snapshot'tan ayrı
  /// bir anahtar: tercih değişince vakit verisini yeniden yazmak gerekmiyor.
  Future<void> publishTimeFormat(String storageValue);

  /// Görünüm ayarlarını (tema, vakte göre renk, sabit palet) widget'a taşır.
  ///
  /// Widget kendi sürecinde çalışır ve uygulamanın temasını göremez; bu yayın
  /// olmadan yalnızca cihazın görünümünü izler ve uygulama koyuyken açık kalır.
  Future<void> publishAppearance(AppearanceSettings settings);

  Future<void> publish(WidgetSnapshot snapshot);
}
