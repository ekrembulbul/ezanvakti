import 'package:ezanvakti/core/models/qr_code_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toMap/fromMap kayipsiz gidip gelir', () {
    final entry = QrCodeEntry(
      id: 'q1',
      label: 'Banyo aynasi',
      payload: 'EZAN-QR-123',
      createdAt: DateTime(2026, 8, 31, 9, 30),
    );
    final restored = QrCodeEntry.fromMap(entry.toMap());
    expect(restored.id, entry.id);
    expect(restored.label, entry.label);
    expect(restored.payload, entry.payload);
    expect(restored.createdAt, entry.createdAt);
  });
}
