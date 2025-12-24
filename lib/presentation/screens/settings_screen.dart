import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/models/location.dart';

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
  String _version = 'Yükleniyor...';

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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        children: [
          _buildSection(
            title: 'Konum',
            children: [
              ListTile(
                key: const Key('location_tile'),
                leading: const Icon(Icons.location_on),
                title: const Text('Lokasyon'),
                subtitle: Text(
                  '${widget.currentLocation.province} / ${widget.currentLocation.district}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.onChangeLocation,
              ),
            ],
          ),
          _buildSection(
            title: 'Veri Kaynağı',
            children: [
              ListTile(
                key: const Key('data_source_tile'),
                leading: const Icon(Icons.source),
                title: const Text('Kaynak'),
                subtitle: Text(widget.dataSource),
                enabled: false,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Türkiye için Diyanet İşleri Başkanlığı verileri kullanılmaktadır.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          _buildSection(
            title: 'Uygulama',
            children: [
              ListTile(
                key: const Key('version_tile'),
                leading: const Icon(Icons.info_outline),
                title: const Text('Versiyon'),
                subtitle: Text(_version),
              ),
              if (widget.onAbout != null)
                ListTile(
                  key: const Key('about_tile'),
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Hakkında'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: widget.onAbout,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(children: children),
        ),
      ],
    );
  }
}
