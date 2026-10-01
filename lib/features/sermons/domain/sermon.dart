import '../../../core/exceptions/parse_exception.dart';

/// Hutbe türü; sunucu sözleşmesindeki `kind`.
enum SermonKind { cuma, bayram }

/// Diyanet'in yabancı dildeki PDF'i (Din Hizmetleri sitesinde).
class SermonPdf {
  final String title;
  final Uri url;

  const SermonPdf({required this.title, required this.url});

  Map<String, dynamic> toJson() => {'title': title, 'url': url.toString()};
}

/// Hutbe listesindeki bir kayıt.
class SermonSummary {
  final String id;
  final DateTime date;
  final SermonKind kind;

  /// Türkçe konu başlığı ("Tebliğ Sorumluluğumuz").
  final String title;
  final Uri sourceUrl;

  /// Dil koduna göre PDF (`en`, `ar`); yoksa boş.
  final Map<String, SermonPdf> pdfs;

  /// Diyanet Haber'deki metnin son değişiklik zamanı (sunucunun verdiği gibi);
  /// saklanan metnin eskidiğini anlamak için.
  final String? modifiedAt;

  const SermonSummary({
    required this.id,
    required this.date,
    required this.kind,
    required this.title,
    required this.sourceUrl,
    this.pdfs = const {},
    this.modifiedAt,
  });

  factory SermonSummary.fromJson(Map<String, dynamic> json) {
    final pdfs = <String, SermonPdf>{};
    final rawPdfs = json['pdfs'];
    if (rawPdfs is Map) {
      rawPdfs.forEach((lang, value) {
        if (value is Map) {
          pdfs['$lang'] = SermonPdf(
            title: _string(value, 'title', 'SermonPdf'),
            url: _uri(value, 'url', 'SermonPdf'),
          );
        }
      });
    }
    return SermonSummary(
      id: _string(json, 'id', 'SermonSummary'),
      date: _date(json, 'SermonSummary'),
      kind: _kind(json, 'SermonSummary'),
      title: _string(json, 'title', 'SermonSummary'),
      sourceUrl: _uri(json, 'sourceUrl', 'SermonSummary'),
      pdfs: pdfs,
      modifiedAt: _optional(json, 'modifiedAt'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': _formatDate(date),
    'kind': kind.name,
    'title': title,
    'sourceUrl': sourceUrl.toString(),
    'pdfs': {for (final e in pdfs.entries) e.key: e.value.toJson()},
    'modifiedAt': modifiedAt,
  };
}

class SermonFootnote {
  final int n;
  final String text;

  const SermonFootnote({required this.n, required this.text});
}

/// Türkçe hutbe metni; Diyanet Haber'deki metin değiştirilmeden, paragraf ve
/// dipnot olarak ayrılmış hâliyle.
class SermonText {
  final String id;
  final DateTime date;
  final SermonKind kind;
  final String title;
  final String heading;
  final List<String> paragraphs;
  final List<SermonFootnote> footnotes;
  final String signature;
  final Uri sourceUrl;
  final String? modifiedAt;

  const SermonText({
    required this.id,
    required this.date,
    required this.kind,
    required this.title,
    required this.heading,
    required this.paragraphs,
    required this.footnotes,
    required this.signature,
    required this.sourceUrl,
    this.modifiedAt,
  });

  factory SermonText.fromJson(Map<String, dynamic> json) {
    final paragraphs = json['paragraphs'];
    final footnotes = json['footnotes'];
    if (paragraphs is! List || paragraphs.isEmpty) {
      throw ParseException(
        message: 'sermon paragraphs missing',
        context: 'SermonText.fromJson',
      );
    }
    return SermonText(
      id: _string(json, 'id', 'SermonText'),
      date: _date(json, 'SermonText'),
      kind: _kind(json, 'SermonText'),
      title: _string(json, 'title', 'SermonText'),
      heading: json['heading'] is String ? json['heading'] as String : '',
      paragraphs: [for (final p in paragraphs) '$p'],
      footnotes: [
        if (footnotes is List)
          for (final f in footnotes)
            if (f is Map && f['n'] is num && f['text'] is String)
              SermonFootnote(
                n: (f['n'] as num).toInt(),
                text: f['text'] as String,
              ),
      ],
      signature: json['signature'] is String ? json['signature'] as String : '',
      sourceUrl: _uri(json, 'sourceUrl', 'SermonText'),
      modifiedAt: _optional(json, 'modifiedAt'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': _formatDate(date),
    'kind': kind.name,
    'title': title,
    'heading': heading,
    'paragraphs': paragraphs,
    'footnotes': [
      for (final f in footnotes) {'n': f.n, 'text': f.text},
    ],
    'signature': signature,
    'sourceUrl': sourceUrl.toString(),
    'modifiedAt': modifiedAt,
  };
}

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String? _optional(Map json, String key) {
  final value = json[key];
  return value is String && value.isNotEmpty ? value : null;
}

String _string(Map json, String key, String ctx) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw ParseException(message: '$ctx.$key missing', context: '$ctx.fromJson');
}

Uri _uri(Map json, String key, String ctx) {
  final uri = Uri.tryParse(_string(json, key, ctx));
  if (uri == null || !uri.hasScheme) {
    throw ParseException(
      message: '$ctx.$key invalid',
      context: '$ctx.fromJson',
    );
  }
  return uri;
}

DateTime _date(Map json, String ctx) {
  final parsed = DateTime.tryParse(_string(json, 'date', ctx));
  if (parsed == null) {
    throw ParseException(
      message: '$ctx.date invalid',
      context: '$ctx.fromJson',
    );
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

SermonKind _kind(Map json, String ctx) {
  final kind = SermonKind.values.asNameMap()[json['kind']];
  if (kind == null) {
    throw ParseException(
      message: '$ctx.kind "${json['kind']}" unknown',
      context: '$ctx.fromJson',
    );
  }
  return kind;
}
