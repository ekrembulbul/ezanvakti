import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/location.dart';
import '../../core/constants/app_constants.dart';
import '../widgets/settings/settings_cards.dart';
import '../widgets/common/app_bar_widgets.dart';

class SettingsScreen extends StatefulWidget {
  final Location currentLocation;
  final String dataSource;
  final VoidCallback? onChangeLocation;
  final VoidCallback? onCalculationSettings;
  final VoidCallback? onAbout;

  const SettingsScreen({
    super.key,
    required this.currentLocation,
    this.dataSource = 'Aladhan API',
    this.onChangeLocation,
    this.onCalculationSettings,
    this.onAbout,
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
      extendBodyBehindAppBar: true,
      appBar: const SimpleAppBar(title: 'Ayarlar'),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.nightGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              const SettingsSectionTitle(title: 'Genel'),
              SettingsGroup(
                children: [
                  SettingsRow(
                    icon: widget.currentLocation.type == LocationType.gps
                        ? Icons.my_location_rounded
                        : Icons.location_on_rounded,
                    title: 'Konum',
                    subtitle: widget.currentLocation.displayName,
                    onTap: widget.onChangeLocation,
                  ),
                  SettingsRow(
                    icon: Icons.tune_rounded,
                    title: 'Hesaplama',
                    subtitle: 'Yöntem ve İkindi mezhebi',
                    onTap: widget.onCalculationSettings,
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const SettingsSectionTitle(title: 'Bilgi'),
              SettingsGroup(
                children: [
                  SettingsRow(
                    icon: Icons.cloud_download_rounded,
                    title: 'Veri Kaynağı',
                    subtitle: widget.dataSource,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 56,
              height: 56,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          AppConstants.appTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _version.isEmpty ? 'Sürüm yükleniyor...' : 'Sürüm $_version',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Vakitler Aladhan API ile hesaplanır. Hesaplama yöntemi '
          'Ayarlar\'dan değiştirilebilir.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Vakitler cihazınızda saklanır, dışarı gönderilmez.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
