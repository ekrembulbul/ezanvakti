import 'package:flutter/material.dart';
import '../../../l10n/l10n_extensions.dart';

import '../common/info_banner.dart';

/// Bildirim izni verilmediğinde gösterilen uyarı.
///
/// Spec §4.1 gereği nötr: turuncu vurgu kaldırıldı, band yüzey/kenarlık
/// token'larını kullanan [InfoBanner] üzerinden geliyor.
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
    return Padding(
      key: const Key('permission_warning'),
      padding: const EdgeInsets.only(bottom: 16),
      child: InfoBanner(
        icon: Icons.notifications_off_rounded,
        text: context.l10n.notificationsNeedPermission,
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onOpenAppSettings != null)
              TextButton(
                key: const Key('open_settings_button'),
                onPressed: onOpenAppSettings,
                child: const Text('Ayarlar'),
              ),
            if (onRequestPermission != null)
              TextButton(
                key: const Key('request_permission_button'),
                onPressed: () async {
                  final granted = await onRequestPermission!.call();
                  onPermissionGranted(granted);
                },
                child: Text(context.l10n.permissionGrant),
              ),
          ],
        ),
      ),
    );
  }
}
