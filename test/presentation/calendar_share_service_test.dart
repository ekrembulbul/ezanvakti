import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/presentation/services/calendar_share_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final location = Location(
    id: 'l1',
    province: 'İstanbul',
    district: 'Şişli',
    type: LocationType.manual,
  );

  test('dosya adi turkce karakter ve bosluk icermez', () {
    final name = CalendarShareService.fileNameFor(
      location,
      DateTime(2026, 9, 4),
    );
    expect(name, endsWith('.png'));
    expect(name, matches(RegExp(r'^[a-z0-9.\-]+$')));
    expect(name, contains('2026-09'));
  });

  test('paylasim metni konum ve ayi tasir', () {
    final caption = CalendarShareService.captionFor(
      location,
      DateTime(2026, 9, 4),
    );
    expect(caption, contains('2026/09'));
    expect(caption, contains(location.displayName));
  });

  test('cizim alani yoksa sessizce basarisiz olmaz', () async {
    final result = await CalendarShareService().shareTable(
      boundary: null,
      location: location,
      date: DateTime(2026, 9, 4),
    );
    expect(result, isFalse);
  });
}
