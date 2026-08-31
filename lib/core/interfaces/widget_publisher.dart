import '../../features/home_widget/domain/widget_snapshot.dart';

/// Widget'a snapshot yayınlamanın soyutlaması.
///
/// Testlerde fake ile değiştirilir; iOS dışı platformlarda [NoopWidgetPublisher]
/// kullanılır.
abstract class WidgetPublisher {
  /// Kullanıcının 12/24 saat tercihini widget'a taşır. Snapshot'tan ayrı
  /// bir anahtar: tercih değişince vakit verisini yeniden yazmak gerekmiyor.
  Future<void> publishTimeFormat(String storageValue);

  Future<void> publish(WidgetSnapshot snapshot);
}
