import 'package:flutter/material.dart';

import '../../core/models/calculation_params.dart';
import '../../core/models/calculation_settings.dart';
import '../../core/models/location.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../features/location/domain/location_repository.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/grouped_list.dart';
import '../widgets/location/calculation_params_selector.dart';

/// Kayıtlı bir konumun hesaplama parametrelerini ve özel ismini düzenler.
///
/// Konum varsayılan olarak **genel hesaplama ayarını** kullanır; kullanıcı bu
/// konuma özel bir override tanımlayabilir. Konumun yeri (il/ilçe/koordinat)
/// burada değişmez. Parametreler değişirse o konumun vakit önbelleği temizlenip
/// güncellenmiş konum geri döndürülür ki çağıran taraf (aktifse) yeniden
/// yükleyip bildirimleri planlayabilsin.
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
  late bool _useGlobal;
  late int _method;
  late AsrSchool _school;
  late LatitudeAdjustment _latitudeAdjustment;

  CalculationSettings _globalSettings = CalculationSettings.defaults;

  @override
  void initState() {
    super.initState();
    final location = widget.location;
    _customNameController = TextEditingController(
      text: location.customName ?? '',
    );
    _useGlobal = !location.hasCalculationOverride;

    // Etkin değerlerle başlat: override varsa onu, yoksa varsayılanı göster.
    // Global ayar yüklenince inherit durumunda yeniden tohumlanır.
    _method = location.method ?? CalculationDefaults.method;
    _school = AsrSchool.fromValue(
      location.school ?? CalculationDefaults.school,
    );
    _latitudeAdjustment = LatitudeAdjustment.fromValue(
      location.latitudeAdjustmentMethod,
    );

    _loadGlobalSettings();
  }

  /// Yardımcı metotların hepsi renk okuyor; tek kısayol.
  AppTokens get tokens => context.tokens;

  @override
  void dispose() {
    _customNameController.dispose();
    super.dispose();
  }

  Future<void> _loadGlobalSettings() async {
    final settings = await widget.locationRepository.getCalculationSettings();
    if (!mounted) return;
    setState(() {
      _globalSettings = settings;
      // Konum global ayarı miras alıyorsa, "özel" moda geçince kullanıcıya
      // mantıklı bir başlangıç sunmak için seçicileri global değerlere tohumla.
      if (_useGlobal) {
        _method = settings.method;
        _school = AsrSchool.fromValue(settings.school);
        _latitudeAdjustment = LatitudeAdjustment.fromValue(
          settings.latitudeAdjustmentMethod,
        );
      }
    });
  }

  Future<void> _save() async {
    final original = widget.location;
    final customName = _customNameController.text.trim();

    // Genel ayarı kullan → override yok (null); aksi halde seçilen değerler.
    final method = _useGlobal ? null : _method;
    final school = _useGlobal ? null : _school.value;
    final latitudeAdjustment = _useGlobal ? null : _latitudeAdjustment.value;

    final updated = Location(
      id: original.id,
      province: original.province,
      district: original.district,
      latitude: original.latitude,
      longitude: original.longitude,
      type: original.type,
      customName: customName.isEmpty ? null : customName,
      method: method,
      school: school,
      latitudeAdjustmentMethod: latitudeAdjustment,
    );

    final paramsChanged =
        method != original.method ||
        school != original.school ||
        latitudeAdjustment != original.latitudeAdjustmentMethod;

    try {
      if (paramsChanged) {
        await widget.locationRepository.clearPrayerTimeCache(original.id);
      }
      await widget.locationRepository.updateLocation(updated);
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Kaydedilemedi: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const SimpleAppBar(title: 'Konumu Düzenle'),
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
                    const SizedBox(height: 20),
                    _buildUseGlobalSwitch(),
                    const SizedBox(height: 12),
                    if (_useGlobal)
                      _buildGlobalSummary()
                    else
                      CalculationParamsSelector(
                        method: _method,
                        school: _school,
                        latitudeAdjustment: _latitudeAdjustment,
                        onMethodChanged: (value) => setState(() {
                          _method = value;
                          _school = AsrSchool.fromValue(
                            CalculationDefaults.schoolForMethod(value),
                          );
                        }),
                        onSchoolChanged: (value) =>
                            setState(() => _school = value),
                        onLatitudeAdjustmentChanged: (value) =>
                            setState(() => _latitudeAdjustment = value),
                      ),
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
          labelText: 'Özel İsim (Opsiyonel)',
          labelStyle: TextStyle(color: tokens.textTertiary),
          hintText: 'Örn: Ev, İş, Anne Evi',
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

  Widget _buildUseGlobalSwitch() {
    return GroupedList(
      children: [
        GroupedRow(
          icon: Icons.public_rounded,
          title: const Text('Genel hesaplama ayarını kullan'),
          subtitle: const Text(
            'Kapatırsan bu konuma özel yöntem/mezhep seçebilirsin',
          ),
          trailing: Switch(
            value: _useGlobal,
            onChanged: (value) => setState(() => _useGlobal = value),
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalSummary() {
    final methodName = CalculationMethods.byId(_globalSettings.method).name;
    final schoolLabel = AsrSchool.fromValue(_globalSettings.school).label;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.public_rounded, size: 18, color: tokens.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Genel ayar: $methodName · $schoolLabel',
              style: AppTypography.rowSubtitle.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ),
        ],
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
      child: const Text('Kaydet'),
    );
  }
}
