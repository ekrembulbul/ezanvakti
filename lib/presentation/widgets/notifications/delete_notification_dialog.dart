import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/utils/prayer_utils.dart';

class DeleteNotificationDialog extends StatelessWidget {
  final NotificationSetting setting;

  const DeleteNotificationDialog({super.key, required this.setting});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.primaryMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.delete_rounded,
              color: Colors.red,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Bildirimi Sil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 15),
          children: [
            TextSpan(
              text: PrayerUtils.getPrayerName(setting.prayerType),
              style: const TextStyle(
                color: AppTheme.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
            const TextSpan(text: ' bildirimi silinsin mi?'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('İptal', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Sil',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  static Future<bool> show(
    BuildContext context,
    NotificationSetting setting,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteNotificationDialog(setting: setting),
    );
    return result ?? false;
  }
}
