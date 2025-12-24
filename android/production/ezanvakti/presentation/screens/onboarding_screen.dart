import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' hide Location;
import '../../core/models/location.dart';
import '../../features/location/data/turkey_locations_data.dart';

class OnboardingScreen extends StatefulWidget {
  final Function(Location) onLocationSelected;

  const OnboardingScreen({super.key, required this.onLocationSelected});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? selectedProvince;
  Location? selectedDistrict;
  List<String> provinces = [];
  List<Location> districts = [];
  bool _isLoadingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    provinces = TurkeyLocationsData.getAllProvinces();
  }

  void _onProvinceSelected(String? province) {
    if (province == null) return;

    setState(() {
      selectedProvince = province;
      selectedDistrict = null;
      districts = TurkeyLocationsData.getDistrictsByProvince(province);
    });
  }

  void _onDistrictSelected(Location? district) {
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
        throw Exception('Konum izni kalıcı olarak reddedildi. Ayarlardan izin verin.');
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
      final district = placemark.subAdministrativeArea ?? placemark.locality ?? '';

      if (province.isEmpty || district.isEmpty) {
        throw Exception('İl veya ilçe bilgisi bulunamadı.');
      }

      final matchedLocation = _findMatchingLocation(province, district);
      if (matchedLocation != null) {
        setState(() {
          selectedProvince = matchedLocation.province;
          selectedDistrict = matchedLocation;
          districts = TurkeyLocationsData.getDistrictsByProvince(matchedLocation.province);
        });
      } else {
        throw Exception('$province/$district için veri bulunamadı. Manuel seçim yapın.');
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

  Location? _findMatchingLocation(String province, String district) {
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

    final districts = TurkeyLocationsData.getDistrictsByProvince(matchedProvince);
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

  void _onContinue() {
    if (selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen il ve ilçe seçiniz')),
      );
      return;
    }

    widget.onLocationSelected(selectedDistrict!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hoş Geldiniz')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Lokasyon Seçimi',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Namaz vakitlerini görmek için lütfen şehir ve ilçe seçiniz.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const Key('detect_location_button'),
              onPressed: _isLoadingLocation ? null : _detectLocation,
              icon: _isLoadingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(_isLoadingLocation ? 'Konum alınıyor...' : 'Konumumu Bul'),
            ),
            if (_locationError != null) ...[
              const SizedBox(height: 8),
              Text(
                _locationError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('veya', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('province_dropdown'),
              value: selectedProvince,
              decoration: const InputDecoration(
                labelText: 'İl',
                border: OutlineInputBorder(),
              ),
              items: provinces
                  .map(
                    (province) => DropdownMenuItem(
                      value: province,
                      child: Text(province),
                    ),
                  )
                  .toList(),
              onChanged: _onProvinceSelected,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Location>(
              key: const Key('district_dropdown'),
              value: selectedDistrict,
              decoration: const InputDecoration(
                labelText: 'İlçe',
                border: OutlineInputBorder(),
              ),
              items: districts
                  .map(
                    (district) => DropdownMenuItem(
                      value: district,
                      child: Text(district.district),
                    ),
                  )
                  .toList(),
              onChanged: _onDistrictSelected,
            ),
            const Spacer(),
            ElevatedButton(
              key: const Key('continue_button'),
              onPressed: _onContinue,
              child: const Text('Devam Et'),
            ),
          ],
        ),
      ),
    );
  }
}
