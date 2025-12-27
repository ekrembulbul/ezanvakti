import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' hide Location;
import '../../core/theme/app_theme.dart';
import '../../core/models/location.dart' as AppLocation;
import '../../features/location/data/turkey_locations_data.dart';
import '../../features/location/domain/location_repository.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/location/location_widgets.dart';
import '../../core/providers/app_state.dart';
import 'package:provider/provider.dart';

class LocationAddScreen extends StatefulWidget {
  final LocationRepository locationRepository;
  final bool fromLocationList;

  const LocationAddScreen({
    super.key,
    required this.locationRepository,
    this.fromLocationList = false,
  });

  @override
  State<LocationAddScreen> createState() => _LocationAddScreenState();
}

class _LocationAddScreenState extends State<LocationAddScreen> {
  bool _showManualSelection = false;
  String? selectedProvince;
  AppLocation.Location? selectedDistrict;
  List<String> provinces = [];
  List<AppLocation.Location> districts = [];
  bool _isLoadingLocation = false;
  String? _locationError;
  final _customNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    provinces = TurkeyLocationsData.getAllProvinces();
  }

  @override
  void dispose() {
    _customNameController.dispose();
    super.dispose();
  }

  void _onProvinceSelected(String? province) {
    if (province == null) return;
    setState(() {
      selectedProvince = province;
      selectedDistrict = null;
      districts = TurkeyLocationsData.getDistrictsByProvince(province);
    });
  }

  void _onDistrictSelected(AppLocation.Location? district) {
    if (district == null) return;
    setState(() => selectedDistrict = district);
  }

  Future<void> _detectLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Konum servisleri kapalı. Lütfen açın.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final shouldRequest = await _showLocationRationale();
        if (!shouldRequest) throw Exception('Konum izni gerekli.');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Konum izni reddedildi.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Konum izni kalıcı olarak reddedildi. Ayarlardan izin verin.',
        );
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) throw Exception('Konum bilgisi alınamadı.');

      final placemark = placemarks.first;
      final province = placemark.administrativeArea ?? '';
      final district =
          placemark.subAdministrativeArea ?? placemark.locality ?? '';

      if (province.isEmpty || district.isEmpty) {
        throw Exception('İl veya ilçe bilgisi bulunamadı.');
      }

      final matchedLocation = _findMatchingLocation(province, district);
      if (matchedLocation != null) {
        final gpsLocation = matchedLocation.copyWith(
          type: AppLocation.LocationType.gps,
          latitude: position.latitude,
          longitude: position.longitude,
        );
        await _saveAndReturn(gpsLocation);
      } else {
        throw Exception(
          '$province/$district için veri bulunamadı. Manuel seçim yapın.',
        );
      }
    } catch (e) {
      setState(
        () => _locationError = e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  AppLocation.Location? _findMatchingLocation(
    String province,
    String district,
  ) {
    final allProvinces = TurkeyLocationsData.getAllProvinces();

    String? matchedProvince;
    for (final p in allProvinces) {
      if (p.toLowerCase().contains(province.toLowerCase()) ||
          province.toLowerCase().contains(p.toLowerCase())) {
        matchedProvince = p;
        break;
      }
    }

    if (matchedProvince == null) return null;

    final districts = TurkeyLocationsData.getDistrictsByProvince(
      matchedProvince,
    );
    for (final d in districts) {
      if (d.district.toLowerCase().contains(district.toLowerCase()) ||
          district.toLowerCase().contains(d.district.toLowerCase())) {
        return d;
      }
    }

    return districts.isNotEmpty ? districts.first : null;
  }

  Future<bool> _showLocationRationale() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primaryMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konum İzni', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Namaz vakitlerini bulunduğunuz konuma göre gösterebilmek için konum iznine ihtiyaç var. '
          'İzni vererek bulunduğunuz il/ilçe otomatik seçilecektir.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.primaryDark,
            ),
            child: const Text('İzin Ver'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _saveAndReturn(AppLocation.Location location) async {
    try {
      if (location.type == AppLocation.LocationType.gps) {
        await widget.locationRepository.saveOrUpdateGpsLocation(location);
      } else {
        await widget.locationRepository.saveLocation(location);
      }
      await widget.locationRepository.setActiveLocation(location);
      if (mounted) {
        if (widget.fromLocationList) {
          // LocationListScreen'den çağrıldı - location'ı döndür
          Navigator.of(context).pop(location);
        } else {
          // İlk kurulum - AppState'i güncelle, AppRoot otomatik geçiş yapar
          context.read<AppState>().setActiveLocation(location);
        }
      }
    } catch (e) {
      _showSnackBar('Hata: $e', isError: true);
    }
  }

  Future<void> _onManualSave() async {
    if (selectedDistrict == null) {
      _showSnackBar('Lütfen il ve ilçe seçiniz', isError: true);
      return;
    }

    final customName = _customNameController.text.trim();
    final locationToSave = selectedDistrict!.copyWith(
      type: AppLocation.LocationType.manual,
      customName: customName.isEmpty ? null : customName,
    );

    await _saveAndReturn(locationToSave);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : AppTheme.gold,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(
        title: _showManualSelection ? 'Manuel Konum' : 'Yeni Konum',
        // İlk kurulumda geri yok, Ayarlar'dan gelince sadece ana seçim ekranında göster
        showBack: widget.fromLocationList && !_showManualSelection,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.nightGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _showManualSelection
                ? _buildManualSelection()
                : _buildChoiceScreen(),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceScreen() {
    return Column(
      children: [
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.gold.withValues(alpha: 0.2),
                AppTheme.gold.withValues(alpha: 0.05),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_location_alt_rounded,
            size: 64,
            color: AppTheme.gold,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Yeni Konum Ekle',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'GPS ile otomatik tespit edin veya\nmanuel olarak konum seçin',
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.6),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        LocationChoiceButton(
          icon: Icons.my_location_rounded,
          title: _isLoadingLocation ? 'Konum Alınıyor...' : 'GPS ile Bul',
          subtitle: 'Otomatik konum tespiti',
          isLoading: _isLoadingLocation,
          isHighlighted: true,
          onTap: _detectLocation,
        ),
        if (_locationError != null) ...[
          const SizedBox(height: 16),
          LocationErrorCard(error: _locationError!),
        ],
        const SizedBox(height: 16),
        LocationChoiceButton(
          icon: Icons.edit_location_alt_rounded,
          title: 'Manuel Seç',
          subtitle: 'İl ve ilçe seçerek ekle',
          onTap: () => setState(() {
            _showManualSelection = true;
            _locationError = null;
          }),
        ),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildManualSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          'İl ve ilçe seçerek yeni konum ekleyin',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 32),
        _buildTextField(),
        const SizedBox(height: 16),
        _buildProvinceDropdown(),
        const SizedBox(height: 16),
        _buildDistrictDropdown(),
        if (selectedDistrict != null) ...[
          const SizedBox(height: 24),
          LocationSelectionConfirm(location: selectedDistrict!),
        ],
        const Spacer(),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildTextField() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: _customNameController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Özel İsim (Opsiyonel)',
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          hintText: 'Örn: Ev, İş, Anne Evi',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
          prefixIcon: Icon(
            Icons.label_outline_rounded,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildProvinceDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedProvince,
          hint: Text(
            'İl Seçiniz',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
          isExpanded: true,
          dropdownColor: AppTheme.primaryMedium,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: provinces.map((province) {
            return DropdownMenuItem(value: province, child: Text(province));
          }).toList(),
          onChanged: _onProvinceSelected,
        ),
      ),
    );
  }

  Widget _buildDistrictDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLocation.Location>(
          value: selectedDistrict,
          hint: Text(
            'İlçe Seçiniz',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
          isExpanded: true,
          dropdownColor: AppTheme.primaryMedium,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: districts.map((district) {
            return DropdownMenuItem<AppLocation.Location>(
              value: district,
              child: Text(district.district),
            );
          }).toList(),
          onChanged: _onDistrictSelected,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _showManualSelection = false;
                selectedProvince = null;
                selectedDistrict = null;
                districts = [];
                _customNameController.clear();
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Geri'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: selectedDistrict != null ? _onManualSave : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.primaryDark,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Kaydet',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
