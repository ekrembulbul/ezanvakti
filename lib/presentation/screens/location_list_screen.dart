import 'package:flutter/material.dart';
import '../../l10n/l10n_extensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../core/models/location.dart';
import '../../features/location/domain/location_repository.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/grouped_list.dart';
import '../widgets/common/section_label.dart';
import '../widgets/common/state_widgets.dart';
import '../widgets/common/swipe_to_delete.dart';
import 'location_add_screen.dart';
import 'location_edit_screen.dart';

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
    final l10n = context.l10n;
    setState(() => _isLoading = true);
    try {
      final locations = await widget.locationRepository.getSavedLocations();
      setState(() {
        _locations = locations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(l10n.locationsLoadFailed(e), isError: true);
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
    if (!mounted) return;
    if (result is Location) {
      widget.onLocationSelected(result);
      Navigator.popUntil(context, (route) => route.isFirst);
    } else if (result == true) {
      _loadLocations();
    }
  }

  Future<void> _editLocation(Location location) async {
    final updated = await Navigator.push<Location>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationEditScreen(
          locationRepository: widget.locationRepository,
          location: location,
        ),
      ),
    );
    if (!mounted || updated == null) return;

    if (widget.currentLocation?.id == updated.id) {
      // Aktif konumun parametreleri değişti: yeniden yükle + bildirimleri planla.
      widget.onLocationSelected(updated);
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      _loadLocations();
      _showSnackBar(context.l10n.locationUpdated);
    }
  }

  /// Onay sorulmadan siler; geri alma "Geri al" ile verilir.
  Future<void> _deleteLocation(Location location) async {
    final l10n = context.l10n;
    try {
      await widget.locationRepository.deleteLocation(location.id);
      _loadLocations();
      _showSnackBar(
        l10n.locationDeleted(location.displayName),
        action: SnackBarAction(
          label: l10n.snackUndo,
          textColor: Colors.white,
          onPressed: () => _restoreLocation(location),
        ),
      );
    } catch (e) {
      _showSnackBar(l10n.errorGenericWith(e), isError: true);
    }
  }

  /// Silinen konumu **aynı id ile** geri yazar; kayıtlı vakitler ve alarm
  /// eşleşmeleri bozulmasın.
  Future<void> _restoreLocation(Location location) async {
    final l10n = context.l10n;
    try {
      await widget.locationRepository.saveLocation(location);
      _loadLocations();
    } catch (e) {
      _showSnackBar(l10n.locationUndoFailed(e), isError: true);
    }
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
    SnackBarAction? action,
  }) {
    if (mounted) {
      // Onceki snackbar'i hemen kaldir; yeni islem mesaji beklemeden gosterilsin.
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          action: action,
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : context.tokens.accent,
          // Eylemli snackbar Flutter'da varsayilan olarak **kalici**
          // (`persist = action != null`): kullanici eyleme dokunmazsa hic
          // kapanmiyordu.
          persist: false,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          actionOverflowThreshold: 0.5,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(
        title: context.l10n.locationsTitle,
        actions: [
          AppBarActionButton(
            icon: Icons.add_location_alt_rounded,
            onTap: _addNewLocation,
            tooltip: context.l10n.locationAdd,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppSurface(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return LoadingState(message: context.l10n.locationsLoading);
    }

    if (_locations.isEmpty) {
      return EmptyState(
        icon: Icons.location_off_rounded,
        message: context.l10n.locationsEmpty,
        subtitle: context.l10n.locationsEmptyHint,
        action: ElevatedButton.icon(
          onPressed: _addNewLocation,
          icon: const Icon(Icons.add_location_alt_rounded),
          label: Text(context.l10n.locationAdd),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        SectionLabel(context.l10n.locationsCount(_locations.length)),
        const SizedBox(height: 10),
        GroupedList(
          children: [for (final location in _locations) _tile(location)],
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.locationsSwipeHint,
          style: AppTypography.hint.copyWith(
            color: context.tokens.textTertiary,
          ),
        ),
      ],
    );
  }

  /// Aktif konum silinemez: [SwipeToDelete] ile sarılmaz, sağında AKTİF rozeti
  /// durur. Diğerlerinde sağdaki ayar ikonu düzenlemeyi açar.
  Widget _tile(Location location) {
    final isActive = widget.currentLocation?.id == location.id;
    final row = GroupedRow(
      icon: location.type == LocationType.gps
          ? Icons.my_location_rounded
          : Icons.location_on_rounded,
      title: Text(location.displayName),
      subtitle: Text(context.l10n.locationTypeLabel(location.type)),
      onTap: isActive
          ? null
          : () {
              widget.onLocationSelected(location);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
      // Aktif konum da duzenlenebilmeli (hesaplama parametreleri); rozet
      // ayar ikonunun yerini almaz, yanina gelir.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) ...[_activeBadge(), const SizedBox(width: 8)],
          _editButton(location),
        ],
      ),
    );

    if (isActive) return row;

    return SwipeToDelete(
      itemKey: ValueKey(location.id),
      onDelete: () => _deleteLocation(location),
      child: row,
    );
  }

  Widget _activeBadge() {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.l10n.locationActive,
        style: AppTypography.sectionLabel.copyWith(
          color: tokens.backgroundStops.last,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _editButton(Location location) {
    final tokens = context.tokens;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _editLocation(location),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.tune_rounded, size: 18, color: tokens.accent),
      ),
    );
  }
}
