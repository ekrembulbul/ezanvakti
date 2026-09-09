# Mimari Karar Kayıtları (ADR)

Bu klasör, projenin geri alınması pahalı kararlarını ve **gerekçelerini** kayıt altına alır. Amaç, altı ay sonra "burası neden böyle yapılmış?" sorusunun kodu tersine mühendislik yapmadan cevaplanabilmesidir.

Bir kayıt neyin yapıldığını değil, **neden o yolun seçildiğini ve hangi alternatiflerin neden elendiğini** anlatır. Kodun kendisi "ne" sorusunu zaten cevaplar.

## Kayıtlar

| # | Başlık | Konu |
|---|---|---|
| [0001](0001-alarm-watchdog-chain.md) | Nöbetçi alarm zinciri ve sert tavanlar | Görevli alarm durdurulunca neden geri döner, neden sonsuza kadar dönmez |
| [0002](0002-stop-gate.md) | StopGate — durdurma sonrası ekran kararı | Hangi ekranın açılacağı, "Görevi yap" düğmesinin varlık sebebi |
| [0003](0003-platform-alarm-models.md) | iOS ve Android için ayrı alarm modelleri | Neden ortak bir çalar soyutlaması yok, hangi davranış farkları kabul edildi |
| [0004](0004-single-source-prayer-time.md) | Vakit hesabında tek kaynak | Ekran, planlayıcı ve widget'ın aynı hesabı kullanma zorunluluğu |
| [0005](0005-notification-scheduling.md) | Bildirim planlaması | Atlama kimliği, sessiz pencere, sistem kotası, alarmdan yalıtım |

## Ne zaman yeni ADR yazılır?

Karar aşağıdakilerden en az birini taşıyorsa:

- Geri alınması pahalı (veri şeması, platform API'si, kalıcı davranış sözleşmesi)
- Gerekçesi koda bakınca görünmüyor
- Yanlış değiştirilirse alarm kaçırılır ya da yanlış vakit gösterilir
- Daha önce en az bir kez yanlış yapılmış ve düzeltilmiş

Küçük ve yerel kararlar için ADR yazılmaz; kod yorumu yeterlidir.

## Yazım kuralları

- Dosya adı: `NNNN-kebab-case-ingilizce-baslik.md`, numara sıralı ve tekrar kullanılmaz.
- İçerik Türkçe. Kod, tanımlayıcı ve komutlar olduğu gibi bırakılır.
- Bölümler: Bağlam ve problem / Karar / Sonuçlar (olumlu + bedeller) / Değerlendirilen alternatifler / Referanslar.
- Referanslar `dosya:satır` ve commit hash'i içerir; okuyan kaynağa gidebilmelidir.
- Kodda ya da commit geçmişinde dayanağı bulunamayan bir gerekçe **uydurulmaz**; `⚠️ Doğrulanmamış noktalar` başlığı altında açıkça işaretlenir.

## Durum yaşam döngüsü

`Önerildi` → `Kabul edildi` → (`Yerini aldı: NNNN` | `Geçersiz`)

Bir karar değiştiğinde eski kayıt **silinmez**; durumu güncellenir ve yerini alan kayda bağlanır. Kaydın değeri, terk edilmiş yolların da görünür kalmasındadır.
