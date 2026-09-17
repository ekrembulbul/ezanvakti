import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/location.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../core/utils/app_logger.dart';
import '../../features/location/data/gps_location_service.dart';
import '../../features/location/data/places_api.dart';
import '../../features/location/domain/location_repository.dart';
import '../../l10n/l10n_extensions.dart';
import '../utils/location_error_text.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/location/location_widgets.dart';
import '../widgets/location/place_search_panel.dart';

/// Konum ekleme: üstte il/ilçe araması, altında "Konumumu kullan".
///
/// Seçim bir Diyanet ilçesidir (`cityId`); koordinat manuelde ilçe merkezi,
/// GPS'te cihazınki. GPS çözümlemesi bir onay bandıyla gösterilir: yanlış ilçe
/// bulunduysa kullanıcı aramaya döner. İlk konumsa kayıttan sonra [AppState]
/// üzerinden ana ekrana geçilir; listeden açıldıysa kayıt geri döndürülür ve
/// aktifleştirme çağırana kalır.
class LocationAddScreen extends StatefulWidget {
  final LocationRepository locationRepository;
  final PlacesApi placesApi;
  final GpsLocationService gpsService;
  final bool fromLocationList;

  const LocationAddScreen({
    super.key,
    required this.locationRepository,
    required this.placesApi,
    required this.gpsService,
    this.fromLocationList = false,
  });

  @override
  State<LocationAddScreen> createState() => _LocationAddScreenState();
}

class _LocationAddScreenState extends State<LocationAddScreen> {
  final _customNameController = TextEditingController();

  PlaceMatch? _selected;
  GpsResolution? _pendingGps;
  bool _gpsBusy = false;
  String? _gpsError;
  bool _saving = false;

  /// Bu ekranda çok sayıda yardımcı metot renk okuyor; tek kısayol.
  AppTokens get tokens => context.tokens;

  @override
  void dispose() {
    _customNameController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() {
      _gpsBusy = true;
      _gpsError = null;
    });
    // `await` sonrası context kullanılmaz; çeviri şimdi yakalanıyor.
    final l10n = context.l10n;
    try {
      final resolution = await widget.gpsService.locate(
        requestPermission: _showLocationRationale,
      );
      if (!mounted) return;
      setState(() => _pendingGps = resolution);
    } catch (e) {
      AppLogger().warning('GPS detection failed', e);
      if (mounted) setState(() => _gpsError = locationErrorText(l10n, e));
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  Future<bool> _showLocationRationale() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.backgroundStops[1],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.l10n.locationPermissionTitle,
          style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
        ),
        content: Text(
          context.l10n.locationPermissionBody,
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
            child: Text(context.l10n.locationPermissionAllow),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save(Location location) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // Silinip yeniden eklenen yerin eski vakit kayıtları konumla silinmez;
      // taze çekim için bu kimliğin önbelleği temizlenir.
      await widget.locationRepository.clearPrayerTimeCache(location.id);
      if (location.type == LocationType.gps) {
        await widget.locationRepository.saveOrUpdateGpsLocation(location);
      } else {
        await widget.locationRepository.saveLocation(location);
      }
      if (!mounted) return;
      if (widget.fromLocationList) {
        Navigator.of(context).pop(location);
        return;
      }
      await widget.locationRepository.setActiveLocation(location);
      if (mounted) context.read<AppState>().setActiveLocation(location);
    } catch (e) {
      AppLogger().error('Location save failed', e);
      if (mounted) {
        _showSnackBar(context.l10n.locationSaveFailed('$e'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onManualSave() async {
    final place = _selected;
    if (place == null) return;
    final customName = _customNameController.text.trim();
    final location = place
        .toLocation(type: LocationType.manual)
        .copyWith(customName: customName.isEmpty ? null : customName);
    await _save(location);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    // Önceki snackbar'ı hemen kaldır; yeni mesaj beklemeden gösterilsin.
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : tokens.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingGps = _pendingGps;
    final selected = _selected;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(
        title: context.l10n.locationAddTitle,
        showBack: widget.fromLocationList,
      ),
      body: AppSurface(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: pendingGps != null
              ? _buildGpsConfirm(pendingGps)
              : selected != null
              ? _buildSelection(selected)
              : _buildSearch(),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.locationsEmptyHint,
          textAlign: TextAlign.center,
          style: AppTypography.rowSubtitle.copyWith(
            color: tokens.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: PlaceSearchPanel(
            api: widget.placesApi,
            autofocus: false,
            onSelected: (match) => setState(() => _selected = match),
          ),
        ),
        if (_gpsError != null) ...[
          const SizedBox(height: 12),
          LocationErrorCard(error: _gpsError!),
        ],
        const SizedBox(height: 12),
        LocationChoiceButton(
          icon: Icons.my_location_rounded,
          title: _gpsBusy
              ? context.l10n.locationGettingPosition
              : context.l10n.locationUseGps,
          subtitle: context.l10n.locationAutoDetect,
          isLoading: _gpsBusy,
          isHighlighted: true,
          onTap: _detectLocation,
        ),
      ],
    );
  }

  Widget _buildGpsConfirm(GpsResolution resolution) {
    final location = resolution.location;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.my_location_rounded, size: 48, color: tokens.accent),
        const SizedBox(height: 20),
        Text(
          context.l10n.locationGpsConfirm(location.displayName),
          textAlign: TextAlign.center,
          style: AppTypography.rowTitle.copyWith(
            color: tokens.textPrimary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _saving ? null : () => _save(location),
          style: _primaryButtonStyle(),
          child: Text(context.l10n.actionConfirm),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => setState(() => _pendingGps = null),
          style: OutlinedButton.styleFrom(
            foregroundColor: tokens.textSecondary,
            side: BorderSide(color: tokens.border),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(context.l10n.locationChange),
        ),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildSelection(PlaceMatch match) {
    final preview = match.toLocation(type: LocationType.manual);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 4),
            children: [
              LocationSelectionConfirm(location: preview),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _selected = null),
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: Text(context.l10n.locationChange),
                  style: TextButton.styleFrom(foregroundColor: tokens.accent),
                ),
              ),
              const SizedBox(height: 8),
              _buildCustomNameField(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _saving ? null : _onManualSave,
          style: _primaryButtonStyle(),
          child: Text(
            context.l10n.actionSave,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
      ],
    );
  }

  ButtonStyle _primaryButtonStyle() => ElevatedButton.styleFrom(
    backgroundColor: tokens.accent,
    foregroundColor: tokens.backgroundStops.last,
    disabledBackgroundColor: tokens.border,
    disabledForegroundColor: tokens.textTertiary,
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  Widget _buildCustomNameField() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: TextField(
        controller: _customNameController,
        style: TextStyle(color: tokens.textPrimary),
        decoration: InputDecoration(
          labelText: context.l10n.locationCustomName,
          labelStyle: TextStyle(color: tokens.textTertiary),
          hintText: context.l10n.locationCustomNameHint,
          hintStyle: TextStyle(color: tokens.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
          prefixIcon: Icon(
            Icons.label_outline_rounded,
            color: tokens.textTertiary,
          ),
        ),
      ),
    );
  }
}
