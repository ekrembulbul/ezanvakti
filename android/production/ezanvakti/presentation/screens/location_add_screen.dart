import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' hide Location;
import '../../core/models/location.dart' as AppLocation;
import '../../features/location/data/turkey_locations_data.dart';
import '../../features/location/domain/location_repository.dart';

class LocationAddScreen extends StatefulWidget {
  final LocationRepository locationRepository;

  const LocationAddScreen({super.key, required this.locationRepository});

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

    setState(() {
      selectedDistrict = district;
    });
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
        if (!shouldRequest) {
          throw Exception('Konum izni gerekli.');
        }
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

      if (placemarks.isEmpty) {
        throw Exception('Konum bilgisi alınamadı.');
      }

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
      setState(() {
        _locationError = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
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
      builder: (context) {
        return AlertDialog(
          title: const Text('Konum İzni'),
          content: const Text(
            'Namaz vakitlerini bulunduğunuz konuma göre gösterebilmek için konum iznine ihtiyaç var. '
            'İzni vererek bulunduğunuz il/ilçe otomatik seçilecektir.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('İzin Ver'),
            ),
          ],
        );
      },
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
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _onManualSave() async {
    if (selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen il ve ilçe seçiniz')),
      );
      return;
    }

    final customName = _customNameController.text.trim();
    final locationToSave = selectedDistrict!.copyWith(
      type: AppLocation.LocationType.manual,
      customName: customName.isEmpty ? null : customName,
    );

    await _saveAndReturn(locationToSave);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Konum Ekle')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _showManualSelection
            ? _buildManualSelection()
            : _buildChoiceScreen(),
      ),
    );
  }

  Widget _buildChoiceScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Icon(Icons.add_location, size: 80, color: Colors.teal),
        const SizedBox(height: 24),
        const Text(
          'Yeni Konum Ekle',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'GPS ile otomatik bul veya manuel seç',
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        ElevatedButton.icon(
          onPressed: _isLoadingLocation ? null : _detectLocation,
          icon: _isLoadingLocation
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.my_location),
          label: Text(_isLoadingLocation ? 'Konum Alınıyor...' : 'GPS ile Bul'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        if (_locationError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _locationError!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _showManualSelection = true;
              _locationError = null;
            });
          },
          icon: const Icon(Icons.edit_location_alt),
          label: const Text('Manuel Seç'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildManualSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Manuel Konum Ekle',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'İl ve ilçe seçerek yeni konum ekleyin.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _customNameController,
          decoration: const InputDecoration(
            labelText: 'Özel İsim (Opsiyonel)',
            hintText: 'Örn: Ev, İş, Anne Evi',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.label_outline),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedProvince,
          decoration: const InputDecoration(
            labelText: 'İl',
            border: OutlineInputBorder(),
          ),
          items: provinces
              .map(
                (province) =>
                    DropdownMenuItem(value: province, child: Text(province)),
              )
              .toList(),
          onChanged: _onProvinceSelected,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<AppLocation.Location>(
          value: selectedDistrict,
          decoration: const InputDecoration(
            labelText: 'İlçe',
            border: OutlineInputBorder(),
          ),
          items: districts
              .map(
                (district) => DropdownMenuItem<AppLocation.Location>(
                  value: district,
                  child: Text(district.district),
                ),
              )
              .toList(),
          onChanged: _onDistrictSelected,
        ),
        const Spacer(),
        Row(
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
                child: const Text('Geri'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _onManualSave,
                child: const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
