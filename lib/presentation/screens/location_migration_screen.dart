import 'package:flutter/material.dart';

import '../../core/models/location.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../core/utils/app_logger.dart';
import '../../features/location/data/places_api.dart';
import '../../features/location/domain/location_migration_service.dart';
import '../../features/location/domain/location_repository.dart';
import '../../l10n/l10n_extensions.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/grouped_list.dart';
import '../widgets/location/place_search_panel.dart';

/// Eski (koordinat tabanlı) kayıtlardan otomatik eşlenemeyenler için tek
/// seferlik doğrulama.
///
/// Belirsiz kayıtta sunucu önerileri listelenir; desteklenmeyen (Türkiye
/// dışı) kayıt silinir ya da başka ilçeyle değiştirilir. Aktif konum
/// silinemez (liste ekranındaki kuralla aynı): seçilir ya da değiştirilir.
/// Tüm öğeler çözülünce [onFinished] çağrılır.
class LocationMigrationScreen extends StatefulWidget {
  final MigrationReport report;
  final LocationRepository locationRepository;
  final PlacesApi placesApi;
  final Future<void> Function() onFinished;

  const LocationMigrationScreen({
    super.key,
    required this.report,
    required this.locationRepository,
    required this.placesApi,
    required this.onFinished,
  });

  @override
  State<LocationMigrationScreen> createState() =>
      _LocationMigrationScreenState();
}

class _LocationMigrationScreenState extends State<LocationMigrationScreen> {
  late final List<MigrationItem> _pending = [
    for (final item in widget.report.items)
      if (item.decision != MigrationDecision.mapped) item,
  ];

  /// Arama paneli açık olan öğe.
  MigrationItem? _picking;
  String? _activeId;
  bool _busy = false;

  AppTokens get tokens => context.tokens;

  @override
  void initState() {
    super.initState();
    _loadActive();
  }

  Future<void> _loadActive() async {
    final active = await widget.locationRepository.getActiveLocation();
    if (mounted) setState(() => _activeId = active?.id);
  }

  Future<void> _resolve(MigrationItem item, PlaceMatch match) async {
    if (_busy) return;
    setState(() => _busy = true);
    final old = item.location;
    // Eşlenen kayıt manuel sayılır: GPS kaydı çözülemediyse (Türkiye dışı)
    // cihaz koordinatı anlamsız, ilçe merkezi kullanılır.
    final replacement = match
        .toLocation(type: LocationType.manual)
        .copyWith(customName: old.customName);
    try {
      final repo = widget.locationRepository;
      if (replacement.id == old.id) {
        await repo.updateLocation(replacement);
      } else {
        await repo.deleteLocation(old.id);
        await repo.saveLocation(replacement);
      }
      await repo.clearPrayerTimeCache(replacement.id);
      if (_activeId == old.id) {
        await repo.setActiveLocation(replacement);
        _activeId = replacement.id;
      }
      _complete(item);
    } catch (e) {
      AppLogger().error('Location migration choice failed', e);
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(MigrationItem item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.locationRepository.deleteLocation(item.location.id);
      _complete(item);
    } catch (e) {
      AppLogger().error('Location migration delete failed', e);
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _complete(MigrationItem item) {
    if (!mounted) return;
    setState(() {
      _pending.remove(item);
      _picking = null;
    });
    if (_pending.isEmpty) widget.onFinished();
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.locationSaveFailed('$error')),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final picking = _picking;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(title: context.l10n.migrationTitle, showBack: false),
      body: AppSurface(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: picking != null ? _buildPicker(picking) : _buildList(),
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        Text(
          context.l10n.migrationIntro,
          style: AppTypography.rowSubtitle.copyWith(
            color: tokens.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        for (final item in _pending) ...[
          _card(item),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildPicker(MigrationItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.location.displayName,
          style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: PlaceSearchPanel(
            api: widget.placesApi,
            onSelected: (match) => _resolve(item, match),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => setState(() => _picking = null),
          style: OutlinedButton.styleFrom(
            foregroundColor: tokens.textSecondary,
            side: BorderSide(color: tokens.border),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(context.l10n.actionBack),
        ),
      ],
    );
  }

  Widget _card(MigrationItem item) {
    final isActive = item.location.id == _activeId;
    final ambiguous = item.decision == MigrationDecision.ambiguous;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedList(
          children: [
            GroupedRow(
              icon: item.location.type == LocationType.gps
                  ? Icons.my_location_rounded
                  : Icons.location_on_rounded,
              title: Text(item.location.displayName),
              subtitle: Text(
                ambiguous
                    ? context.l10n.migrationAmbiguousHint
                    : context.l10n.migrationUnsupported,
              ),
            ),
            for (final suggestion in item.suggestions)
              GroupedRow(
                icon: Icons.subdirectory_arrow_right_rounded,
                title: Text(suggestion.displayName),
                subtitle: suggestion.matchedAlias == null
                    ? null
                    : Text(
                        context.l10n.placeAliasIncluded(
                          suggestion.matchedAlias!,
                        ),
                      ),
                trailing: Text(
                  context.l10n.actionSelect,
                  style: AppTypography.rowSubtitle.copyWith(
                    color: tokens.accent,
                  ),
                ),
                onTap: _busy ? null : () => _resolve(item, suggestion),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            TextButton.icon(
              onPressed: _busy ? null : () => setState(() => _picking = item),
              icon: const Icon(Icons.search_rounded, size: 16),
              label: Text(context.l10n.migrationSearchOther),
              style: TextButton.styleFrom(foregroundColor: tokens.accent),
            ),
            const Spacer(),
            if (isActive)
              Flexible(
                child: Text(
                  context.l10n.migrationActiveCannotDelete,
                  textAlign: TextAlign.end,
                  style: AppTypography.hint.copyWith(
                    color: tokens.textTertiary,
                  ),
                ),
              )
            else
              TextButton(
                onPressed: _busy ? null : () => _delete(item),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(context.l10n.actionDelete),
              ),
          ],
        ),
      ],
    );
  }
}
