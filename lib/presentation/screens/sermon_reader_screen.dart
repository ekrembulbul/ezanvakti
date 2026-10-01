import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../core/utils/app_logger.dart';
import '../../features/sermons/domain/sermon.dart';
import '../../features/sermons/domain/sermon_repository.dart';
import '../../l10n/l10n_extensions.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/state_widgets.dart';
import '../widgets/sermons/sermon_presentation.dart';

/// Türkçe hutbe metni. Diyanet Haber'deki metin değiştirilmeden gösterilir;
/// altta dipnotlar, imza ve kaynak bağlantısı.
class SermonReaderScreen extends StatefulWidget {
  final SermonRepository repository;
  final SermonSummary summary;
  final Future<bool> Function(Uri) openUrl;

  /// Yazı boyutu kademeleri; varsayılan kademe 2 (17).
  static const List<double> fontSizes = [14, 16, 17, 20, 24];

  const SermonReaderScreen({
    super.key,
    required this.repository,
    required this.summary,
    required this.openUrl,
  });

  @override
  State<SermonReaderScreen> createState() => _SermonReaderScreenState();
}

class _SermonReaderScreenState extends State<SermonReaderScreen> {
  SermonText? _text;
  Object? _error;
  int _step = SermonRepository.defaultFontStep;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final step = await widget.repository.fontStep();
      final text = await widget.repository.text(widget.summary.id);
      if (mounted) {
        setState(() {
          _step = step;
          _text = text;
        });
      }
    } catch (e, s) {
      AppLogger().warning('Sermon text load failed', e, s);
      if (mounted) setState(() => _error = e);
    }
  }

  void _resize(int delta) {
    final next = (_step + delta).clamp(
      0,
      SermonReaderScreen.fontSizes.length - 1,
    );
    if (next == _step) return;
    setState(() => _step = next);
    widget.repository.setFontStep(next);
  }

  Future<void> _share() async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '${widget.summary.title}\n${widget.summary.sourceUrl}',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (e, s) {
      AppLogger().warning('Sermon share failed', e, s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(
        title: l10n.toolsSermons,
        actions: [
          AppBarActionButton(
            icon: Icons.text_decrease_rounded,
            tooltip: l10n.sermonTextSmaller,
            onTap: () => _resize(-1),
          ),
          AppBarActionButton(
            icon: Icons.text_increase_rounded,
            tooltip: l10n.sermonTextLarger,
            onTap: () => _resize(1),
          ),
          AppBarActionButton(
            icon: Icons.ios_share_rounded,
            tooltip: l10n.actionShare,
            onTap: _share,
          ),
        ],
      ),
      body: AppSurface(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final text = _text;
    if (text == null) {
      if (_error != null) {
        return ErrorState(
          message: context.l10n.sermonsLoadFailed,
          onRetry: _load,
        );
      }
      return const LoadingState();
    }
    final tokens = context.tokens;
    final size = SermonReaderScreen.fontSizes[_step];
    final body = AppTypography.hint.copyWith(
      fontSize: size,
      height: 1.5,
      color: tokens.textPrimary,
    );
    final small = AppTypography.hint.copyWith(
      color: tokens.textSecondary,
      height: 1.5,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Text(
          sermonDateLabel(context, widget.summary),
          style: AppTypography.hint.copyWith(color: tokens.textTertiary),
        ),
        const SizedBox(height: 8),
        if (text.heading.isNotEmpty) ...[
          Text(
            text.heading,
            style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
          ),
          const SizedBox(height: 16),
        ],
        for (final paragraph in text.paragraphs) ...[
          Text(paragraph, style: body),
          SizedBox(height: size * 0.75),
        ],
        if (text.footnotes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Divider(color: tokens.divider),
          const SizedBox(height: 8),
          Text(
            context.l10n.sermonFootnotes,
            style: AppTypography.rowTitle.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: 8),
          for (final note in text.footnotes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${note.n}. ${note.text}', style: small),
            ),
        ],
        if (text.signature.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            text.signature,
            textAlign: TextAlign.end,
            style: small.copyWith(color: tokens.textTertiary),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () =>
                openUrlOrNotify(context, text.sourceUrl, widget.openUrl),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(context.l10n.sermonSource),
          ),
        ),
      ],
    );
  }
}
