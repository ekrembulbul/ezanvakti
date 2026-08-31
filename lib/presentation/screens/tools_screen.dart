import 'package:flutter/material.dart';
import '../utils/directional_icons.dart';
import '../../l10n/l10n_extensions.dart';
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
      appBar: SimpleAppBar(title: context.l10n.toolsTitle, showBack: false),
      body: AppSurface(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            SectionLabel(context.l10n.toolsDirection),
            const SizedBox(height: 10),
            GroupedList(
              children: [
                _row(
                  context,
                  icon: Icons.explore_rounded,
                  title: context.l10n.toolsQibla,
                  subtitle: context.l10n.toolsQiblaHint,
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
            SectionLabel(context.l10n.toolsTracking),
            const SizedBox(height: 10),
            GroupedList(
              children: [
                _row(
                  context,
                  icon: Icons.checklist_rounded,
                  title: context.l10n.toolsPrayerTracking,
                  subtitle: context.l10n.toolsPrayerTrackingHint,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PrayerTrackingScreen(),
                    ),
                  ),
                ),
                _row(
                  context,
                  icon: Icons.circle_outlined,
                  title: context.l10n.toolsDhikr,
                  subtitle: context.l10n.toolsDhikrHint,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DhikrScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.toolsPrivacyNote,
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
        context.forwardChevron,
        size: 20,
        color: tokens.textTertiary,
      ),
    );
  }
}
