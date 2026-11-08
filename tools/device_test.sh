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
java -jar /tmp/bundletool.jar validate --bundle=build/agir-yuk.aab > "$OUT/bundletool_validate.txt" 2>&1 \
  && echo "AAB doğrulama: OK" | tee -a "$OUT/result.txt" || { echo "AAB doğrulama: HATA" | tee -a "$OUT/result.txt"; FAIL=1; }
java -jar /tmp/bundletool.jar build-apks --bundle=build/agir-yuk.aab --output=/tmp/u.apks --mode=universal \
  --ks="$KS" --ks-pass="pass:$PASS" --ks-key-alias="$ALIAS" --key-pass="pass:$PASS" --overwrite > /dev/null 2>&1
unzip -o -q /tmp/u.apks universal.apk -d /tmp
echo "AAB evrensel APK kurulumu: $(adb install -r /tmp/universal.apk 2>&1 | tail -1)" | tee -a "$OUT/result.txt"
adb uninstall "$PKG" > /dev/null 2>&1

# 2) Kullanıcının telefona kuracağı APK'nin kendisi
R=$(adb install -r build/agir-yuk.apk 2>&1 | tail -1)
echo "Release APK kurulumu: $R" | tee -a "$OUT/result.txt"
if [[ "$R" != *Success* ]]; then
  echo "Release APK kurulamadı, AAB'den üretilen APK ile açılış test ediliyor" | tee -a "$OUT/result.txt"
  adb install -r /tmp/universal.apk > /dev/null 2>&1 || true
  FAIL=1
fi

# 3) Aç, bekle, ekran görüntüsü al, dokun, çökme kontrolü
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
sleep 30
adb exec-out screencap -p > "$OUT/01_launch.png"
SIZE=$(adb shell wm size | tail -1 | awk '{print $NF}'); W=${SIZE%x*}; H=${SIZE#*x}
# BAŞLA (sol alt) -> oyun; sonra GAZ (sağ alt) 4 sn basılı tut
if [ "$W" -gt "$H" ]; then BX=$((W*16/100)); BY=$((H*88/100)); else BX=$((W*25/100)); BY=$((H*95/100)); fi
adb shell input tap $BX $BY; sleep 4
adb exec-out screencap -p > "$OUT/02_game.png"
adb shell input swipe $((W*88/100)) $((H*95/100)) $((W*88/100)) $((H*95/100)) 5000; sleep 1
adb exec-out screencap -p > "$OUT/03_after_gas.png"
PID=$(adb shell pidof "$PKG" | tr -d '\r')
adb logcat -d > "$OUT/logcat.txt"
if [ -n "$PID" ]; then echo "Uygulama çalışıyor (pid $PID)" | tee -a "$OUT/result.txt"; else echo "Uygulama çalışmıyor / kapandı" | tee -a "$OUT/result.txt"; FAIL=1; fi
if grep -E "FATAL EXCEPTION|SCRIPT ERROR|signal 11|Abort message" "$OUT/logcat.txt" | head -5 | tee -a "$OUT/result.txt" | grep -q .; then FAIL=1; fi
echo "SONUÇ: $([ $FAIL = 0 ] && echo BAŞARILI || echo HATALI)" | tee -a "$OUT/result.txt"
exit $FAIL
