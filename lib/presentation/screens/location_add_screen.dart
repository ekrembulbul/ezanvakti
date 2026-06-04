import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' hide Location;
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/location.dart' as app_location;
import '../../core/providers/app_state.dart';
import '../../features/location/data/gps_label.dart';
import '../../features/location/data/photon_geocoding_service.dart';
import '../../features/location/data/place_suggestion.dart';
import '../../features/location/domain/location_repository.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/location/location_widgets.dart';

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
  static const Duration _searchDebounce = Duration(milliseconds: 300);
  static const int _minQueryLength = 2;

  // GPS konumu tek satır olarak saklanır; saveOrUpdateGpsLocation aynı kaydı
  // günceller, bu yüzden sabit bir kimlik yeterli.
  static const String _gpsLocationId = 'gps';

  final PhotonGeocodingService _geocodingService = PhotonGeocodingService();
  final _searchController = TextEditingController();
  final _customNameController = TextEditingController();

  bool _showManualSelection = false;
  bool _isLoadingLocation = false;
  String? _locationError;

  Timer? _searchTimer;
  List<PlaceSuggestion> _searchResults = [];
  bool _isSearching = false;
  bool _searchAttempted = false;

  app_location.Location? _selectedPlace;

  // Sonuçları kullanıcının yakınına önceleyen opsiyonel bias.
  double? _biasLatitude;
  double? _biasLongitude;

  @override
  void initState() {
    super.initState();
    _loadBiasLocation();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  Future<void> _loadBiasLocation() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null && mounted) {
        setState(() {
          _biasLatitude = position.latitude;
          _biasLongitude = position.longitude;
        });
      }
    } catch (_) {
      // Bias en iyi çaba; alınamazsa arama yine global çalışır.
    }
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    setState(() => _selectedPlace = null);

    final query = value.trim();
    if (query.length < _minQueryLength) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchAttempted = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _searchTimer = Timer(_searchDebounce, () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    final results = await _geocodingService.search(
      query,
      biasLatitude: _biasLatitude,
      biasLongitude: _biasLongitude,
    );
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
      _searchAttempted = true;
    });
  }

  void _onSuggestionSelected(PlaceSuggestion suggestion) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedPlace = suggestion.toLocation();
      _searchResults = [];
    });
  }

  void _clearSelection() {
    setState(() => _selectedPlace = null);
  }

  Future<void> _detectLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Konum servisleri kapalı. Lütfen açın.');
      }

      var permission = await Geolocator.checkPermission();
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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final label = await _reverseGeocodeLabel(
        position.latitude,
        position.longitude,
      );

      // Ham GPS koordinatı doğrudan kullanılır; il/ilçe yalnızca etikettir.
      final gpsLocation = app_location.Location(
        id: _gpsLocationId,
        province: label.province,
        district: label.district,
        latitude: position.latitude,
        longitude: position.longitude,
        type: app_location.LocationType.gps,
      );
      await _saveAndReturn(gpsLocation);
    } catch (e) {
      setState(
        () => _locationError = e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  /// GPS koordinatından okunur il/ilçe etiketi üretir. Adres bulunamazsa
  /// koordinata düşer; namaz vakti yine ham koordinattan hesaplanır.
  Future<({String province, String district})> _reverseGeocodeLabel(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        return resolveGpsLabel(placemarks.first);
      }
    } catch (_) {
      // Reverse geocode başarısızsa koordinat etiketine düşülür.
    }
    final coordsLabel =
        '${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)}';
    return (province: 'GPS Konumu', district: coordsLabel);
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

  Future<void> _saveAndReturn(app_location.Location location) async {
    try {
      // Seçilen hesaplama parametreleriyle taze veri çekilsin diye, bu kimliğe
      // ait eski (olası geçersiz) önbellek temizlenir. Silinip yeniden eklenen
      // bir yerin vakit kayıtları konumla birlikte silinmediğinden bu gerekli.
      await widget.locationRepository.clearPrayerTimeCache(location.id);

      if (location.type == app_location.LocationType.gps) {
        await widget.locationRepository.saveOrUpdateGpsLocation(location);
      } else {
        await widget.locationRepository.saveLocation(location);
      }
      await widget.locationRepository.setActiveLocation(location);
      if (mounted) {
        if (widget.fromLocationList) {
          Navigator.of(context).pop(location);
        } else {
          context.read<AppState>().setActiveLocation(location);
        }
      }
    } catch (e) {
      _showSnackBar('Hata: $e', isError: true);
    }
  }

  Future<void> _onManualSave() async {
    final place = _selectedPlace;
    if (place == null) {
      _showSnackBar('Lütfen bir konum seçin', isError: true);
      return;
    }

    final customName = _customNameController.text.trim();
    // Yeni konum global hesaplama ayarını miras alır (override yok); gerekirse
    // sonradan düzenleme ekranından konuma özel ayarlanabilir.
    final location = place.copyWith(
      type: app_location.LocationType.manual,
      customName: customName.isEmpty ? null : customName,
    );

    await _saveAndReturn(location);
  }

  void _resetManualSelection() {
    setState(() {
      _showManualSelection = false;
      _selectedPlace = null;
      _searchResults = [];
      _isSearching = false;
      _searchAttempted = false;
      _searchController.clear();
      _customNameController.clear();
    });
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
        title: _showManualSelection ? 'Konum Ara' : 'Yeni Konum',
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
          'GPS ile otomatik tespit edin veya\nadres arayarak konum seçin',
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
          icon: Icons.search_rounded,
          title: 'Adres Ara',
          subtitle: 'Şehir, ilçe veya yer adıyla ara',
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
        _buildSearchField(),
        const SizedBox(height: 16),
        Expanded(
          child: _selectedPlace == null
              ? _buildResults()
              : _buildConfigSection(),
        ),
        const SizedBox(height: 8),
        _buildAttribution(),
        const SizedBox(height: 12),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Şehir, ilçe veya yer ara...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          suffixIcon: _buildSearchSuffix(),
        ),
      ),
    );
  }

  Widget? _buildSearchSuffix() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.gold,
          ),
        ),
      );
    }
    if (_searchController.text.isNotEmpty) {
      return IconButton(
        icon: Icon(
          Icons.close_rounded,
          color: Colors.white.withValues(alpha: 0.5),
        ),
        onPressed: () {
          _searchController.clear();
          _onSearchChanged('');
        },
      );
    }
    return null;
  }

  Widget _buildResults() {
    if (_searchResults.isEmpty) {
      final message = _searchAttempted
          ? 'Sonuç bulunamadı.\nFarklı bir arama deneyin veya bağlantınızı kontrol edin.'
          : 'Aramak için yazmaya başlayın.';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) => _buildResultTile(_searchResults[index]),
    );
  }

  Widget _buildResultTile(PlaceSuggestion suggestion) {
    return GestureDetector(
      onTap: () => _onSuggestionSelected(suggestion),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              color: Colors.white.withValues(alpha: 0.5),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                suggestion.displayLabel,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigSection() {
    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        LocationSelectionConfirm(location: _selectedPlace!),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _clearSelection,
            icon: const Icon(Icons.search_rounded, size: 16),
            label: const Text('Değiştir'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.gold),
          ),
        ),
        const SizedBox(height: 8),
        _buildCustomNameField(),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 15,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hesaplama yöntemi genel ayardan alınır. Bu konuma özel '
                'değiştirmek için kaydettikten sonra düzenleyin.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomNameField() {
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

  Widget _buildAttribution() {
    return Text(
      '© OpenStreetMap katkıcıları',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.3),
        fontSize: 11,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _resetManualSelection,
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
            onPressed: _selectedPlace != null ? _onManualSave : null,
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
