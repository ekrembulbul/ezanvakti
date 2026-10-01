import 'package:flutter/material.dart';

import '../../core/utils/app_logger.dart';
import '../../features/sermons/domain/sermon.dart';
import '../../features/sermons/domain/sermon_repository.dart';
import '../../l10n/l10n_extensions.dart';
import '../utils/directional_icons.dart';
import '../../core/theme/tokens_context.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/grouped_list.dart';
import '../widgets/common/state_widgets.dart';
import '../widgets/sermons/sermon_presentation.dart';

/// Son 20 hutbe. Türkçede okuma ekranına, diğer dillerde o dilin PDF'ine
/// gider; o dilde PDF'i olmayan hutbe listede görünmez.
class SermonListScreen extends StatefulWidget {
  final SermonRepository repository;
  final Future<bool> Function(Uri) openUrl;

  const SermonListScreen({
    super.key,
    required this.repository,
    required this.openUrl,
  });

  @override
  State<SermonListScreen> createState() => _SermonListScreenState();
}

class _SermonListScreenState extends State<SermonListScreen> {
  List<SermonSummary>? _sermons;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _error = null);
    try {
      final sermons = await widget.repository.index(force: force);
      if (mounted) setState(() => _sermons = sermons);
    } catch (e, s) {
      AppLogger().warning('Sermon list load failed', e, s);
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(title: context.l10n.sermonsTitle),
      body: AppSurface(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final sermons = _sermons;
    if (sermons == null) {
      if (_error != null) {
        return ErrorState(
          message: context.l10n.sermonsLoadFailed,
          onRetry: () => _load(force: true),
        );
      }
      return const LoadingState();
    }
    final lang = Localizations.localeOf(context).languageCode;
    final visible = [
      for (final s in sermons)
        if (sermonTitleFor(s, lang) != null) s,
    ];
    if (visible.isEmpty) {
      return EmptyState(
        icon: Icons.menu_book_rounded,
        message: context.l10n.sermonsEmpty,
      );
    }
    final tokens = context.tokens;
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          GroupedList(
            children: [
              for (final sermon in visible)
                GroupedRow(
                  icon: sermon.kind == SermonKind.bayram
                      ? Icons.celebration_rounded
                      : Icons.menu_book_rounded,
                  title: Text(sermonTitleFor(sermon, lang)!),
                  subtitle: Text(sermonDateLabel(context, sermon)),
                  growWithContent: true,
                  onTap: () => openSermon(
                    context,
                    sermon: sermon,
                    repository: widget.repository,
                    openUrl: widget.openUrl,
                  ),
                  trailing: Icon(
                    lang == 'tr'
                        ? context.forwardChevron
                        : Icons.picture_as_pdf_outlined,
                    size: 20,
                    color: tokens.textTertiary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
