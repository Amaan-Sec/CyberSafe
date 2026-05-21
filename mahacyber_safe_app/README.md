# MahaCyber Safe — Flutter Prototype

Citizen cybersecurity companion app for Maharashtra State Cyber, built per the
MahaCyber Safe RFP. This is the **Phase 1 prototype**: cross-platform Flutter
app with **freeRASP** (Talsec) runtime protection wired into every screen.

## Modules in this prototype

| Module | Status | Notes |
|---|---|---|
| Splash + Login + Guest mode | ✅ | Mocked auth |
| Home dashboard | ✅ | Live RASP status banner + SOS shortcut |
| QR scanner | ✅ | `mobile_scanner` + URL heuristic on payload |
| URL safety check | ✅ | Offline heuristic (replace with VirusTotal/APIVoid) |
| Wi-Fi safety | ✅ | `network_info_plus`, name/BSSID/IP, naive heuristic |
| Breach check | ✅ | Mocked (swap to XposedOrNot / HIBP) |
| App permissions analyzer | ✅ | This app's own permissions |
| Security advisor | ✅ | Live device health score from RASP signals |
| Cyber news feed | ✅ | Static seed data |
| Emergency SOS | ✅ | Quick-dial helplines + SOS trigger stub |
| RASP status & threat log | ✅ | Real-time threat table |
| **freeRASP integration** | ✅ | All 16 Talsec threat callbacks wired |

## Prerequisites

- Flutter SDK ≥ 3.22 ([install guide](https://docs.flutter.dev/get-started/install))
- Android Studio or VS Code with Flutter extension
- Java 17 (for Android builds)
- For iOS: Xcode 15+, CocoaPods

## First-time setup

```bash
cd C:\MahaCyberSafe\mahacyber_safe_app

# Generate android/ and ios/ folders without overwriting our lib/
flutter create --project-name mahacyber_safe --org in.gov.maharashtracyber .

# Fetch packages
flutter pub get
```

## Run

```bash
# List devices
flutter devices

# Run (debug)
flutter run

# Release APK
flutter build apk --release
```

## RASP configuration (required before release)

Open `lib/core/rasp/rasp_service.dart` and replace the placeholders:

```dart
androidConfig: AndroidConfig(
  packageName: 'in.gov.maharashtracyber.safe',         // your final package
  signingCertHashes: ['<SHA-256 of release keystore>'], // base64-encoded
),
iosConfig: IOSConfig(
  bundleIds: ['in.gov.maharashtracyber.safe'],
  teamId: 'XXXXXXXXXX',                                // Apple Team ID
),
watcherMail: 'security@maharashtracyber.gov.in',       // alerts inbox
```

### Getting the signing-cert SHA-256

```bash
keytool -list -v -keystore release.keystore -alias <alias>
# Take the SHA-256 line, hex → bytes → base64-encode it.
```

Talsec has a one-liner script for this in their freeRASP docs.

## Required Android permissions

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.CALL_PHONE" />
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
<uses-permission android:name="android.permission.READ_CONTACTS" />
```

And set `android:minSdkVersion` to **23** or higher in `android/app/build.gradle`.

### Android — set minSdk to 23

In `android/app/build.gradle.kts` (or `build.gradle`):

```kotlin
defaultConfig {
    minSdk = 23
    targetSdk = 34
}
```

## Required iOS permissions

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Required to scan QR codes for cyber-safety analysis.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to read Wi-Fi details and assist with SOS.</string>
<key>NSContactsUsageDescription</key>
<string>Optional — used by SOS to notify your trusted contacts.</string>
```

## Architecture

```
lib/
├── main.dart                    # entry point; bootstraps RASP before runApp
├── app.dart                     # MaterialApp.router + locales (en/hi/mr)
├── core/
│   ├── rasp/
│   │   ├── rasp_service.dart    # Talsec freeRASP wrapper + state
│   │   └── rasp_status_banner.dart
│   ├── theme/                   # Material 3 theme
│   ├── router/                  # GoRouter
│   ├── constants/
│   └── services/
│       └── url_safety_service.dart   # heuristic URL classifier
└── features/
    ├── splash/
    ├── auth/
    ├── home/
    ├── scanners/                # QR, URL, Wi-Fi
    ├── breach/
    ├── permissions/
    ├── advisor/                 # uses RASP data live
    ├── news/
    ├── sos/
    └── rasp_status/             # threat log + summary
```

## What's NOT in the prototype (Phase 2+)

These are the agreed next steps once the foundation is approved:

- Real backend (.NET Core 7 + MS SQL) and JWT auth
- Real threat-intel integration (VirusTotal, APIVoid, XposedOrNot, CERT-In feed)
- Push notifications (FCM/APNs)
- Hidden apps detection, adware scan, threat analyzer
- OTP / call-forwarding status check
- Multilingual content (Marathi/Hindi/English strings + TTS)
- Admin web portal (React)
- Telemetry & SLA-grade observability
- Play Store / App Store signing + publishing
- ISO 27001 / OWASP MASVS audit prep

## USP ideas to layer on top later

The user mentioned adding USPs after the prototype lands. Strong candidates:

- **UPI safety mode**: detect risky "collect requests" / fake refund flows
- **SIM-swap detector**: signals via Telecom USSD + device binding diff
- **Family circle**: protect parents / kids with shared advisories
- **Voice-first cyber assistant** in Marathi/Hindi (TTS already wired)
- **On-device ML**: classify SMS/notifications as phishing locally
- **Trust score** shared with banks/UPI apps via a public REST endpoint
- **Offline-first cyber awareness courses** with completion badges

## License / ownership

Per the RFP, all source, designs, and APIs will be owned by MH Cyber on contract execution.
