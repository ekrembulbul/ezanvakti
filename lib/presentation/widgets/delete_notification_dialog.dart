import 'package:flutter/material.dart';
import '../../core/models/notification_setting.dart';
import '../utils/prayer_name_helper.dart';

class DeleteNotificationDialog extends StatelessWidget {
  final NotificationSetting setting;

  const DeleteNotificationDialog({super.key, required this.setting});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bildirimi Sil'),
      content: Text(
        '${PrayerNameHelper.getName(setting.prayerType)} bildirimi silinsin mi?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Sil'),
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
