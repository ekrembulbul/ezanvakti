import 'package:flutter/material.dart';
import '../../core/models/location.dart';
import '../../features/location/domain/location_repository.dart';
import 'location_add_screen.dart';

class LocationListScreen extends StatefulWidget {
  final LocationRepository locationRepository;
  final Location? currentLocation;
  final Function(Location) onLocationSelected;

  const LocationListScreen({
    super.key,
    required this.locationRepository,
    required this.currentLocation,
    required this.onLocationSelected,
  });

  @override
  State<LocationListScreen> createState() => _LocationListScreenState();
}

class _LocationListScreenState extends State<LocationListScreen> {
  List<Location> _locations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoading = true);
    try {
      final locations = await widget.locationRepository.getSavedLocations();
      setState(() {
        _locations = locations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Konumlar yüklenemedi: $e')));
      }
    }
  }

  Future<void> _addNewLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LocationAddScreen(locationRepository: widget.locationRepository),
      ),
    );
    if (result == true) {
      _loadLocations();
    }
  }

  Future<void> _deleteLocation(Location location) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konumu Sil'),
        content: Text(
          '${location.displayName} konumunu silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.locationRepository.deleteLocation(location.id);
        _loadLocations();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Konum silindi')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konumlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewLocation,
            tooltip: 'Yeni Konum Ekle',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _locations.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              itemCount: _locations.length,
              itemBuilder: (context, index) {
                final location = _locations[index];
                final isActive = widget.currentLocation?.id == location.id;
                return _buildLocationTile(location, isActive);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewLocation,
        icon: const Icon(Icons.add_location),
        label: const Text('Yeni Konum'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Henüz konum eklenmedi',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni konum eklemek için + butonuna basın',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTile(Location location, bool isActive) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.teal : Colors.grey.shade300,
          child: Icon(
            location.type == LocationType.gps
                ? Icons.my_location
                : Icons.location_on,
            color: isActive ? Colors.white : Colors.grey.shade600,
          ),
        ),
        title: Text(
          location.displayName,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${location.province} / ${location.district}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  location.type == LocationType.gps
                      ? Icons.gps_fixed
                      : Icons.edit_location,
                  size: 14,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  location.type.displayName,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        trailing: isActive
            ? const Chip(
                label: Text('Aktif', style: TextStyle(fontSize: 12)),
                backgroundColor: Colors.teal,
                labelStyle: TextStyle(color: Colors.white),
              )
            : IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteLocation(location),
              ),
        onTap: isActive
            ? null
            : () {
                widget.onLocationSelected(location);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
      ),
    );
  }
}
