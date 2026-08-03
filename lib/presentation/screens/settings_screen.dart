import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/location.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/grouped_list.dart';
import '../widgets/common/section_label.dart';
import '../widgets/settings/appearance_section.dart';

class SettingsScreen extends StatefulWidget {
  final Location currentLocation;
  final String dataSource;
  final VoidCallback? onChangeLocation;
  final VoidCallback? onCalculationSettings;

  /// Verilmezse ekran kendi özet diyaloğunu gösterir.
  final VoidCallback? onPrivacy;

  const SettingsScreen({
    super.key,
    required this.currentLocation,
    this.dataSource = 'Aladhan API',
    this.onChangeLocation,
    this.onCalculationSettings,
    this.onPrivacy,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = packageInfo.version);
    } catch (_) {
      if (mounted) setState(() => _version = 'Bilinmiyor');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const SimpleAppBar(title: 'Ayarlar'),
      body: AppSurface(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            const SectionLabel('Genel'),
            const SizedBox(height: 10),
            GroupedList(
              children: [
                _row(
                  icon: widget.currentLocation.type == LocationType.gps
                      ? Icons.my_location_rounded
                      : Icons.location_on_rounded,
                  title: 'Konum',
                  value: widget.currentLocation.displayName,
                  onTap: widget.onChangeLocation,
                ),
                _row(
                  icon: Icons.tune_rounded,
                  title: 'Hesaplama',
                  onTap: widget.onCalculationSettings,
                ),
              ],
            ),
            const SizedBox(height: 26),
            const SectionLabel('Görünüm'),
            const SizedBox(height: 10),
            const AppearanceSection(),
            const SizedBox(height: 26),
            const SectionLabel('Bilgi'),
            const SizedBox(height: 10),
            GroupedList(
              children: [
                _row(
                  icon: Icons.cloud_download_rounded,
                  title: 'Veri kaynağı',
                  value: widget.dataSource,
                ),
                _row(
                  icon: Icons.lock_rounded,
                  title: 'Gizlilik',
                  onTap: widget.onPrivacy ?? _showPrivacy,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  /// Ayar satırı: sağda değer metni, dokunulabilirse ok.
  Widget _row({
    required IconData icon,
    required String title,
    String? value,
    VoidCallback? onTap,
  }) {
    final tokens = context.tokens;

    return GroupedRow(
      icon: icon,
      title: Text(title),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.rowSubtitle.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: tokens.textTertiary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final tokens = context.tokens;

    return Column(
      children: [
        Text(
          AppConstants.appTitle,
          textAlign: TextAlign.center,
          style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          _version.isEmpty ? 'Sürüm yükleniyor...' : 'Sürüm $_version',
          style: AppTypography.rowSubtitle.copyWith(color: tokens.textTertiary),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final tokens = context.tokens;

    return Text(
      'Vakitler cihazınızda saklanır, dışarı gönderilmez.',
      textAlign: TextAlign.center,
      style: AppTypography.hint.copyWith(
        color: tokens.textTertiary,
        height: 1.5,
      ),
    );
  }

  /// Gizlilik özeti. Tam metin `docs/privacy.html`'de; uygulamaya gömmek ayrı
  /// bir iş olduğu için burada özet gösteriliyor.
  void _showPrivacy() {
    final tokens = context.tokens;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.backgroundStops[1],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Gizlilik',
          style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
        ),
        content: Text(
          'Konumunuz yalnızca namaz vakitlerini hesaplamak için kullanılır ve '
          'cihazınızda saklanır. Vakit verisi Aladhan API üzerinden koordinatla '
          'sorgulanır; kişisel bilgi gönderilmez.',
          style: AppTypography.rowSubtitle.copyWith(
            color: tokens.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}
