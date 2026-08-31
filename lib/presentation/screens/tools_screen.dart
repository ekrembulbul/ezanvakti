import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_state.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/grouped_list.dart';
import '../widgets/common/section_label.dart';
import 'dhikr_screen.dart';
import 'prayer_tracking_screen.dart';
import 'qibla_screen.dart';

/// Araçlar sekmesi: kıble, namaz takibi ve zikirmatik.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      // Sekme olarak barindiriliyor; geri oku yok.
      appBar: const SimpleAppBar(title: 'Araçlar', showBack: false),
      body: AppSurface(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const SectionLabel('Yön'),
            const SizedBox(height: 10),
            GroupedList(
              children: [
                _row(
                  context,
                  icon: Icons.explore_rounded,
                  title: 'Kıble',
                  subtitle: 'Kâbe yönünü pusulayla bul',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QiblaScreen(
                        location: context.read<AppState>().activeLocation,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            const SectionLabel('Takip'),
            const SizedBox(height: 10),
            GroupedList(
              children: [
                _row(
                  context,
                  icon: Icons.checklist_rounded,
                  title: 'Namaz takibi',
                  subtitle: 'Kıldıklarını işaretle, kazanı say',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PrayerTrackingScreen(),
                    ),
                  ),
                ),
                _row(
                  context,
                  icon: Icons.circle_outlined,
                  title: 'Zikirmatik',
                  subtitle: 'Hedefli sayaç',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DhikrScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Araçlar cihazında çalışır; hiçbir veri dışarı gönderilmez.',
              textAlign: TextAlign.center,
              style: AppTypography.hint.copyWith(
                color: tokens.textTertiary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    final tokens = context.tokens;

    return GroupedRow(
      icon: icon,
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
      dimmed: onTap == null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: tokens.textTertiary,
      ),
    );
  }
}
