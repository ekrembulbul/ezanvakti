import '../../features/home_widget/domain/widget_snapshot.dart';

/// Widget'a snapshot yayınlamanın soyutlaması.
///
/// Testlerde fake ile değiştirilir; iOS dışı platformlarda [NoopWidgetPublisher]
/// kullanılır.
abstract class WidgetPublisher {
  Future<void> publish(WidgetSnapshot snapshot);
}
