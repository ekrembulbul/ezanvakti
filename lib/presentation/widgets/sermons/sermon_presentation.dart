import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../features/sermons/domain/sermon.dart';
import '../../../features/sermons/domain/sermon_repository.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../screens/sermon_reader_screen.dart';

/// Arayüz dilindeki başlık: Türkçede hutbenin konusu, diğer dillerde o dildeki
/// PDF'in adı; o dilde PDF yoksa `null` (hutbe o dilde gösterilmez).
String? sermonTitleFor(SermonSummary sermon, String languageCode) =>
    languageCode == 'tr' ? sermon.title : sermon.pdfs[languageCode]?.title;

/// "25 Eylül 2026 · Cuma".
String sermonDateLabel(BuildContext context, SermonSummary sermon) {
  final date = DateFormat(
    'd MMMM y',
    Localizations.localeOf(context).toLanguageTag(),
  ).format(sermon.date);
  final kind = switch (sermon.kind) {
    SermonKind.cuma => context.l10n.sermonKindFriday,
    SermonKind.bayram => context.l10n.sermonKindEid,
  };
  return '$date · $kind';
}

/// Türkçede okuma ekranını, diğer dillerde o dilin PDF'ini açar.
Future<void> openSermon(
  BuildContext context, {
  required SermonSummary sermon,
  required SermonRepository repository,
  required Future<bool> Function(Uri) openUrl,
}) async {
  final lang = Localizations.localeOf(context).languageCode;
  if (lang == 'tr') {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SermonReaderScreen(
          repository: repository,
          summary: sermon,
          openUrl: openUrl,
        ),
      ),
    );
    return;
  }
  final pdf = sermon.pdfs[lang];
  if (pdf == null) return;
  await openUrlOrNotify(context, pdf.url, openUrl);
}

/// Bağlantıyı açar; açılamazsa kısa bir mesaj gösterir.
Future<void> openUrlOrNotify(
  BuildContext context,
  Uri url,
  Future<bool> Function(Uri) openUrl,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = context.l10n.sermonOpenFailed;
  var ok = false;
  try {
    ok = await openUrl(url);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(failed)));
  }
}
