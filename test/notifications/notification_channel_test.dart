import 'package:ezanvakti/core/constants/notification_sounds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sessiz ses ya da sessiz pencere sessiz kanala gider', () {
    expect(
      NotificationSounds.androidChannelFor(
        NotificationSounds.silent,
        silent: false,
      ),
      NotificationSounds.androidSilentChannel,
    );
    expect(
      NotificationSounds.androidChannelFor(
        NotificationSounds.beep,
        silent: true,
      ),
      NotificationSounds.androidSilentChannel,
    );
  });

  test('kisa ton kendi kanalina, diger her sey sistem kanalina', () {
    expect(
      NotificationSounds.androidChannelFor(
        NotificationSounds.beep,
        silent: false,
      ),
      NotificationSounds.androidBeepChannel,
    );
    expect(
      NotificationSounds.androidChannelFor(
        NotificationSounds.system,
        silent: false,
      ),
      'ezan_vakti_channel',
    );
    expect(
      NotificationSounds.androidChannelFor(null, silent: false),
      'ezan_vakti_channel',
    );
  });

  test('kanal kimlikleri sabit kalir', () {
    // Kimlik degisirse kullanicinin sistem ayarlarindaki kanal tercihleri
    // kaybolur.
    expect(NotificationSounds.androidSystemChannel, 'ezan_vakti_channel');
    expect(NotificationSounds.androidBeepChannel, 'ezan_vakti_beep');
    expect(NotificationSounds.androidSilentChannel, 'ezan_vakti_silent');
  });
}
