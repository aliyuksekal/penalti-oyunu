# Ağır Yük – Kargo Taşıma (Godot 4)

2D fizik tabanlı kamyon/kargo taşıma oyunu. Kasadaki yükleri düşürmeden teslimat noktalarına ulaştır.
Hiç görsel dosya yok: araziden kamyonlara her şey kodla (Polygon2D / Line2D) çiziliyor.

## Dosyalar
| Dosya | Görev |
|---|---|
| `Main.tscn` | Main (Node2D) → Terrain, Truck |
| `TerrainGenerator.gd` | Sonsuz, aşamalı zorlaşan arazi (chunk), her 500 m'de teslimat noktası |
| `TruckController.gd` | Kamyon fiziği, süspansiyon (GrooveJoint2D + DampedSpringJoint2D), kamera |
| `TruckCatalog.gd` | 6 kamyon: fiyat (jeton), güç/tutuş/yakıt/süspansiyon çarpanları |
| `TruckArt.gd` | Kamyon ve tekerlek çizimi (oyun + garaj vitrini) |
| `CargoAndGameManager.gd` | Yükler, HUD, dokunmatik pedallar, teslimat, oyun sonu, ekonomi, kayıt |
| `MenuScreen.gd` | Menü: Kamyonlar / Geliştirme / Mağaza |
| `AdService.gd` | Reklam + uygulama içi satın alma katmanı (şu an TEST modu) |

## Ekonomi
- **Altın**: teslimatlardan kazanılır; geliştirmeler altınla alınır.
- **Jeton**: sadece kamyon almak için. 100 altın = 10 jeton, ödüllü reklam = +50 jeton, jeton paketleri.
- Kamyon alma, geliştirme ve altın→jeton dönüştürmeden önce tam ekran reklam gösterilir. Alt banner yok.

## Derleme
`main` dalına her gönderimde GitHub Actions imzalı **AAB + APK** üretir, testleri çalıştırır,
emülatörde açar ve Releases'e koyar. İmza için depo ayarlarında 3 gizli anahtar gerekir:
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (yoksa geçici anahtar kullanılır).
