# Bilinen sınırlamalar

1. **Görsel tarz:** Karakterler kodla üretilmiş 3D "oyuncak figür" modellerdir. Gönderilen tanıtım
   görsellerindeki gerçekçi kalite gerçek zamanlı mobil 3D'de mümkün değildir. Hazır CC0 karakter paketleri
   (Kenney, Quaternius) doğrudan indirme bağlantısı sunmadığı ve şut/dalış animasyonu içermediği için kullanılmadı.
   Daha detaylı .glb modeller sağlanırsa `scripts/world/player_model.gd` yerine takılabilir.
2. **Takım adları/armalar yok:** Yalnızca renk ve desen (marka hakları nedeniyle bilinçli tercih).
3. **Reklamlar test modunda:** AdMob hesabı bağlanana kadar simülasyon (docs/ADS.md).
4. **Gerçek cihaz testi:** Android 15 emülatöründe kurulum + açılış + çizim doğrulandı; telefonda dokunma
   hissi, performans ve ses henüz denenmedi.
5. **Çince/Korece:** Ayrı font paketlenmedi, Android sistem fontuna düşer.
6. **APK boyutu ~150 MB** (32 + 64 bit tek dosyada). Play üzerinden indirme çok daha küçüktür.
