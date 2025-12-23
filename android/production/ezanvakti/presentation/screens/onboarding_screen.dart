import 'package:flutter/material.dart';
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
            const SizedBox(height: 32),
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
