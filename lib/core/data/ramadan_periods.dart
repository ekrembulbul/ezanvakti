import '../../features/ramadan/domain/ramadan_period.dart';

const _source = 'https://vakithesaplama.diyanet.gov.tr';
final List<RamadanPeriod> ramadanPeriods = List.unmodifiable([
  RamadanPeriod(
    hijriYear: 1445,
    start: DateTime(2024, 3, 11),
    eid: DateTime(2024, 4, 10),
    sourceUrls: ['$_source/dinigunler.php?yil=2024'],
  ),
  RamadanPeriod(
    hijriYear: 1446,
    start: DateTime(2025, 3, 1),
    eid: DateTime(2025, 3, 30),
    sourceUrls: ['$_source/dinigunler.php?yil=2025'],
  ),
  RamadanPeriod(
    hijriYear: 1447,
    start: DateTime(2026, 2, 19),
    eid: DateTime(2026, 3, 20),
    sourceUrls: ['$_source/dinigunler.php?yil=2026'],
  ),
  RamadanPeriod(
    hijriYear: 1448,
    start: DateTime(2027, 2, 8),
    eid: DateTime(2027, 3, 9),
    sourceUrls: ['$_source/icerik.php?icerik=154'],
  ),
  RamadanPeriod(
    hijriYear: 1449,
    start: DateTime(2028, 1, 28),
    eid: DateTime(2028, 2, 26),
    sourceUrls: ['$_source/icerik.php?icerik=185'],
  ),
  RamadanPeriod(
    hijriYear: 1450,
    start: DateTime(2029, 1, 16),
    eid: DateTime(2029, 2, 14),
    sourceUrls: ['$_source/icerik.php?icerik=186'],
  ),
  RamadanPeriod(
    hijriYear: 1451,
    start: DateTime(2030, 1, 5),
    eid: DateTime(2030, 2, 4),
    sourceUrls: ['$_source/icerik.php?icerik=187'],
  ),
  RamadanPeriod(
    hijriYear: 1452,
    start: DateTime(2030, 12, 26),
    eid: DateTime(2031, 1, 24),
    sourceUrls: [
      '$_source/icerik.php?icerik=187',
      '$_source/icerik.php?icerik=188',
    ],
  ),
]);

RamadanPeriod defaultRamadanPeriod(DateTime now) => ramadanPeriods.firstWhere(
  (period) => DateTime(now.year, now.month, now.day).isBefore(period.eid),
  orElse: () => ramadanPeriods.last,
);
