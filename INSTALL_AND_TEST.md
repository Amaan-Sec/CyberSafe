# MahaCyber Safe — Install & Test Guide

Both deliverables are ready.

## 1. Mobile App (Android)

### Pick the right APK for your phone

Almost every modern Android phone (2019+) is `arm64-v8a` — use that one.

| File | Size | When to use |
|---|---|---|
| `mahacyber_safe_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` | 32 MB | **Most modern phones (recommended)** |
| `mahacyber_safe_app/build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` | 27 MB | Older 32-bit Android phones |
| `mahacyber_safe_app/build/app/outputs/flutter-apk/app-x86_64-release.apk` | 35 MB | x86 emulators only |
| `mahacyber_safe_app/build/app/outputs/flutter-apk/app-debug.apk` | 188 MB | Debug build (large, has all ABIs) |

### Install on your phone

1. Copy `app-arm64-v8a-release.apk` to your phone (USB / Google Drive / email yourself).
2. Tap it on the phone → Android will prompt **"Install unknown apps"** → enable for your file manager / browser.
3. Tap Install. The app installs as **"MahaCyber Safe"**.

### What RASP does on first launch

freeRASP (Talsec) initializes **before** the UI renders. On the home screen
you'll see a colored banner showing live threat status:

- ✅ Green = clean
- 🟡 Yellow = low/medium threat (screenshot, dev mode, etc.)
- 🟠 Orange = high (debugger, simulator, unofficial store)
- 🔴 Red = critical (rooted device, hooking framework, malware, tampering)

### Try to trigger RASP detections

| Action | Expected detection |
|---|---|
| Take a screenshot inside the app | "Screenshot captured" (low) |
| Enable USB debugging in Developer Options | "Developer mode enabled" (low) |
| Connect a system VPN | "System VPN active" (medium) |
| Run on a rooted phone or Magisk | "Rooted / jailbroken device" (critical) |
| Run on a Genymotion / Android Studio emulator | "Emulator / simulator detected" (high) |
| Sideload (which you just did!) on a fresh install | "Installed from unofficial store" (high) |
| Attach Frida / objection | "Runtime hooking detected" (critical) |

All detections appear in **RASP Status** screen (bottom nav) with a citizen-friendly
recommendation and a severity tag.

### Features you can test

- **Home** — dashboard with live RASP banner + SOS shortcut
- **QR Scanner** — scan a QR code, app classifies the URL behind it
- **URL Scanner** — paste a URL, get a heuristic safety verdict
- **Wi-Fi Scanner** — shows your current SSID/BSSID and a safety hint
- **Breach Check** — enter an email, get a mocked breach result
- **App Permissions** — list of what this app itself requests
- **Security Advisor** — composite score derived from live RASP signals
- **Cyber News** — seed list of advisories
- **SOS** — quick-dial 112 / 1930 (cyber crime) / 100 (police) / 1091 (women)
- **RASP Status** — full timeline of every detection

---

## 2. Admin Console (Web)

Open `admin_console/index.html` in any browser (double-click works).

### Login

- Username: `admin`
- Password: `admin`
- Role: pick Administrator or Govt Authority

### What you'll see

| Page | Demonstrates |
|---|---|
| Dashboard | KPI cards, scan-trend chart, threat-severity donut, system health |
| Users & Roles | CRUD on admin/govt users with role-based access |
| Cyber News & Advisories | Draft → Approval → Publish workflow, multilingual flags |
| Threat Reports | Live feed of RASP detections from all phones (mocked) |
| Scan Analytics | QR/URL trend bar chart, threat-category pie |
| Citizen Grievances | Ticketing system with status badges |
| Audit Trail | Immutable log of every admin action (timestamped, IP'd) |
| Settings & APIs | External integrations (VirusTotal, APIVoid, XposedOrNot, CERT-In, FCM, Talsec) |

This is a single self-contained HTML file. Everything works offline; data is
mocked and resets on reload. In Phase 2 you swap the `DATA = {...}` object for
fetch calls to the .NET Core REST API.

---

## What still needs to be done before production

These are intentionally **out of scope for this prototype** (per the original
handoff doc):

- Replace the placeholder Android signing-cert SHA-256 in `rasp_service.dart`
  (currently `AAAA…AA=` — only matters when you ship the **release** build to
  citizens; the debug-signed APK above will detect itself as "unofficial store"
  which is expected)
- Replace iOS bundle id + Apple Team ID (iOS not built yet — needs a Mac)
- Real backend (.NET Core 7 + MS SQL + JWT)
- Real threat-intel API keys (the admin console shows them as "Connected" but
  they're mocked)
- Push notifications via FCM
- Hidden apps scan, adware scan, threat analyzer (RFP §6.4.1.6)
- OTP / call-forwarding check (RFP §6.4.1.4)
- ISO 27001 / OWASP MASVS audit prep
- Play Store publishing
