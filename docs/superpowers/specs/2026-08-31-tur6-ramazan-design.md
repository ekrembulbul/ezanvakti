# Tur 6 — Ramazan Modu (0.11.0)

Tarih: 2026-08-31 · Baz: Tur 5 (`feat/tur5-lokalizasyon`, DB v12) · Platform: yalnızca iOS

## Amaç

Ramazan boyunca uygulamanın öne çıkardığı bilgiyi değiştirmek: iftara/sahura kalan süre, imsakiye ve oruç takibi. 2027 Ramazan'ı 8 Şubat'ta başlıyor (hesaplanan tarih).

## Kapsam

### RM.1 — Mod tespiti ve ayarı
- `RamadanMode.isActive(date)` — `ReligiousDays` ile aynı hicri kaynaktan: hicri 9. ay boyunca aktif.
- Ayar: `GeneralSettings.ramadanMode: auto | off` (varsayılan `auto`).

### RM.2 — Ana ekran sayacı
Ramazan'da ana ekrana sayaç kartı: gündüz **iftara** (akşam), imsaktan önce **sahurun bitişine** (imsak) geri sayım. Mevcut geri sayım altyapısı kullanılır; hedef vakit moda göre seçilir.

### RM.3 — Sahur ve iftar hatırlatmaları
Ramazan'ın ilk gününde tek seferlik öneri sayfası: "Sahur (imsaktan 45 dk önce) ve iftar bildirimi ekleyeyim mi?" Onaylanırsa **normal bildirim satırları** olarak eklenir — Hatırlatıcılar'da görünür ve silinebilir. Gizli otomatik bildirim yok.

### RM.4 — Oruç takibi
- **DB v13:** `fasting_log(date TEXT PRIMARY KEY, status TEXT NOT NULL)` — `fasted | missed | exempt`.
- Araçlar > Namaz takibi ekranına Ramazan'da ikinci bölüm: oruç ızgarası (son 7 gün) ve kaza orucu sayacı (`qada_counts` yerine ayrı anahtar: `fasting_qada`).

### RM.5 — Takvim imsakiye görünümü
Ramazan'da Takvim sekmesi başlığı "Ramazan İmsakiyesi" olur ve tabloda İmsak ile Akşam sütunları vurgulanır. Paylaşım metni de imsakiye olur.

## Kapsam dışı
- Widget'ta Ramazan varyantı (snapshot v3) — ayrı iş; widget şu an sıradaki vakti gösteriyor, bu Ramazan'da da doğru.
- Mukabele/hatim takibi, teravih sayacı, Ramazan içerikleri.
- Live Activity iftar sayacı (push olmadan bayatlıyor).

## Doğrulama
`flutter analyze` + `flutter test`; mod tespiti, sayaç hedefi ve oruç kaydı birim testli. Üç dilde çeviri.
