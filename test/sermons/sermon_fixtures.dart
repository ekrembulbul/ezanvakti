/// Sunucu sözleşmesine (plan "JSON sözleşmesi") uygun örnekler.
Map<String, Object?> summaryJson({
  String id = '2026-09-25-cuma',
  String date = '2026-09-25',
  String kind = 'cuma',
  String title = 'Tebliğ Sorumluluğumuz',
  Map<String, Object?>? pdfs,
}) => {
  'id': id,
  'date': date,
  'kind': kind,
  'title': title,
  'sourceUrl': 'https://www.diyanethaber.com.tr/25-eylul-2026-cuma-hutbesi',
  'modifiedAt': '2026-09-25T11:28:09+03:00',
  'pdfs':
      pdfs ??
      {
        'en': {
          'title': 'Our Responsibility to Convey Islam',
          'url':
              'https://dinhizmetleri.diyanet.gov.tr/Documents/Our%20Responsibility%20to%20Convey%20Islam.pdf',
        },
        'ar': {
          'title': 'مَسْؤُولِيَّتُنَا فِي التَّبْلِيغِ',
          'url': 'https://dinhizmetleri.diyanet.gov.tr/Documents/ar.pdf',
        },
      },
};

Map<String, Object?> indexJson(List<Map<String, Object?>> sermons) => {
  'schemaVersion': 1,
  'updatedAt': '2026-10-01T19:00:04Z',
  'sermons': sermons,
};

Map<String, Object?> textJson({String id = '2026-09-25-cuma'}) => {
  'id': id,
  'date': '2026-09-25',
  'kind': 'cuma',
  'title': 'Tebliğ Sorumluluğumuz',
  'heading': 'TEBLİĞ SORUMLULUĞUMUZ',
  'paragraphs': ['Muhterem Müslümanlar!', 'Medineliler Allah Resûlü…[1]'],
  'footnotes': [
    {'n': 1, 'text': 'İbn Sa’d, Tabakât, I, 219, 220.'},
  ],
  'signature': 'Din Hizmetleri Genel Müdürlüğü',
  'sourceUrl': 'https://www.diyanethaber.com.tr/25-eylul-2026-cuma-hutbesi',
  'modifiedAt': '2026-09-25T11:28:09+03:00',
};
