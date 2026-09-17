import 'dart:async';
import 'dart:io';

import '../../core/exceptions/api_exception.dart';
import '../../core/exceptions/parse_exception.dart';
import '../../features/location/data/gps_location_service.dart';
import '../../features/location/data/places_api.dart';
import '../../l10n/app_localizations.dart';

/// Konum ekleme/GPS akışındaki hata nesnesini kullanıcı metnine çevirir.
///
/// Servisler metin değil kararlı anahtar/tip üretir; çeviri burada seçilir.
/// Ağ, zaman aşımı, sunucu hatası ve bozuk gövde kullanıcı için tek anlamdır:
/// sunucuya ulaşılamadı.
String locationErrorText(AppLocalizations l10n, Object error) {
  if (error is GpsLocationException) {
    return switch (error.key) {
      GpsLocationService.servicesOffKey => l10n.locationServicesOff,
      GpsLocationService.permissionDeniedForeverKey =>
        l10n.locationPermissionDenied,
      _ => l10n.errorLocationPermission,
    };
  }
  if (error is NoCoverageException) return l10n.locationNoCoverage;
  if (error is PlacesNotReadyException ||
      error is ApiException ||
      error is ParseException ||
      error is SocketException ||
      error is TimeoutException ||
      error is HttpException) {
    return l10n.locationNeedsInternet;
  }
  return l10n.errorGenericWith(error.toString());
}
