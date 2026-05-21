# CyberSafe

> Citizen-facing digital safety companion for Maharashtra — Flutter mobile app + Python backend + web admin console.

CyberSafe helps everyday users detect and respond to the most common mobile-age threats: phishing links, fake Wi-Fi, leaked credentials, malicious apps, fraudulent SMS, and call-forwarding scams. It bundles a multilingual (English / हिन्दी / मराठी) Android app with a lightweight backend and a real-time admin console for analysts.

---

## Features

| Module | What it does |
|---|---|
| 🔍 **QR & URL scanner** | VirusTotal-backed link analysis with on-device heuristics |
| 📶 **Wi-Fi scanner** | Flags open / WEP / evil-twin networks nearby |
| 🛡️ **Breach check** | Email & phone exposure lookup |
| 🔐 **App permissions audit** | Surfaces over-privileged apps |
| 🧭 **Security advisor** | Personalised hardening checklist |
| 📰 **Cyber news** | Curated, locally-relevant advisories |
| 🚨 **SOS** | One-tap emergency contacts + 1930 hotline |
| 🛠️ **RASP status** | Runtime app self-protection self-test |
| 📱 **Installed / hidden apps** | Enumerates side-loaded & masked apps |
| 📞 **Call-forwarding probe** | Detects active `##21#` / `##62#` redirects |
| 📩 **SMS inspector** | Flags smishing patterns offline |
| ♿ **Accessibility audit** | Catches apps abusing AccessibilityService |
| 📢 **Adware scanner** | Identifies apps with excessive ad-SDKs or data harvesting |
| 📝 **Grievances** | In-app reporting workflow |

---

## Architecture

```
┌──────────────────┐        ┌────────────────────┐        ┌───────────────────┐
│  Flutter app     │ HTTPS  │   Python backend   │  files │  Admin console    │
│  (Android)       │ ─────► │   server.py :8000  │ ─────► │  /admin_console/  │
│                  │        │   threaded HTTP    │        │  (static HTML/JS) │
└──────────────────┘        └────────────────────┘        └───────────────────┘
        │                            │
        │ MethodChannel              │ env-only secrets
        ▼                            ▼
   Native Android                 .env (gitignored)
   (Kotlin)                       VT_API_KEY
                                  SARVAM_KEY
```

- **Mobile**: Flutter 3.x · GoRouter · MethodChannel bridge to Kotlin for device-level scans
- **Backend**: pure-stdlib `http.server` (no framework dependency) on port `8000`
- **Admin console**: static HTML served from `/admin_console/`
- **i18n**: EN / HI / MR strings dictionary in `lib/core/i18n/strings.dart`

---

## Quick start

### 1. Backend

```bash
git clone https://github.com/Amaan-Sec/CyberSafe.git
cd CyberSafe
cp .env.example .env       # add your VT_API_KEY + SARVAM_KEY
./run.sh                   # starts on http://0.0.0.0:8000
```

Endpoints:
- `http://<host>:8000/` — landing page + APK downloads
- `http://<host>:8000/admin_console/` — analyst dashboard
- `http://<host>:8000/api/health` — health check

### 2. Flutter app

```bash
cd mahacyber_safe_app
flutter pub get
flutter build apk --release --split-per-abi \
  --dart-define=SARVAM_KEY=$SARVAM_KEY \
  --dart-define=BASE_URL=http://<your-server>:8000
```

APKs land in `build/app/outputs/flutter-apk/`. Install the `arm64-v8a` variant on most modern phones.

### 3. Admin console

Open `http://<host>:8000/admin_console/` in any browser. Default-served from the same backend.

---

## Configuration

All secrets live in `.env` (gitignored). Template in `.env.example`:

```env
VT_API_KEY=     # https://www.virustotal.com/gui/my-apikey
SARVAM_KEY=     # https://dashboard.sarvam.ai/admin/api-keys
```

Empty values disable the corresponding feature gracefully (URL scanning / Sarvam TTS fallback to on-device flutter_tts).

---

## Project layout

```
.
├── server.py                  # backend HTTP server
├── run.sh                     # env-loading launcher
├── .env.example               # secret template
├── admin_console/             # static analyst UI
├── index.html                 # public landing + APK downloads
├── mahacyber_safe_app/        # Flutter app
│   ├── lib/
│   │   ├── core/              # router, theme, i18n, services
│   │   └── features/          # one folder per scanner/module
│   └── android/app/src/main/kotlin/  # native MethodChannel handlers
└── INSTALL_AND_TEST.md        # extended testing guide
```

---

## Security notes

- Secrets are **never** committed; the repo uses `--dart-define` + env-var injection only.
- VirusTotal scans use the public free-tier endpoint — rate-limited to 4 req/min.
- The Android app declares only the runtime permissions each feature actually needs; nothing is requested at install time.
- The adware scanner uses **declared component class names** (no DEX / bytecode parsing), making it fast and side-effect free.

---

## License

Prototype — all rights reserved. Contact the maintainer for licensing terms.

---

**Build:** v13 · **Date:** 2026-05-21 · **Maintainer:** [@Amaan-Sec](https://github.com/Amaan-Sec)
