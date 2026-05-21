# MahaCyber Safe — Admin Console (Prototype)

Single-file web admin portal covering RFP §6.4.2 (Administrative Web Application).

## How to open

Just double-click `index.html` — it opens in any modern browser. No server, no install.

For local file:// CORS issues with Chart.js, you can also run:

```bash
cd admin_console
python3 -m http.server 8080
# then open http://localhost:8080
```

## Demo credentials

- Username: `admin`
- Password: `admin`

## Modules implemented (matches RFP §6.4.2)

| Module | Status |
|---|---|
| Login (Administrator / Govt Authority roles) | ✅ |
| Dashboard (citizen count, threat counts, scan totals, grievances) | ✅ |
| Users & Roles management (CRUD) | ✅ |
| Cyber News & Advisories CMS (draft → approval → publish, multilingual) | ✅ |
| Threat Reports (live RASP threats from the mobile app) | ✅ |
| Scan Analytics (QR / URL / Wi-Fi / breach trends, categories) | ✅ |
| Citizen Grievances ticketing | ✅ |
| Audit Trail (immutable log of admin actions) | ✅ |
| Settings & API integrations (VirusTotal, APIVoid, XposedOrNot, CERT-In, FCM, Talsec) | ✅ |

## Tech notes

- Pure HTML + Tailwind CSS (CDN) + Chart.js (CDN)
- All data is in-memory mock data — wire to the .NET Core / Node backend in Phase 2
- Responsive grid layout, Material-style cards
- Designed to be embedded into the production React/.NET admin portal later

## Phase 2 wiring

When the backend lands, replace the `DATA` object at the top of `<script>` with
fetch calls to your REST API (the surface area is already designed as tables
and CRUD modals, so the swap is mechanical).
