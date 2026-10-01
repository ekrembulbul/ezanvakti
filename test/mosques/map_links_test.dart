import 'package:ezanvakti/features/mosques/domain/map_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const center = (lat: 41.0, lon: 29.0);

  String uri(
    MapApp app, {
    String query = 'cami',
    LatLon? center,
    bool android = false,
    bool appleUnified = true,
  }) => mosqueSearchUri(
    app: app,
    query: query,
    center: center,
    android: android,
    appleUnified: appleUnified,
  ).toString();

  group('mosqueSearchUri', () {
    test('Android merkezli geo bağlantısı', () {
      expect(
        uri(MapApp.google, center: center, android: true),
        'geo:41.0,29.0?z=14&q=cami',
      );
    });

    test('Android merkezsiz arama konum adını sorguda taşır', () {
      expect(
        uri(MapApp.google, query: 'cami Kadıköy', android: true),
        'geo:0,0?q=cami%20Kad%C4%B1k%C3%B6y',
      );
    });

    test('Apple iOS 18.4+ birleşik arama bağlantısı', () {
      expect(
        uri(MapApp.apple, center: center),
        'https://maps.apple.com/search?query=cami&center=41.0,29.0&span=0.03,0.03',
      );
    });

    test('Apple eski sürüm bağlantısı', () {
      expect(
        uri(MapApp.apple, center: center, appleUnified: false),
        'https://maps.apple.com/?q=cami&sll=41.0,29.0&z=14',
      );
    });

    test('Apple merkezsiz', () {
      expect(
        uri(MapApp.apple, query: 'cami Şile'),
        'https://maps.apple.com/search?query=cami%20%C5%9Eile',
      );
      expect(
        uri(MapApp.apple, query: 'cami', appleUnified: false),
        'https://maps.apple.com/?q=cami',
      );
    });

    test('Google iOS uygulama bağlantısı', () {
      expect(
        uri(MapApp.google, center: center),
        'comgooglemaps://?q=cami&center=41.0,29.0&zoom=14',
      );
      expect(uri(MapApp.google), 'comgooglemaps://?q=cami');
    });

    test('Yandex bağlantısında boylam önce gelir', () {
      expect(
        uri(MapApp.yandex, center: center),
        'yandexmaps://maps.yandex.com/?text=cami&ll=29.0,41.0&z=14',
      );
    });

    test('Arapça sorgu yüzde kodlanır', () {
      expect(
        uri(MapApp.google, query: 'مسجد', center: center, android: true),
        'geo:41.0,29.0?z=14&q=%D9%85%D8%B3%D8%AC%D8%AF',
      );
    });
  });

  group('appleUnifiedMapsSupported', () {
    test('18.4 ve sonrası', () {
      expect(appleUnifiedMapsSupported('18.4'), isTrue);
      expect(
        appleUnifiedMapsSupported('Version 18.4.1 (Build 22E252)'),
        isTrue,
      );
      expect(appleUnifiedMapsSupported('26.0'), isTrue);
    });

    test('18.4 öncesi ve okunamayan', () {
      expect(
        appleUnifiedMapsSupported('Version 18.3.1 (Build 22D72)'),
        isFalse,
      );
      expect(appleUnifiedMapsSupported('17.5'), isFalse);
      expect(appleUnifiedMapsSupported(''), isFalse);
    });
  });
}
