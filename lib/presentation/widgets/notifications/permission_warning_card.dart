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
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.2),
            Colors.orange.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_off_rounded,
                  color: Colors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bildirim İzni Verilmedi',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bildirim almak için izin vermeniz gerekmektedir.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onOpenAppSettings != null)
                TextButton(
                  key: const Key('open_settings_button'),
                  onPressed: onOpenAppSettings,
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text('Ayarlar'),
                ),
              const SizedBox(width: 8),
              if (onRequestPermission != null)
                ElevatedButton(
                  key: const Key('request_permission_button'),
                  onPressed: () async {
                    final granted = await onRequestPermission!.call();
                    onPermissionGranted(granted);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'İzin Ver',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
