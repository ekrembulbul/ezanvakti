# Tur 5 — Lokalizasyon: Türkçe, İngilizce, Arapça (0.10.0)

Tarih: 2026-08-31 · Baz: Tur 4 (`feat/tur4-araclar`, DB v12) · Platform: yalnızca iOS

## Amaç

Uygulamayı üç dilde kullanılabilir kılmak: **Türkçe** (kaynak dil), **İngilizce**, **Arapça** (RTL). Dil, cihaz ayarını izler ya da kullanıcı tarafından seçilir.

## Kapsam

### L1 — Altyapı
- `flutter_localizations` + `intl` ile `gen-l10n`; `l10n.yaml`, ARB dosyaları `lib/l10n/app_tr.arb` (kaynak), `app_en.arb`, `app_ar.arb`.
- `MaterialApp.localizationsDelegates` + `supportedLocales`; `locale` kullanıcı tercihine bağlı.
- Ayar: `GeneralSettings.language: system | tr | en | ar`.

### L2 — Bağlamsız çeviri (bildirimler)
Bildirim metinleri arka planda, `BuildContext` olmadan üretiliyor. Çözüm: `AppLocalizations.delegate.load(locale)` ile örnek yüklenip planlayıcıya **enjekte** edilir (`NotificationScheduler({required AppLocalizations l10n})` yerine bir `Future<AppLocalizations> Function()` sağlayıcı — planlama anında güncel dil okunur).

### L3 — Metin taşıma
324 benzersiz Türkçe metin, öncelik sırasıyla taşınır:
1. Vakit adları, navigasyon, ana ekran, geri sayım
2. Bildirim başlık/gövdeleri (kullanıcı bunları uygulamayı açmadan görüyor)
3. Ayarlar, hatırlatıcılar, sessiz pencereler
4. Alarm düzenleme ve görev ekranları
5. Araçlar (kıble, takip, zikirmatik), konum ekranları, hata durumları

### L4 — RTL (Arapça)
- Yön `MaterialApp` tarafından `Directionality` ile otomatik verilir.
- Sabit yönlü yerleşimler (`EdgeInsets.only(left/right)`, `Alignment.centerLeft`, `Icons.chevron_right`) taranıp **yön duyarlı** karşılıklarına çevrilir (`EdgeInsetsDirectional`, `AlignmentDirectional`, `Icons.chevron_right` → `Directionality`'ye duyarlı ikon).
- Sayılar: Arapça'da Batı rakamları kullanılır (`intl` varsayılanı `ar` için Arap-Hint rakamı verebilir; vakit saatlerinde Batı rakamı sabitlenir — takvimle karşılaştırma yapılabilsin).

### Çeviri kalitesi
- İngilizce ve Arapça'da namaz vakitleri yerleşik terimlerdir: Fajr/الفجر, Sunrise/الشروق, Dhuhr/الظهر, Asr/العصر, Maghrib/المغرب, Isha/العشاء.
- Çeviriler bu turda **tarafımdan** yazılır; anadili Arapça olan bir gözden geçirme önerilir (changelog'a not).

## Kapsam dışı
- Widget ve Siri kısayolu metinleri (Swift tarafı `Localizable.xcstrings`) — ayrı iş.
- Hicri ay adlarının Arapça yazımı (zaten Arapça kökenli; TR transkripsiyonu korunur).
- Android native metinleri.

## Doğrulama
`flutter analyze` + `flutter test`; ARB anahtarlarının üç dilde de bulunduğu testle sınanır. Cihaz testi Ekrem'de (özellikle Arapça yerleşimi).
