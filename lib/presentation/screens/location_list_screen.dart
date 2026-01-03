import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/location.dart';
import '../../features/location/domain/location_repository.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/state_widgets.dart';
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
      _showSnackBar('Konumlar yüklenemedi: $e', isError: true);
    }
  }

  Future<void> _addNewLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationAddScreen(
          locationRepository: widget.locationRepository,
          fromLocationList: true,
        ),
      ),
    );
    if (result is Location) {
      widget.onLocationSelected(result);
      Navigator.popUntil(context, (route) => route.isFirst);
    } else if (result == true) {
      _loadLocations();
    }
  }

  Future<void> _deleteLocation(Location location) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primaryMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konumu Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          '${location.displayName} konumunu silmek istediğinize emin misiniz?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.locationRepository.deleteLocation(location.id);
        _loadLocations();
        _showSnackBar('Konum silindi');
      } catch (e) {
        _showSnackBar('Hata: $e', isError: true);
      }
    }
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
      appBar: SimpleAppBar(title: 'Konumlar'),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.nightGradient),
        child: SafeArea(child: _buildBody()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewLocation,
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.primaryDark,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text(
          'Yeni Konum',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingState(message: 'Konumlar yükleniyor...');
    }

    if (_locations.isEmpty) {
      return EmptyState(
        icon: Icons.location_off_rounded,
        message: 'Henüz konum eklenmedi',
        subtitle:
            'GPS ile otomatik tespit edin veya\nmanuel olarak konum ekleyin.',
        action: ElevatedButton.icon(
          onPressed: _addNewLocation,
          icon: const Icon(Icons.add_location_alt_rounded),
          label: const Text('Konum Ekle'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            foregroundColor: AppTheme.primaryDark,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _locations.length,
      itemBuilder: (context, index) {
        final location = _locations[index];
        final isActive = widget.currentLocation?.id == location.id;
        return _LocationTileWithDelete(
          location: location,
          isActive: isActive,
          onTap: () {
            widget.onLocationSelected(location);
            Navigator.popUntil(context, (route) => route.isFirst);
          },
          onDelete: () => _deleteLocation(location),
        );
      },
    );
  }
}

class _LocationTileWithDelete extends StatelessWidget {
  final Location location;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _LocationTileWithDelete({
    required this.location,
    required this.isActive,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isActive ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [
                    AppTheme.gold.withValues(alpha: 0.2),
                    AppTheme.gold.withValues(alpha: 0.05),
                  ],
                )
              : null,
          color: isActive ? null : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppTheme.gold.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.gold.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                location.type == LocationType.gps
                    ? Icons.my_location_rounded
                    : Icons.location_on_rounded,
                color: isActive ? AppTheme.gold : Colors.white70,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          location.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isActive ? AppTheme.gold : Colors.white,
                          ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.gold,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'AKTİF',
                            style: TextStyle(
                              color: AppTheme.primaryDark,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${location.province} / ${location.district}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isActive
                          ? AppTheme.gold.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.gold.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              location.type == LocationType.gps
                                  ? Icons.gps_fixed_rounded
                                  : Icons.edit_location_rounded,
                              size: 12,
                              color: isActive
                                  ? AppTheme.gold
                                  : Colors.white.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              location.type.displayName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isActive
                                    ? AppTheme.gold
                                    : Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (!isActive)
                        GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
