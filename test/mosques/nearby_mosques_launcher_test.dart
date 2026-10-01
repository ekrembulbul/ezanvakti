import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/features/mosques/domain/map_links.dart';
import 'package:ezanvakti/presentation/services/nearby_mosques_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

class _SettingsStorage implements LocalStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> getSetting(String key) async => values[key];

  @override
  Future<void> setSetting(String key, String value) async =>
      values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_SettingsStorage.${invocation.memberName}');
}

void main() {
  late _SettingsStorage storage;
  late Set<String> installedSchemes;
  late List<Uri> opened;
  late bool openResult;

  NearbyMosquesLauncher launcher({bool isIOS = true, String os = '26.0'}) =>
      NearbyMosquesLauncher(
        storage: storage,
        isIOS: isIOS,
        osVersion: os,
        canOpen: (uri) async => installedSchemes.contains(uri.scheme),
        open: (uri) async {
          opened.add(uri);
          return openResult;
        },
      );

  setUp(() {
    storage = _SettingsStorage();
    installedSchemes = {};
    opened = [];
    openResult = true;
  });

  test('iOS: yalnız Apple Haritalar varsa liste tek', () async {
    expect(await launcher().installedApps(), [MapApp.apple]);
  });

  test('iOS: Google ve Yandex yüklüyse sıralı listelenir', () async {
    installedSchemes = {'comgooglemaps', 'yandexmaps'};
    expect(await launcher().installedApps(), [
      MapApp.apple,
      MapApp.google,
      MapApp.yandex,
    ]);
  });

  test('kayıtlı uygulama yüklüyse döner, silinmişse null', () async {
    installedSchemes = {'comgooglemaps'};
    await launcher().saveApp(MapApp.google);
    expect(await launcher().savedApp(), MapApp.google);
    installedSchemes = {};
    expect(await launcher().savedApp(), isNull);
  });

  test('saveApp(null) seçimi temizler', () async {
    await launcher().saveApp(MapApp.apple);
    await launcher().saveApp(null);
    expect(await launcher().savedApp(), isNull);
  });

  test('launch iOS sürümüne göre Apple bağlantısı açar', () async {
    await launcher(
      os: 'Version 18.3 (Build 22D63)',
    ).launch(app: MapApp.apple, query: 'cami', center: (lat: 41.0, lon: 29.0));
    expect(
      opened.single.toString(),
      'https://maps.apple.com/?q=cami&sll=41.0,29.0&z=14',
    );
  });

  test('Android geo bağlantısı açar', () async {
    final ok = await launcher(
      isIOS: false,
    ).launch(app: MapApp.google, query: 'cami', center: (lat: 41.0, lon: 29.0));
    expect(ok, isTrue);
    expect(opened.single.toString(), 'geo:41.0,29.0?z=14&q=cami');
  });

  test('açılamazsa false döner', () async {
    openResult = false;
    expect(await launcher().launch(app: MapApp.apple, query: 'cami'), isFalse);
  });
}
