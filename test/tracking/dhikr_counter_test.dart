import 'package:ezanvakti/features/tracking/domain/dhikr_counter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tur ve kalan hesabi', () {
    const state = DhikrState(count: 35, target: 33);
    expect(state.laps, 1);
    expect(state.inLap, 2);
    expect(state.remaining, 31);
  });

  test('hedefe tam ulasinca tur artar, kalan hedef kadar olur', () {
    const state = DhikrState(count: 33, target: 33);
    expect(state.laps, 1);
    expect(state.inLap, 0);
    expect(state.remaining, 33);
  });

  test('sifirdan baslangic', () {
    const state = DhikrState(count: 0, target: 99);
    expect(state.laps, 0);
    expect(state.inLap, 0);
    expect(state.remaining, 99);
  });

  test('gecersiz hedef bir sayilir; sifira bolme olmaz', () {
    const state = DhikrState(count: 5, target: 0);
    expect(state.laps, 5);
    expect(state.remaining, 1);
  });

  test('artirma ve sifirlama', () {
    const state = DhikrState(count: 5, target: 33);
    expect(state.increment().count, 6);
    expect(state.reset().count, 0);
    expect(state.reset().target, 33, reason: 'hedef korunur');
  });

  test('sayac negatife dusmez', () {
    const state = DhikrState(count: 0, target: 33);
    expect(state.decrement().count, 0);
    expect(const DhikrState(count: 3, target: 33).decrement().count, 2);
  });

  test('hedef listesi kapali ve sirali', () {
    expect(kDhikrTargets, [33, 99, 100, 500, 1000]);
  });
}
