import 'package:ezanvakti/core/models/general_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'sabit satır varsayılan açık; kayıt okunur, bozuk değer varsayılana düşer',
    () {
      expect(const GeneralSettings().nextPrayerNotification, isTrue);
      expect(
        GeneralSettings.fromMap({
          GeneralSettings.nextPrayerNotificationKey: 'false',
        }).nextPrayerNotification,
        isFalse,
      );
      expect(
        GeneralSettings.fromMap({
          GeneralSettings.nextPrayerNotificationKey: 'evet',
        }).nextPrayerNotification,
        isTrue,
      );
      final off = const GeneralSettings().copyWith(
        nextPrayerNotification: false,
      );
      expect(GeneralSettings.fromMap(off.toMap()), off);
    },
  );
}
