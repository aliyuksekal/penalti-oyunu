# Ödüllü reklamlar (AdMob) – nasıl açılır

Şu an oyunda **gerçek reklam yok**. Reklam düğmeleri ("bölümü geç", "jetonları ikiye katla",
ipucu, mağazada "+50") açıkça **TEST** yazan 5 saniyelik bir simülasyon gösterir ve ödülü verir.
Kod tek bir noktadan geçer: `scripts/autoload/ads.gd`.

Gerçek reklam için gerekenler:
1. admob.google.com'da hesap aç, uygulamayı ekle (paket: `com.benim.penaltiustasi`).
2. Bir **Ödüllü (Rewarded)** reklam birimi oluştur; Uygulama Kimliği ve Reklam Birimi Kimliğini bana ver.
3. Godot 4 için Android AdMob eklentisi (ör. poing-studios/godot-admob-android) projeye eklenir,
   `ads.gd` içindeki `show_rewarded` gerçek reklamı çağıracak şekilde güncellenir.
4. Play Console'da: Reklamlar = **Evet**; Veri güvenliği formu AdMob'un topladığı verilere göre
   güncellenir (cihaz/reklam kimliği, uygulama etkileşimleri vb.); gizlilik politikası güncellenir;
   `AD_ID` izni eklenir.
5. Çocuklara yönelik hedef kitle seçilirse AdMob "çocuklara yönelik içerik" ayarları zorunludur.

Politika notu: Yalnızca kullanıcının kendi isteğiyle açtığı **ödüllü** reklamlar kullanılıyor;
oyunu kesen zorunlu tam ekran reklam yok. Bu, Play'in "rahatsız edici reklam" kurallarıyla uyumludur.
