import 'dart:async';
import 'dart:convert';

import 'package:ezanvakti/features/location/data/gps_location_service.dart';
import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeGeolocator extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  Object? positionError;
  LocationAccuracy? requestedAccuracy;
  Duration? requestedTimeLimit;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    requestedAccuracy = locationSettings?.accuracy;
    requestedTimeLimit = locationSettings?.timeLimit;
    if (positionError case final error?) throw error;
    return Position(
      latitude: 40.99,
      longitude: 29.03,
      timestamp: DateTime(2026, 10, 1),
      accuracy: 20,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  late _FakeGeolocator geo;
  late int apiCalls;
  late GpsLocationService service;

  setUp(() {
    geo = _FakeGeolocator();
    GeolocatorPlatform.instance = geo;
    apiCalls = 0;
    service = GpsLocationService(
      api: PlacesApi(
        client: MockClient((req) async {
          apiCalls++;
          return http.Response(
            jsonEncode({
              'city': {
                'id': 9541,
                'name': 'Kadıköy',
                'stateName': 'İstanbul',
                'displayName': 'Kadıköy, İstanbul',
                'stateId': 539,
                'countryId': 2,
                'isCentre': false,
              },
              'distanceKm': 1.2,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
        baseUrl: 'https://api.test',
      ),
    );
  });

  test('currentPosition koordinatı sunucuya sormadan döner', () async {
    final position = await service.currentPosition();
    expect(position.lat, 40.99);
    expect(position.lon, 29.03);
    expect(apiCalls, 0);
    expect(geo.requestedAccuracy, LocationAccuracy.medium);
    expect(geo.requestedTimeLimit, const Duration(seconds: 10));
  });

  test('servis kapalıysa servicesOff hatası', () async {
    geo.serviceEnabled = false;
    await expectLater(
      service.currentPosition(),
      throwsA(
        isA<GpsLocationException>().having(
          (e) => e.key,
          'key',
          GpsLocationService.servicesOffKey,
        ),
      ),
    );
  });

  test('izin yok ve açıklama onaylanmadıysa permissionRequired', () async {
    geo.permission = LocationPermission.denied;
    await expectLater(
      service.currentPosition(requestPermission: () async => false),
      throwsA(
        isA<GpsLocationException>().having(
          (e) => e.key,
          'key',
          GpsLocationService.permissionRequiredKey,
        ),
      ),
    );
  });

  test('zaman aşımı kararlı anahtarla bildirilir', () async {
    geo.positionError = TimeoutException('slow');
    await expectLater(
      service.currentPosition(),
      throwsA(
        isA<GpsLocationException>().having(
          (e) => e.key,
          'key',
          GpsLocationService.timeoutKey,
        ),
      ),
    );
  });

  test('locate yüksek doğrulukla alır ve ilçeye çözer', () async {
    final resolution = await service.locate();
    expect(apiCalls, 1);
    expect(geo.requestedAccuracy, LocationAccuracy.high);
    expect(resolution.location.latitude, 40.99);
  });
}
