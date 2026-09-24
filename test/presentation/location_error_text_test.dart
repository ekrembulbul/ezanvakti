import 'dart:io';

import 'package:ezanvakti/core/exceptions/api_exception.dart';
import 'package:ezanvakti/features/location/data/gps_location_service.dart';
import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:ezanvakti/presentation/utils/location_error_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/l10n_helper.dart';

void main() {
  test('hata nesnesi kullaniciya uygun metne cevrilir', () async {
    final l10n = await loadTestL10n();

    expect(
      locationErrorText(
        l10n,
        const GpsLocationException(GpsLocationService.permissionRequiredKey),
      ),
      l10n.errorLocationPermission,
    );
    expect(
      locationErrorText(
        l10n,
        const GpsLocationException(GpsLocationService.servicesOffKey),
      ),
      l10n.locationServicesOff,
    );
    expect(
      locationErrorText(
        l10n,
        const GpsLocationException(
          GpsLocationService.permissionDeniedForeverKey,
        ),
      ),
      l10n.locationPermissionDenied,
    );
    expect(
      locationErrorText(l10n, NoCoverageException()),
      l10n.locationNoCoverage,
    );
    expect(
      locationErrorText(l10n, PlacesNotReadyException()),
      l10n.locationNeedsInternet,
    );
    expect(
      locationErrorText(l10n, const SocketException('x')),
      l10n.locationNeedsInternet,
    );
    expect(
      locationErrorText(l10n, ApiException(500, context: 'x')),
      l10n.locationNeedsInternet,
    );
    expect(
      locationErrorText(l10n, Exception('boom')),
      l10n.errorGenericWith('Exception: boom'),
    );
  });
}
