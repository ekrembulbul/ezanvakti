import 'package:flutter/material.dart';

class NotificationPermissionWarning extends StatelessWidget {
  final VoidCallback? onRequestPermission;
  final VoidCallback? onOpenAppSettings;

  const NotificationPermissionWarning({
    super.key,
    this.onRequestPermission,
    this.onOpenAppSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade900),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bildirim İzni Gerekli',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bildirim almak için uygulama izni vermelisiniz.',
            style: TextStyle(color: Colors.orange.shade900),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: onRequestPermission,
                icon: const Icon(Icons.notifications_active),
                label: const Text('İzin Ver'),
              ),
              const SizedBox(width: 8),
              if (onOpenAppSettings != null)
                TextButton(
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
