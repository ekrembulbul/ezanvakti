# Yakındaki Camiler — Tasarım Spec'i

1 Ekim 2026 brainstorming'inin üçüncü alt projesi (diğerleri:
`2026-10-01-gunun-icerigi-design.md`, `2026-10-01-hutbe-design.md`).
Kendi cami verisi tutulmaz; telefondaki harita uygulaması seçilen konumun
çevresinde "cami" aramasıyla açılır.

## 1. Kullanıcı kararları ve gerekçe

| # | Karar |
|---|---|
| C1 | Kendi cami verisi yok. Araştırmada OSM ~%52 kapsadı (≈47 bin / Diyanet ≈90 bin); Overture, Wikidata ve dört büyükşehir verisiyle bile ~%60–65'e çıkıyordu. Kullanıcı harita uygulamasında aramayı önerdi |
| C2 | Düğmeye basınca her seferinde sorulur: "Vakit konumuna göre" ya da "Bulunduğum yere göre". İkisinde de arama o koordinatın çevresinde yapılır |
| C3 | Birden fazla harita uygulaması varsa ilk seferde sorulur, seçim hatırlanır, ayarlardan değiştirilebilir |
| C4 | Araçlar ekranında, her dilde görünür; arama metni dile göre |

## 2. Bulgular

| # | Bulgu | Kaynak |
|---|---|---|
| B1 | Apple Haritalar (iOS 18.4+): `https://maps.apple.com/search?query=…&center=lat,lon&span=0.05,0.05` | https://developer.apple.com/documentation/mapkit/unified-map-urls (doğrulandı) |
| B2 | Apple Haritalar eski biçim (arşiv belge): `q` arama, `sll` arama konumu, `z` yakınlık; örnek `?q=Mexican+Restaurant&sll=50.89,4.34&z=10` | Apple Map Links arşivi (doğrulandı) |
| B3 | Google Haritalar iOS: `comgooglemaps://?q=Pizza&center=37.75,-122.42`, ayrıca `zoom`; yüklü mü `canOpenURL` ile | https://developers.google.com/maps/documentation/urls/ios-urlscheme (doğrulandı) |
| B4 | Android: `geo:lat,lon?z=zoom&q=query` — koordinat aramanın merkezi ve yanlılığıdır | https://developer.android.com/guide/components/google-maps-intents (doğrulandı) |
| B5 | Yandex Haritalar bağlantı biçimi resmî belgeden doğrulanamadı | — |
| B6 | Uygulama hedefi iOS 17 (B1 iOS 18.4 ister) | `ios/Podfile`, mimari notları |
| B7 | Konumlarda koordinat isteğe bağlı: GPS konumu kendi koordinatını, il/ilçe seçilerek eklenen konum sunucunun ilçe merkezini taşır; eski kayıtlarda boş olabilir | `lib/core/models/location.dart:9-10`, `lib/features/location/data/places_api.dart:70-90` |
| B8 | GPS izni ve konum alma akışı mevcut (izin isteme, kalıcı ret, servis kapalı ayrımı); ancak sonucu sunucuda ilçeye çözüyor | `lib/features/location/data/gps_location_service.dart:42-68` |
| B9 | iOS'ta `LSApplicationQueriesSchemes` yok; Android `<queries>` yalnız metin işleme niyetini içeriyor | `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml:90` |

## 3. Akış

1. **Araçlar → Yakındaki camiler.** Alttan açılan kısa seçim: "Vakit
   konumuna göre (Kadıköy)" ve "Bulunduğum yere göre".
2. **Vakit konumu:** etkin konumun koordinatı. Koordinat yoksa arama konum
   adıyla yapılır ("cami Kadıköy"), merkez verilmez.
3. **Bulunduğum yer:** telefonun konumu bir kez alınır (orta doğruluk, 10 sn
   zaman aşımı); sunucuya gönderilmez, ilçeye çözülmez. İzin yoksa mevcut
   izin akışıyla istenir. Reddedilir, servis kapalıdır ya da zaman aşımı
   olursa "Konumun alınamadı. Vakit konumuna göre aransın mı?" sorulur.
4. **Harita uygulaması (iOS):** Apple Haritalar her zaman; Google Haritalar
   ve (cihaz denemesi geçerse) Yandex Haritalar yüklüyse seçenek olur. Birden
   fazla varsa ilk seferde sorulur, seçim hatırlanır; ayarlarda "Harita
   uygulaması" satırıyla değiştirilir. Seçilen uygulama sonradan silinmişse
   yeniden sorulur.
5. **Harita uygulaması (Android):** `geo:` bağlantısı açılır; uygulama
   seçimini ve hatırlamayı sistem yapar. Ayar satırı Android'de görünmez.
6. **Bağlantılar (arama metni Q, merkez lat,lon):**
   - Apple, iOS 18.4+: `https://maps.apple.com/search?query=Q&center=lat,lon&span=0.03,0.03`
   - Apple, iOS 17–18.3: `https://maps.apple.com/?q=Q&sll=lat,lon&z=14`
   - Google (iOS): `comgooglemaps://?q=Q&center=lat,lon&zoom=14`
   - Android: `geo:lat,lon?z=14&q=Q`
   - Yandex: cihazda denenecek biçim; geçmezse seçenekten çıkar.
   - Merkezsiz (koordinat yok): aynı bağlantılar merkez parametresi olmadan,
     Q = "cami <konum adı>".
7. **Arama metni:** dile göre — tr "cami", en "mosque", ar "مسجد" (ARB).
8. **Hata:** hiçbir harita uygulaması açılamazsa kısa hata mesajı;
   `AppLogger` ile loglanır.

## 4. Platform ve bağımlılık

- `url_launcher` (hutbe spec'iyle ortak).
- iOS `Info.plist`: `LSApplicationQueriesSchemes` → `comgooglemaps`,
  `yandexmaps`.
- Android manifest `<queries>`: `ACTION_VIEW` + `geo` şeması.
- iOS sürümü `dart:io` platform sürüm dizgisinden okunur (yeni bağımlılık
  yok).
- Lokalizasyon: düğme, seçim satırları, hata/izin metinleri, ayar satırı,
  arama metni.

## 5. Gizlilik

Koordinat yalnız kullanıcının seçtiği harita uygulamasına gider, bizim
sunucumuza gitmez. Gizlilik belgesine bu cümle eklenir.

## 6. Test

- **Birim:** her uygulama ve iOS sürümü için bağlantı üretimi; merkezsiz
  geri düşüş; dile göre arama metni; hatırlanan seçimin silinmiş uygulamada
  sıfırlanması.
- **Widget:** seçim sayfası, izin reddinde vakit konumu sorusu.
- **Elle (kullanıcı):** iPhone'da Apple (iOS 27 cihaz) ve Google Haritalar;
  Android'de `geo:`; Yandex bağlantısı. iOS 17–18.3 biçimi elde cihaz yoksa
  test edilemeyecek — teslimde belirtilir.

## 7. Kapsam dışı

Uygulama içi cami listesi ya da haritası, cami verisi toplama, Diyanet'ten
veri izni.
