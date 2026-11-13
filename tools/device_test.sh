#!/usr/bin/env bash
# Android emülatöründe kurulum + açılış testi. CI'da android-emulator-runner içinde çalışır.
set -u
PKG=com.benim.agiryuk
OUT=build/device
mkdir -p "$OUT"
KS="$GODOT_ANDROID_KEYSTORE_RELEASE_PATH"; PASS="$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"; ALIAS="$GODOT_ANDROID_KEYSTORE_RELEASE_USER"
adb wait-for-device
echo "ABI listesi: $(adb shell getprop ro.product.cpu.abilist)" | tee "$OUT/result.txt"
echo "Android: $(adb shell getprop ro.build.version.release) (SDK $(adb shell getprop ro.build.version.sdk))" | tee -a "$OUT/result.txt"
FAIL=0

# 1) Play'e gidecek AAB'den evrensel APK üret (AAB'yi de doğrular) ve kur
java -jar /tmp/bundletool.jar validate --bundle=build/drop-zero.aab > "$OUT/bundletool_validate.txt" 2>&1 \
  && echo "AAB doğrulama: OK" | tee -a "$OUT/result.txt" || { echo "AAB doğrulama: HATA" | tee -a "$OUT/result.txt"; FAIL=1; }
java -jar /tmp/bundletool.jar build-apks --bundle=build/drop-zero.aab --output=/tmp/u.apks --mode=universal \
  --ks="$KS" --ks-pass="pass:$PASS" --ks-key-alias="$ALIAS" --key-pass="pass:$PASS" --overwrite > /dev/null 2>&1
unzip -o -q /tmp/u.apks universal.apk -d /tmp
echo "AAB evrensel APK kurulumu: $(adb install -r /tmp/universal.apk 2>&1 | tail -1)" | tee -a "$OUT/result.txt"
adb uninstall "$PKG" > /dev/null 2>&1

# 2) Kullanıcının telefona kuracağı APK'nin kendisi
R=$(adb install -r build/drop-zero.apk 2>&1 | tail -1)
echo "Release APK kurulumu: $R" | tee -a "$OUT/result.txt"
if [[ "$R" != *Success* ]]; then
  echo "Release APK kurulamadı, AAB'den üretilen APK ile açılış test ediliyor" | tee -a "$OUT/result.txt"
  adb install -r /tmp/universal.apk > /dev/null 2>&1 || true
  FAIL=1
fi

# 3) Aç, bekle, ekran görüntüsü al, dokun, çökme kontrolü
# Tuşların yeri banner reklama göre değiştiği için dokunulacak yer ekran görüntüsünden bulunur
# (sabit koordinatla yanlışlıkla reklama dokunulup Chrome açılıyordu).
adb shell settings put secure immersive_mode_confirmations confirmed > /dev/null 2>&1
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
sleep 35
shot() { adb exec-out screencap -p > "$OUT/$1"; }
focus_ok() { adb shell dumpsys window 2>/dev/null | grep -E "mCurrentFocus|mFocusedApp" | grep -q "$PKG"; }
find_green() { python3 tools/find_blob.py "$1" "$2" "$3" "$4" "$5" 2>/dev/null; }

shot 01_menu_portrait.png
adb shell settings put system user_rotation 1; sleep 6
shot 02_menu_landscape.png
adb shell settings put system user_rotation 0; sleep 6
shot tmp.png
# BAŞLA: sol alttaki yeşil tuş
P=$(find_green "$OUT/tmp.png" 0.0 0.6 0.45 1.0)
if [ -n "$P" ]; then
  echo "BAŞLA tuşu bulundu: $P" | tee -a "$OUT/result.txt"
  adb shell input tap $P; sleep 6
else
  echo "BAŞLA tuşu ekranda bulunamadı" | tee -a "$OUT/result.txt"; FAIL=1
fi
shot 03_game_portrait.png
# GAZ: sağ alttaki yeşil pedal, 5 sn basılı tut
G=$(find_green "$OUT/03_game_portrait.png" 0.6 0.6 1.0 1.0)
if [ -n "$G" ]; then
  echo "GAZ pedalı bulundu: $G" | tee -a "$OUT/result.txt"
  adb shell input swipe $G $G 5000; sleep 1
else
  echo "GAZ pedalı ekranda bulunamadı" | tee -a "$OUT/result.txt"; FAIL=1
fi
shot 04_after_gas.png
# ekranı döndür: üst bilgi şeridi hep en üstte, tuşlar banner'ın iki yanında kalmalı
adb shell settings put system user_rotation 1; sleep 6
shot 05_game_landscape.png
G2=$(find_green "$OUT/05_game_landscape.png" 0.7 0.5 1.0 1.0)
if [ -n "$G2" ]; then adb shell input swipe $G2 $G2 3000; sleep 1; fi
shot 06_game_landscape_gas.png
adb shell settings put system user_rotation 0; sleep 5
shot 07_portrait_again.png
rm -f "$OUT/tmp.png"
if focus_ok; then echo "Oyun ön planda (reklama yanlışlıkla dokunulmadı)" | tee -a "$OUT/result.txt"; else echo "Oyun ön planda DEĞİL: $(adb shell dumpsys window | grep mCurrentFocus | tr -d '\r')" | tee -a "$OUT/result.txt"; FAIL=1; fi
PID=$(adb shell pidof "$PKG" | tr -d '\r')
adb logcat -d > "$OUT/logcat.txt"
grep -E "godot +: \[reklam\]" "$OUT/logcat.txt" | sed 's/^.*godot *: //' | sort -u | head -12 | tee -a "$OUT/result.txt"
if [ -n "$PID" ]; then echo "Uygulama çalışıyor (pid $PID)" | tee -a "$OUT/result.txt"; else echo "Uygulama çalışmıyor / kapandı" | tee -a "$OUT/result.txt"; FAIL=1; fi
if grep -E "FATAL EXCEPTION|SCRIPT ERROR|signal 11|Abort message" "$OUT/logcat.txt" | head -5 | tee -a "$OUT/result.txt" | grep -q .; then FAIL=1; fi
echo "SONUÇ: $([ $FAIL = 0 ] && echo BAŞARILI || echo HATALI)" | tee -a "$OUT/result.txt"
exit $FAIL
