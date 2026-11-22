#!/usr/bin/env python3
"""Adds the permissions/queries EcoRide needs to android/app/src/main/AndroidManifest.xml.
Idempotent. Run from the project root after `flutter create`."""
import re, sys, pathlib

p = pathlib.Path("android/app/src/main/AndroidManifest.xml")
if not p.exists():
    sys.exit("AndroidManifest.xml not found - run this from the project root after 'flutter create'.")
s = p.read_text()

perms = [
    "android.permission.INTERNET",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
]
add = ""
for perm in perms:
    if perm not in s:
        add += f'    <uses-permission android:name="{perm}"/>\n'
if add:
    s = re.sub(r"(<manifest[^>]*>\s*\n)", lambda m: m.group(1) + add, s, count=1)

if "<queries>" not in s:
    queries = """    <queries>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
        <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>
    </queries>
"""
    s = s.replace("<application", queries + "    <application", 1)

s = re.sub(r'android:label="[^"]*"', 'android:label="EcoRide"', s, count=1)
p.write_text(s)
print("AndroidManifest.xml patched.")
