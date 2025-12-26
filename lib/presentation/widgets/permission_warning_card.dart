import 'package:flutter/material.dart';

class PermissionWarningCard extends StatelessWidget {
  final Future<bool> Function()? onRequestPermission;
  final VoidCallback? onOpenAppSettings;
  final Function(bool) onPermissionGranted;

  const PermissionWarningCard({
    super.key,
    this.onRequestPermission,
    this.onOpenAppSettings,
    required this.onPermissionGranted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('permission_warning'),
      color: Colors.orange.shade100,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: const Text(
                  'Bildirim izni verilmedi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Bildirim almak için izin vermeniz gerekmektedir.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onRequestPermission != null)
                TextButton(
                  key: const Key('request_permission_button'),
                  onPressed: () async {
                    final granted = await onRequestPermission!.call();
                    onPermissionGranted(granted);
                  },
                  child: const Text('İzin Ver'),
                ),
              if (onOpenAppSettings != null)
                TextButton(
                  key: const Key('open_settings_button'),
                  onPressed: onOpenAppSettings,
                  child: const Text('Ayarlara Git'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
