import 'package:flutter/material.dart';

import '../../../core/models/location.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/app_logger.dart';
import '../../../features/location/data/gps_location_service.dart';
import '../../../features/mosques/domain/map_links.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../services/nearby_mosques_launcher.dart';
import '../common/option_picker.dart';

enum _Origin { prayerLocation, currentLocation }

/// "Yakındaki camiler": konumu (vakit konumu ya da telefonun konumu) sorar,
/// gerekirse harita uygulamasını seçtirir ve aramayı o koordinatın çevresinde
/// harita uygulamasında açar.
Future<void> showNearbyMosquesFlow(
  BuildContext context, {
  required Location location,
  required NearbyMosquesLauncher launcher,
  required GpsLocationService gps,
}) async {
  final l10n = context.l10n;
  var origin = await showOptionPicker<_Origin?>(
    context: context,
    title: l10n.toolsMosques,
    selected: null,
    items: [
      OptionItem(
        value: _Origin.prayerLocation,
        label: l10n.mosquesByPrayerLocation(location.displayName),
        icon: Icons.schedule_rounded,
      ),
      OptionItem(
        value: _Origin.currentLocation,
        label: l10n.mosquesByCurrentLocation,
        icon: Icons.my_location_rounded,
      ),
    ],
  );
  if (origin == null || !context.mounted) return;

  LatLon? center;
  if (origin == _Origin.currentLocation) {
    try {
      center = await gps.currentPosition(
        requestPermission: () => _confirm(
          context,
          title: l10n.locationPermissionTitle,
          body: l10n.mosquesPermissionBody,
          action: l10n.locationPermissionAllow,
        ),
      );
    } catch (e, s) {
      // İzin/servis hataları ve platformun beklenmeyen hataları aynı yoldan:
      // kullanıcıya vakit konumuyla aramayı öner.
      AppLogger().warning('Nearby mosques: location unavailable', e, s);
      if (!context.mounted) return;
      final fallback = await _confirm(
        context,
        body: l10n.mosquesLocationFailed,
        action: l10n.mosquesSearchAction,
      );
      if (!fallback || !context.mounted) return;
      origin = _Origin.prayerLocation;
    }
  }

  var query = l10n.mosqueSearchQuery;
  if (origin == _Origin.prayerLocation) {
    final lat = location.latitude;
    final lon = location.longitude;
    if (lat != null && lon != null) {
      center = (lat: lat, lon: lon);
    } else {
      // Özel ad ("Ev") harita uygulamasında yer olarak çözülmez; ilçe adı kullanılır.
      query = '$query ${location.copyWith(customName: '').displayName}';
    }
  }

  if (!context.mounted) return;
  final app = await _pickApp(context, launcher, l10n);
  if (app == null || !context.mounted) return;
  final ok = await launcher.launch(app: app, query: query, center: center);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.mosquesOpenFailed)));
  }
}

/// Android'de seçimi sistem yapar; iOS'ta hatırlanan ya da tek yüklü uygulama,
/// yoksa kullanıcıya sorulur ve seçim hatırlanır.
Future<MapApp?> _pickApp(
  BuildContext context,
  NearbyMosquesLauncher launcher,
  AppLocalizations l10n,
) async {
  if (!launcher.isIOS) return MapApp.google;
  final saved = await launcher.savedApp();
  if (saved != null) return saved;
  final installed = await launcher.installedApps();
  if (installed.length == 1) return installed.single;
  if (!context.mounted) return null;
  final picked = await showOptionPicker<MapApp?>(
    context: context,
    title: l10n.mapAppPickerTitle,
    selected: null,
    items: [
      for (final app in installed)
        OptionItem(value: app, label: mapAppLabel(l10n, app)),
    ],
  );
  if (picked != null && !await launcher.asksEachTime()) {
    await launcher.saveApp(picked);
  }
  return picked;
}

String mapAppLabel(AppLocalizations l10n, MapApp app) => switch (app) {
  MapApp.apple => l10n.mapAppApple,
  MapApp.google => l10n.mapAppGoogle,
  MapApp.yandex => l10n.mapAppYandex,
};

Future<bool> _confirm(
  BuildContext context, {
  String? title,
  required String body,
  required String action,
}) async {
  final tokens = context.tokens;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: tokens.backgroundStops[1],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: title == null
          ? null
          : Text(
              title,
              style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
            ),
      content: Text(
        body,
        style: AppTypography.rowSubtitle.copyWith(
          color: tokens.textSecondary,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.actionCancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: tokens.accent,
            foregroundColor: tokens.backgroundStops.last,
          ),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}
