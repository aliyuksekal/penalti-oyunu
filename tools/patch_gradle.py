#!/usr/bin/env python3
"""Godot Android derleme şablonundaki build.gradle dosyasının release buildType
bloğuna R8 (minifyEnabled + proguard kuralları) ekler. Play Console'un
"R8 optimizasyonu" önerisini karşılar. Birden çok kez çalıştırmak güvenlidir."""
import re
import sys

path = sys.argv[1]
src = open(path, encoding="utf-8").read()
if "proguard-godot.pro" in src:
    print("zaten yamalı")
    sys.exit(0)

bt = src.find("buildTypes")
if bt < 0:
    sys.exit("buildTypes bulunamadı")
m = re.compile(r"\n(\s*)release\s*\{").search(src, bt)
if not m:
    sys.exit("buildTypes içinde release bloğu bulunamadı")
indent = m.group(1) + "    "
insert = (
    f"\n{indent}minifyEnabled true"
    f"\n{indent}proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-godot.pro'"
)
pos = m.end()
src = src[:pos] + insert + src[pos:]
open(path, "w", encoding="utf-8").write(src)
print("R8 etkinleştirildi")
