import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/location.dart';
import '../widgets/settings/settings_cards.dart';
import '../widgets/common/app_bar_widgets.dart';

class SettingsScreen extends StatefulWidget {
  final Location currentLocation;
  final String dataSource;
  final VoidCallback? onChangeLocation;
  final VoidCallback? onAbout;

  const SettingsScreen({
    super.key,
    required this.currentLocation,
    this.dataSource = 'Diyanet (Awqat Salah API)',
    this.onChangeLocation,
    this.onAbout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
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
        child: const SafeArea(top: true, bottom: true, child: _SettingsBody()),
      ),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_SettingsScreenState>();
    if (state == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionTitle(title: 'Konum'),
          const SizedBox(height: 12),
          LocationSettingsCard(
            location: state.widget.currentLocation,
            onTap: state.widget.onChangeLocation,
          ),
          const SizedBox(height: 28),
          const SettingsSectionTitle(title: 'Veri Kaynağı'),
          const SizedBox(height: 12),
          DataSourceCard(dataSource: state.widget.dataSource),
          const SizedBox(height: 28),
          const SettingsSectionTitle(title: 'Uygulama'),
          const SizedBox(height: 12),
          AppInfoCard(
            version: state._version.isEmpty
                ? ''
                : '${state._version} (${state._buildNumber})',
          ),
        ],
      ),
    );
  }
}
