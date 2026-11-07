# Google Play Console – uçtan uca yayın rehberi

Bu rehber, Kasım 2026 itibarıyla Play Console'un istediği her adımı ve **Penaltı Ustası için verilecek cevapları** sırayla anlatır.

## 0. Paket bilgileri (hazır)

| Konu | Değer |
|---|---|
| Paket adı | `com.benim.penaltiustasi` (Play'e ilk yüklemeden sonra değiştirilemez) |
| Hedef API | **36 (Android 16)**: 31 Ağustos 2026'dan beri yeni uygulamalar ve güncellemeler için zorunlu |
| En düşük Android | 7.0 (API 24) |
| Format | İmzalı **AAB** (Play için), imzalı **APK** (telefona doğrudan kurulum için) |
| Mimariler | AAB: arm64-v8a, armeabi-v7a, x86_64 · APK: arm64-v8a |
| 16 KB sayfa boyutu | Uyumlu (CI'da `zipalign -P 16` ile doğrulanıyor) |
| Kenardan kenara ekran | Açık; sistem çubukları ve çentik için güvenli alan boşluğu bırakılıyor |
| Büyük ekran | Yön kısıtı yok (sensor) ve boyut değiştirilebilir; tablet ile yatay ekranda ayrı yerleşim var |
| R8 | Açık (`minifyEnabled true`); `mapping.txt` her sürümle birlikte üretiliyor |
| İzinler | Yalnızca `VIBRATE`. İnternet, konum, reklam kimliği yok |
| Reklam / satın alma | Yok |

## 1. Bir kerelik: imza anahtarını GitHub'a ekle

Bu yapılmazsa her sürüm **geçici** anahtarla imzalanır ve Play'e yüklenemez.

1. Telefonda tarayıcıyla `github.com/aliyuksekal/penalti-ustasi` sayfasını aç → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.
2. Üç gizli değer ekle (isimleri birebir yaz):
   - `ANDROID_KEYSTORE_BASE64` → sana gönderilen `ANDROID_KEYSTORE_BASE64.txt` dosyasının içeriğinin tamamı
   - `ANDROID_KEYSTORE_PASSWORD` → sana gönderilen şifre
   - `ANDROID_KEY_ALIAS` → `upload`
3. **Actions** → **Android derleme (AAB + APK)** → **Run workflow**. Yeni sürümün notunda "✅ Kalıcı yükleme anahtarıyla imzalandı" yazmalı.

> `upload-keystore.jks` dosyasını ve şifresini **kaybetme**. Bu senin *yükleme anahtarın*. Play App Signing açık olduğu için kaybetsen bile Play Console'dan "yükleme anahtarını sıfırla" talebi açabilirsin, ama bu işlem günler sürer.

## 2. Uygulamayı oluştur

Play Console → **Tüm uygulamalar** → **Uygulama oluştur**
- Uygulama adı: `Penaltı Ustası`
- Varsayılan dil: **Türkçe – tr-TR**
- Uygulama mı, oyun mu: **Oyun**
- Ücretsiz mi, ücretli mi: **Ücretsiz**
- Beyanlar: Geliştirici Program Politikaları ✔, ABD ihracat yasaları ✔

## 3. Uygulama içeriği (Politika → Uygulama içeriği)

| Bölüm | Cevap |
|---|---|
| **Gizlilik politikası** | `https://aliyuksekal.github.io/gizlilik/penalti-ustasi-gizlilik.html` (dosya: `docs/penalti-ustasi-gizlilik.html`, gizlilik deposuna konmalı) |
| **Uygulama erişimi** | "Tüm işlevler özel erişim gerekmeden kullanılabilir" |
| **Reklamlar** | Bu sürümde "Hayır". AdMob eklenince "Evet" (docs/ADS.md) |
| **İçerik derecelendirmesi** | E-posta: matali.truz@gmail.com · Kategori: **Oyun**. Şiddet: **Yok**. Korku, cinsellik, küfür, kumar, uyuşturucu: **Hayır**. Kullanıcı etkileşimi / içerik paylaşımı / konum paylaşımı / dijital satın alma: **Hayır**. Beklenen sonuç: PEGI 3–7 / Herkes |
| **Hedef kitle ve içerik** | Önerilen yaş grupları: **13–15, 16–17, 18+**. "Çocuklara hitap edebilir mi?" sorusuna dürüstçe cevap ver. Karakterler sevimli olduğu için Google "çocuklara hitap ediyor" diyebilir. Oyun veri toplamadığı ve reklam içermediği için Aileler politikasına da uyuyor, istersen 9–12 yaşı da ekleyebilirsin; o durumda ek inceleme olur |
| **Veri güvenliği** | "Uygulamanız gerekli kullanıcı veri türlerini topluyor veya paylaşıyor mu?" → **Hayır**. Toplanan veri yok, paylaşılan veri yok, hesap yok |
| **Reklam kimliği** | "Uygulamanız reklam kimliği kullanıyor mu?" → **Hayır** |
| **Haber uygulaması** | Hayır |
| **Devlet uygulaması** | Hayır |
| **Finansal özellikler** | "Uygulamamda finansal özellik yok" |
| **Sağlık** | "Uygulamamın sağlık özelliği yok" |
| **COVID-19 / temas takibi** | Hayır |

## 4. Mağaza girişi (Büyüme → Mağaza varlığı → Ana mağaza girişi)

- Metinler: `store/listing/STORE_LISTING.md` (6 dil hazır, karakter sınırları kontrol edildi)
- Uygulama simgesi: `store/icon_512.png` (512×512, 32-bit PNG)
- Öne çıkan görsel: `store/feature_graphic_1024x500.png`
- Telefon ekran görüntüleri (2–8 adet, 1080×1920): `store/screenshots/tr_*.png` (Türkçe), `store/screenshots/en_*.png` (diğer diller)
- Tablet ekran görüntüleri (7" ve 10"): `store/screenshots/tablet_*.png` (2560×1600)
- Kategori: **Oyun → Spor**
- Etiketler: Futbol, Penaltı, Tek oyunculu, Çevrimdışı
- İletişim e-postası: matali.truz@gmail.com

## 5. Test ve yayın

1. **Test → Kapalı test** → kanal oluştur → testçi listesi ekle.
2. **Yeni sürüm oluştur** → GitHub Releases'teki `penalti-ustasi.aab` dosyasını yükle. Play App Signing'i kabul et (Google'ın yönetmesi önerilir).
3. Aynı sürümün **App bundle explorer → Downloads** bölümüne:
   - `mapping.txt` → *ReTrace mapping file* (R8 çökme raporlarını okunur yapar)
   - `native-debug-symbols.zip` → *Native debug symbols* (isteğe bağlı; büyük dosya)
4. Sürüm notu (TR/EN): GitHub Release notundan kopyala veya "İlk sürüm" yaz.
5. Kişisel geliştirici hesapları için kural: **en az 12 testçi, 14 gün kesintisiz** kapalı test yapılmadan üretime başvuru açılmaz.
6. 14 gün dolunca → **Üretime erişim başvurusu** → **Üretim** → sürümü yükselt.
7. **Ülkeler/bölgeler**: tümü (veya Türkiye + istediğin ülkeler).

## 6. Her güncellemede

- `main` dalına her gönderim otomatik derleme yapar; sürüm kodu kendiliğinden artar.
- Play Console'a yeni AAB'yi yükle, sürüm notunu yaz, gönder.
- Ön-lansman raporunu (Pre-launch report) kontrol et.


## Penaltı Ustası'na özel notlar
- Gerçek kulüp adı, arması, oyuncu adı kullanılmıyor; mağaza metinlerinde ve görsellerde de **kullanma** (marka ihlali → red/kaldırma).
- Aynı yükleme anahtarı (upload-keystore.jks) bu uygulama için de kullanılıyor; Play'de her uygulama ayrı imzalanır, sorun değildir.
