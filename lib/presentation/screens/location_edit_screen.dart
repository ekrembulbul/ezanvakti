import 'package:flutter/material.dart';
import '../../l10n/l10n_extensions.dart';

import '../../core/models/location.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../features/location/domain/location_repository.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';

/// Kayıtlı bir konumun özel adını düzenler.
///
/// Konumun yeri (ilçe/koordinat) burada değişmez; güncellenmiş konum geri
/// döndürülür ki çağıran taraf (aktifse) ekranı tazeleyebilsin.
class LocationEditScreen extends StatefulWidget {
  final LocationRepository locationRepository;
  final Location location;

  const LocationEditScreen({
    super.key,
    required this.locationRepository,
    required this.location,
  });

  @override
  State<LocationEditScreen> createState() => _LocationEditScreenState();
}

class _LocationEditScreenState extends State<LocationEditScreen> {
  late final TextEditingController _customNameController;

  @override
  void initState() {
    super.initState();
    _customNameController = TextEditingController(
      text: widget.location.customName ?? '',
    );
  }

  /// Yardımcı metotların hepsi renk okuyor; tek kısayol.
  AppTokens get tokens => context.tokens;

  @override
  void dispose() {
    _customNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final customName = _customNameController.text.trim();
    // copyWith `??` ile null'ı yazamaz: özel ad silindiyse açık kurulum.
    final updated = customName.isEmpty
        ? _withoutCustomName(widget.location)
        : widget.location.copyWith(customName: customName);

    try {
      await widget.locationRepository.updateLocation(updated);
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(context.l10n.locationSaveFailed('$e')),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
      }
    }
  }

  static Location _withoutCustomName(Location location) => Location(
    id: location.id,
    province: location.province,
    district: location.district,
    latitude: location.latitude,
    longitude: location.longitude,
    type: location.type,
    cityId: location.cityId,
    stateId: location.stateId,
    countryId: location.countryId,
    displayLabel: location.displayLabel,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(title: context.l10n.locationEditTitle),
      body: AppSurface(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    _buildLocationHeader(),
                    const SizedBox(height: 24),
                    _buildCustomNameField(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationHeader() {
    final location = widget.location;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            location.type == LocationType.gps
                ? Icons.my_location_rounded
                : Icons.location_on_rounded,
            color: tokens.accent,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              location.displayName,
              style: AppTypography.rowTitle.copyWith(color: tokens.accent),
            ),
          ),
        ],
      ),
    );
  }

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
        style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
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

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _save,
      style: ElevatedButton.styleFrom(
        backgroundColor: tokens.accent,
        foregroundColor: tokens.backgroundStops.last,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(context.l10n.actionSave),
    );
  }
}
