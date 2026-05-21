"""MahaCyber Safe — combined static+API server (prototype).

Serves:
  GET  /                                       → landing page
  GET  /admin_console/                         → admin portal
  GET  /mahacyber_safe_app/build/.../*.apk     → APK downloads

  POST /api/devices/register                   → upsert a device (keyed by deviceId)
  GET  /api/devices                            → list registered devices
  DELETE /api/devices/<id>                     → remove a device
  POST /api/threats                            → log a RASP threat event
  GET  /api/threats                            → list threat events
  GET  /api/health                             → liveness probe

State is persisted to ./server_data/{devices,threats}.json so it survives restarts.
"""

import base64
import json
import os
import re
import threading
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime
from email.utils import parsedate_to_datetime
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse

ROOT = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(ROOT, "server_data")
DEVICES_FILE = os.path.join(DATA_DIR, "devices.json")
THREATS_FILE = os.path.join(DATA_DIR, "threats.json")
INCIDENTS_FILE = os.path.join(DATA_DIR, "incidents.json")
NEWS_FILE = os.path.join(DATA_DIR, "news.json")
AUDIT_FILE = os.path.join(DATA_DIR, "audit.json")
SCANS_FILE = os.path.join(DATA_DIR, "scans.json")
GRIEVANCES_FILE = os.path.join(DATA_DIR, "grievances.json")
os.makedirs(DATA_DIR, exist_ok=True)

_lock = threading.Lock()


def _load(path):
    if not os.path.exists(path):
        return []
    try:
        with open(path, "r") as f:
            return json.load(f)
    except Exception:
        return []


def _save(path, data):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, path)


def now_iso():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def audit_log(action: str, user: str = "system", ip: str = "-", detail: str = ""):
    """Append an audit event, capped at 5000 most recent entries."""
    entry = {
        "ts": now_iso(),
        "user": user or "system",
        "action": action,
        "ip": ip or "-",
        "detail": detail or "",
    }
    try:
        with _lock:
            items = _load(AUDIT_FILE)
            items.insert(0, entry)
            items = items[:5000]
            _save(AUDIT_FILE, items)
    except Exception as e:
        print(f"[audit] failed to persist: {e}")
    return entry


_VALID_SCAN_KINDS = {"url", "qr", "wifi", "breach", "ip", "call_forward", "sms", "accessibility"}
_VALID_SCAN_VERDICTS = {"safe", "suspicious", "malicious", "clean", "breached", "unknown"}


def record_scan(kind: str, verdict: str, target: str = "", device_id: str = "",
                citizen: str = "", latency_ms: int = 0, ip: str = "-"):
    """Persist one scan event. Capped at 10000 most recent."""
    kind = (kind or "").lower().strip()
    if kind not in _VALID_SCAN_KINDS:
        return None
    verdict = (verdict or "unknown").lower().strip()
    if verdict not in _VALID_SCAN_VERDICTS:
        verdict = "unknown"
    entry = {
        "id": int(datetime.now().timestamp() * 1000),
        "ts": now_iso(),
        "kind": kind,
        "verdict": verdict,
        "target": (target or "")[:300],
        "deviceId": device_id or "",
        "citizen": citizen or "",
        "latency_ms": int(latency_ms or 0),
        "ip": ip or "-",
    }
    try:
        with _lock:
            items = _load(SCANS_FILE)
            items.insert(0, entry)
            items = items[:10000]
            _save(SCANS_FILE, items)
    except Exception as e:
        print(f"[scans] failed to persist: {e}")
    return entry


def scans_summary(days: int = 7):
    """Aggregate scans into per-day buckets by kind, for the last `days` days
    ending today. Also returns top-level KPIs the admin dashboard needs."""
    days = max(1, min(int(days or 7), 90))
    from datetime import timedelta
    today = datetime.now().date()
    day_keys = [(today - timedelta(days=days - 1 - i)) for i in range(days)]
    labels = [d.strftime("%a") if days <= 7 else d.strftime("%m-%d") for d in day_keys]
    by_kind = {"url": [0] * days, "qr": [0] * days, "wifi": [0] * days,
               "breach": [0] * days, "ip": [0] * days,
               "call_forward": [0] * days, "sms": [0] * days,
               "accessibility": [0] * days}
    threats_found = 0
    total = 0
    latency_total = 0
    latency_count = 0
    by_verdict = {"safe": 0, "suspicious": 0, "malicious": 0, "clean": 0,
                  "breached": 0, "unknown": 0}
    with _lock:
        items = _load(SCANS_FILE)
    cutoff_str = (today - timedelta(days=days - 1)).strftime("%Y-%m-%d")
    for s in items:
        ts = s.get("ts", "")
        if not ts or ts[:10] < cutoff_str:
            continue
        try:
            d = datetime.strptime(ts[:10], "%Y-%m-%d").date()
        except Exception:
            continue
        idx = (d - day_keys[0]).days
        if idx < 0 or idx >= days:
            continue
        kind = s.get("kind", "")
        if kind in by_kind:
            by_kind[kind][idx] += 1
        total += 1
        v = s.get("verdict", "unknown")
        by_verdict[v] = by_verdict.get(v, 0) + 1
        if v in ("malicious", "suspicious", "breached"):
            threats_found += 1
        lm = s.get("latency_ms") or 0
        if lm > 0:
            latency_total += lm
            latency_count += 1
    return {
        "days": days,
        "labels": labels,
        "qr": by_kind["qr"],
        "url": by_kind["url"],
        "wifi": by_kind["wifi"],
        "breach": by_kind["breach"],
        "ip": by_kind["ip"],
        "call_forward": by_kind["call_forward"],
        "sms": by_kind["sms"],
        "accessibility": by_kind["accessibility"],
        "total": total,
        "threats_found": threats_found,
        "by_verdict": by_verdict,
        "avg_latency_ms": int(latency_total / latency_count) if latency_count else 0,
    }


def _seed_news_if_empty():
    """Drop a few default advisories the first time the server runs so the
    app and admin console aren't empty out of the box."""
    if os.path.exists(NEWS_FILE):
        return
    seed = [
        {
            "id": 1,
            "title": "Beware of fake e-Challan SMS scams in Maharashtra",
            "summary": "Citizens are receiving SMS with links impersonating Maharashtra Traffic Police. Always verify e-Challans on echallan.parivahan.gov.in.",
            "body": "If you receive an SMS claiming an unpaid traffic challan with a payment link, do NOT click it. Open the official portal at https://echallan.parivahan.gov.in/ and verify with your vehicle number. Real challans never use shortened/click-bait URLs.",
            "category": "Phishing",
            "lang": "EN/HI/MR",
            "status": "Published",
            "created": now_iso(),
            "updated": now_iso(),
        },
        {
            "id": 2,
            "title": "Rise in UPI 'collect request' frauds",
            "summary": "Scammers send a 'collect' request disguised as a refund. UPI never requires a PIN to receive money — only to pay.",
            "body": "UPI 'collect requests' look like incoming payments but are actually requests to debit your account. If you didn't initiate the transaction, REJECT the request. No refund or cashback ever requires entering your UPI PIN.",
            "category": "Financial fraud",
            "lang": "EN/HI/MR",
            "status": "Published",
            "created": now_iso(),
            "updated": now_iso(),
        },
        {
            "id": 3,
            "title": "OTP forwarding scam targeting Maharashtra citizens",
            "summary": "Fraudsters convince victims to dial **21*<number># enabling unconditional call forwarding. Disable it via your SIM settings.",
            "body": "If anyone (claiming to be from a bank, telco or 'KYC officer') asks you to dial codes starting with **21*, **62* or **67* — refuse. These are call-forwarding codes that let scammers intercept your OTPs. To check: dial *#21# from your phone; to disable: dial ##002#.",
            "category": "Awareness",
            "lang": "EN/HI/MR",
            "status": "Published",
            "created": now_iso(),
            "updated": now_iso(),
        },
    ]
    _save(NEWS_FILE, seed)


def _next_news_id():
    items = _load(NEWS_FILE)
    return (max((i.get("id", 0) for i in items), default=0) + 1)


# Integrations health check is cached because every refresh hits external
# APIs — VirusTotal's free tier is only 4 requests/minute, and the admin
# dashboard polls every 10 seconds. Without caching the dashboard alone
# blows the quota and the tile flips to HTTP 429.
_integrations_cache = {"data": None, "ts": 0, "ttl": 0}
_integrations_lock = threading.Lock()
INTEGRATIONS_TTL_HEALTHY = 5 * 60  # 5 minutes when all green
INTEGRATIONS_TTL_DEGRADED = 30     # 30s when something is rate-limited/erroring
                                   # so the UI recovers quickly once VT cools off


def _probe_integrations():
    integrations = []
    # VirusTotal: probe /users/{key}. We do NOT go through the user-facing
    # rate limiter here — that would let user scans starve the health probe
    # and keep the tile stuck in "rate-limited". Instead we hit VT directly
    # and let 429 itself tell us if we're throttled (still a "Connected"
    # state from the integration's POV).
    try:
        status, _ = _http_get(
            f"https://www.virustotal.com/api/v3/users/{VT_API_KEY}",
            headers={"x-apikey": VT_API_KEY}, timeout=6,
        )
        integrations.append({
            "name": "VirusTotal", "purpose": "URL / domain / IP reputation",
            "status": "Connected" if status == 200 else f"HTTP {status}",
        })
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            label = "Connected"
        elif e.code == 429:
            label = "Connected (rate-limited)"
        else:
            label = f"HTTP {e.code}"
        integrations.append({"name": "VirusTotal", "purpose": "URL / domain / IP reputation",
                             "status": label})
    except Exception as e:
        integrations.append({"name": "VirusTotal", "purpose": "URL / domain / IP reputation",
                             "status": f"Error: {e.__class__.__name__}"})
    # URLhaus (local cache, no external call here)
    _refresh_urlhaus()
    with _urlhaus_lock:
        size = _urlhaus_cache["count"]
    integrations.append({
        "name": "URLhaus (abuse.ch)", "purpose": "Known-bad URL feed",
        "status": "Connected" if size > 0 else "Unavailable",
        "feed_size": size,
    })
    # XposedOrNot
    try:
        status, _ = _http_get("https://api.xposedornot.com/v1/check-email/no-such-user-xyz@example.test",
                               headers={"User-Agent": "MahaCyberSafe/0.1"}, timeout=6)
        integrations.append({"name": "XposedOrNot", "purpose": "Email breach lookup",
                             "status": "Connected" if status in (200, 404) else f"HTTP {status}"})
    except urllib.error.HTTPError as e:
        integrations.append({"name": "XposedOrNot", "purpose": "Email breach lookup",
                             "status": "Connected" if e.code == 404 else f"HTTP {e.code}"})
    except Exception as e:
        integrations.append({"name": "XposedOrNot", "purpose": "Email breach lookup",
                             "status": f"Error: {e.__class__.__name__}"})
    integrations.append({
        "name": "RSS news feeds", "purpose": "Cyber news ticker",
        "status": "Connected" if _news_cache["items"] else "Refreshing",
        "items": len(_news_cache["items"]),
    })
    return {"integrations": integrations, "checked_at": now_iso()}


def get_integrations_status():
    """Cached wrapper. Healthy results cache for 5 min; degraded results
    (any non-"Connected" status) only cache for 30s so the dashboard reflects
    recovery promptly once a rate-limit window clears."""
    import time
    with _integrations_lock:
        cached = _integrations_cache["data"]
        age = time.time() - _integrations_cache["ts"]
        ttl = _integrations_cache["ttl"]
        if cached and age < ttl:
            return cached
    # Probe outside the lock so concurrent callers don't pile up.
    fresh = _probe_integrations()
    all_healthy = all(
        (i.get("status") or "").startswith("Connected") and
        "rate-limited" not in (i.get("status") or "")
        for i in fresh.get("integrations", [])
    )
    ttl = INTEGRATIONS_TTL_HEALTHY if all_healthy else INTEGRATIONS_TTL_DEGRADED
    with _integrations_lock:
        _integrations_cache["data"] = fresh
        _integrations_cache["ts"] = time.time()
        _integrations_cache["ttl"] = ttl
    return fresh


_VALID_GRIEVANCE_STATUSES = ("Open", "In Progress", "Resolved", "Escalated")
_VALID_GRIEVANCE_CATEGORIES = (
    "Financial Fraud", "Phishing", "Malware", "Account Security",
    "Identity Theft", "Cyberbullying", "Fake Apps", "Other",
)


def _next_grievance_id() -> str:
    year = datetime.now().year
    items = _load(GRIEVANCES_FILE)
    nums = []
    for i in items:
        m = re.match(rf"^G-{year}-(\d+)$", str(i.get("id", "")))
        if m:
            nums.append(int(m.group(1)))
    n = (max(nums) if nums else 0) + 1
    return f"G-{year}-{n:04d}"


# ---------------- Breach check (XposedOrNot) ----------------
def check_breach(email: str):
    email = (email or "").strip()
    if not email or "@" not in email:
        return {"ok": False, "error": "Invalid email"}
    try:
        # XposedOrNot public API — no key required.
        # Returns 404 if no breaches found; 200 with a list otherwise.
        encoded = urllib.parse.quote(email)
        status, body = _http_get(
            f"https://api.xposedornot.com/v1/check-email/{encoded}",
            headers={"User-Agent": "MahaCyberSafe/0.1"},
            timeout=10,
        )
        breaches = []
        if status == 200 and body:
            j = json.loads(body)
            names = (j.get("breaches") or [[]])[0]
            if isinstance(names, list):
                breaches = names
        # If we got names, enrich with details.
        details = []
        if breaches:
            try:
                s2, b2 = _http_get(
                    f"https://api.xposedornot.com/v1/breach-analytics?email={encoded}",
                    headers={"User-Agent": "MahaCyberSafe/0.1"},
                    timeout=12,
                )
                if s2 == 200 and b2:
                    j2 = json.loads(b2)
                    by_name = {b.get("breach"): b for b in (j2.get("ExposedBreaches", {}).get("breaches_details", []) or [])}
                    for n in breaches:
                        d = by_name.get(n, {})
                        details.append({
                            "name": n,
                            "date": d.get("xposed_date") or "",
                            "records": d.get("xposed_records") or 0,
                            "data": d.get("xposed_data") or "",
                            "description": d.get("details") or "",
                            "industry": d.get("industry") or "",
                            "logo": d.get("logo") or "",
                        })
            except Exception as e:
                # Names without details is still useful.
                details = [{"name": n, "date": "", "records": 0, "data": "", "description": "", "industry": "", "logo": ""} for n in breaches]
                print(f"[breach] analytics failed: {e}")
        return {
            "ok": True,
            "email": email,
            "found": bool(breaches),
            "count": len(breaches),
            "breaches": details,
            "source": "XposedOrNot",
        }
    except urllib.error.HTTPError as e:
        if e.code == 404:
            # No breaches found
            return {"ok": True, "email": email, "found": False, "count": 0, "breaches": [], "source": "XposedOrNot"}
        return {"ok": False, "error": f"XposedOrNot HTTP {e.code}"}
    except Exception as e:
        return {"ok": False, "error": str(e)}


# ---------------- URL scanning ----------------
# VT key comes from the VT_API_KEY env var (see .env / .env.example).
# Empty disables URL scanning gracefully.
VT_API_KEY = os.environ.get("VT_API_KEY", "").strip()
GSB_API_KEY = os.environ.get("GSB_API_KEY", "").strip()

# VirusTotal free tier: 4 req/min, 500/day. Keep one request/min in reserve
# for the periodic integrations probe so end-user scans never starve it out.
VT_MAX_REQS_PER_MIN = 3
VT_LOOKUP_TTL_SECONDS = 600  # 10-minute memo for URL/domain lookups
_vt_call_times: list = []           # rolling 60s window of call timestamps
_vt_lookup_cache: dict = {}         # key -> (expires_at, result_tuple)
_vt_rate_lock = threading.Lock()


def _vt_allow_call() -> bool:
    """Token-bucket guard: only allow a VT call if we've made fewer than
    VT_MAX_REQS_PER_MIN in the last 60s. Skips the call entirely otherwise
    so we never trip a 429."""
    import time
    now = time.time()
    with _vt_rate_lock:
        # drop timestamps older than 60s
        cutoff = now - 60
        while _vt_call_times and _vt_call_times[0] < cutoff:
            _vt_call_times.pop(0)
        if len(_vt_call_times) >= VT_MAX_REQS_PER_MIN:
            return False
        _vt_call_times.append(now)
        return True


def _vt_cache_get(key: str):
    import time
    entry = _vt_lookup_cache.get(key)
    if not entry:
        return None
    expires, value = entry
    if expires < time.time():
        _vt_lookup_cache.pop(key, None)
        return None
    return value


def _vt_cache_put(key: str, value):
    import time
    _vt_lookup_cache[key] = (time.time() + VT_LOOKUP_TTL_SECONDS, value)
    # Bound cache size — drop oldest if it grows past 2k entries.
    if len(_vt_lookup_cache) > 2000:
        oldest = min(_vt_lookup_cache.items(), key=lambda kv: kv[1][0])[0]
        _vt_lookup_cache.pop(oldest, None)

SHORTENERS = {
    "bit.ly", "tinyurl.com", "t.co", "goo.gl", "is.gd", "rb.gy",
    "shorturl.at", "cutt.ly", "ow.ly", "buff.ly",
}
SUSPICIOUS_TLDS = (".zip", ".mov", ".country", ".click", ".gq", ".tk", ".cf", ".ml", ".work")
BRAND_KEYWORDS = (
    "paytm", "phonepe", "sbi", "hdfc", "icici", "aadhaar", "uidai",
    "irctc", "pmkisan", "kyc",
)


def heuristic(uri: urllib.parse.ParseResult):
    reasons = []
    host = (uri.hostname or "").lower()
    if uri.scheme == "http":
        reasons.append("Uses unencrypted HTTP")
    if re.match(r"^\d{1,3}(\.\d{1,3}){3}$", host or ""):
        reasons.append("Host is a raw IP address")
    if host in SHORTENERS or any(host.endswith("." + s) for s in SHORTENERS):
        reasons.append("URL shortener — destination is hidden")
    if any(host.endswith(t) for t in SUSPICIOUS_TLDS):
        reasons.append("Suspicious top-level domain")
    if any(k in host for k in BRAND_KEYWORDS) and not host.endswith(".gov.in"):
        reasons.append("Imitates a well-known Indian brand")
    if "--" in host or any(len(p) > 24 for p in host.split(".")):
        reasons.append("Unusual domain structure (possible typosquatting)")
    qs = urllib.parse.parse_qs(uri.query)
    if any(k.lower() in ("otp", "cvv", "pin") for k in qs):
        reasons.append("Asks for sensitive credentials in URL")
    return reasons


def _http_get(url, headers=None, timeout=6):
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.status, r.read().decode("utf-8", errors="replace")


def _http_post(url, data=None, headers=None, timeout=6, form=False):
    body = urllib.parse.urlencode(data).encode() if form else (data.encode() if isinstance(data, str) else data)
    req = urllib.request.Request(url, data=body, headers=headers or {}, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.status, r.read().decode("utf-8", errors="replace")


# URLhaus public CSV feed (no auth). Refreshed once per hour in-process.
_urlhaus_cache = {"hosts": set(), "urls": set(), "fetched_at": 0, "count": 0}
_urlhaus_lock = threading.Lock()


def _refresh_urlhaus(force=False):
    import time as _t
    now = _t.time()
    if not force and (now - _urlhaus_cache["fetched_at"]) < 3600 and _urlhaus_cache["hosts"]:
        return
    try:
        status, body = _http_get(
            "https://urlhaus.abuse.ch/downloads/csv_recent/",
            timeout=15,
        )
        hosts, urls = set(), set()
        for line in body.splitlines():
            if not line or line.startswith("#"):
                continue
            # id,dateadded,url,url_status,last_online,threat,tags,urlhaus_link,reporter
            parts = line.split(",")
            if len(parts) < 3:
                continue
            u = parts[2].strip('"').strip()
            if not u:
                continue
            urls.add(u.lower())
            try:
                h = urllib.parse.urlparse(u).hostname
                if h:
                    hosts.add(h.lower())
            except Exception:
                pass
        with _urlhaus_lock:
            _urlhaus_cache["hosts"] = hosts
            _urlhaus_cache["urls"] = urls
            _urlhaus_cache["fetched_at"] = now
            _urlhaus_cache["count"] = len(urls)
        print(f"[urlhaus] cached {len(urls)} URLs / {len(hosts)} hosts")
    except Exception as e:
        print(f"[urlhaus] refresh failed: {e}")


# Tiny local demo blocklist — well-known test/fake-evil domains so a tester can
# verify the integration works end-to-end even when a URL isn't on URLhaus.
DEMO_BLOCKLIST = {
    "evil.com",
    "phishing.example.com",
    "malware.example.com",
    "internetbadguys.com",
    "malware.testing.google.test",
    "testsafebrowsing.appspot.com",
}


def check_urlhaus(url: str):
    """abuse.ch URLhaus public CSV feed (no auth)."""
    _refresh_urlhaus()
    try:
        uri = urllib.parse.urlparse(url)
        host = (uri.hostname or "").lower()
        u_low = url.lower()
        with _urlhaus_lock:
            hosts = _urlhaus_cache["hosts"]
            urls = _urlhaus_cache["urls"]
            total = _urlhaus_cache["count"]
        if u_low in urls or host in hosts:
            return {"source": "URLhaus (abuse.ch)", "hit": True, "matched_on": "url" if u_low in urls else "host", "feed_size": total}
        return {"source": "URLhaus (abuse.ch)", "hit": False, "feed_size": total}
    except Exception as e:
        return {"source": "URLhaus (abuse.ch)", "error": str(e)}


def check_demo_blocklist(url: str):
    try:
        host = (urllib.parse.urlparse(url).hostname or "").lower()
        if host in DEMO_BLOCKLIST or any(host.endswith("." + d) for d in DEMO_BLOCKLIST):
            return {"source": "MahaCyber demo blocklist", "hit": True}
        return {"source": "MahaCyber demo blocklist", "hit": False}
    except Exception as e:
        return {"source": "MahaCyber demo blocklist", "error": str(e)}


def _vt_stats(j):
    stats = (j.get("data", {}).get("attributes", {}) or {}).get("last_analysis_stats", {}) or {}
    return {
        "malicious": int(stats.get("malicious", 0)),
        "suspicious": int(stats.get("suspicious", 0)),
        "harmless": int(stats.get("harmless", 0)),
        "undetected": int(stats.get("undetected", 0)),
    }


def _vt_submit_url(url: str):
    """Submit a URL to VirusTotal for analysis. Fire-and-forget so callers
    don't pay the latency cost. The result will be cached at VT for next time."""
    try:
        body = ("url=" + urllib.parse.quote(url, safe="")).encode()
        req = urllib.request.Request(
            "https://www.virustotal.com/api/v3/urls",
            data=body,
            headers={
                "x-apikey": VT_API_KEY,
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "application/json",
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=6) as r:
            r.read()  # discard
    except Exception as e:
        print(f"[vt] submit failed for {url}: {e}")


def _vt_check_url_known(url: str):
    """Look up a URL in VT without submitting. Returns (stats_dict, reputation, found_bool)."""
    cache_key = f"url:{url}"
    cached = _vt_cache_get(cache_key)
    if cached is not None:
        return cached
    if not _vt_allow_call():
        # Don't hit VT — we'd just get 429. Signal "unknown" so the caller
        # falls back to other sources (URLhaus, heuristics).
        return None, 0, False
    url_id = base64.urlsafe_b64encode(url.encode()).decode().rstrip("=")
    try:
        status, body = _http_get(
            f"https://www.virustotal.com/api/v3/urls/{url_id}",
            headers={"x-apikey": VT_API_KEY},
            timeout=8,
        )
    except urllib.error.HTTPError as e:
        if e.code == 404:
            result = (None, 0, False)
            _vt_cache_put(cache_key, result)
            return result
        if e.code == 429:
            return None, 0, False  # don't cache transient rate-limit
        raise
    if status != 200:
        return None, 0, False
    j = json.loads(body)
    stats = _vt_stats(j)
    reputation = int((j.get("data", {}).get("attributes", {}) or {}).get("reputation", 0) or 0)
    result = (stats, reputation, True)
    _vt_cache_put(cache_key, result)
    return result


def _vt_check_domain(host: str):
    """Domain reputation lookup. Works for any domain VT has seen (which is most)."""
    cache_key = f"dom:{host}"
    cached = _vt_cache_get(cache_key)
    if cached is not None:
        return cached
    if not _vt_allow_call():
        return None, 0, False
    try:
        status, body = _http_get(
            f"https://www.virustotal.com/api/v3/domains/{urllib.parse.quote(host)}",
            headers={"x-apikey": VT_API_KEY},
            timeout=8,
        )
    except urllib.error.HTTPError as e:
        if e.code == 404:
            result = (None, 0, False)
            _vt_cache_put(cache_key, result)
            return result
        return None, 0, False
    except Exception:
        return None, 0, False
    if status != 200:
        return None, 0, False
    j = json.loads(body)
    stats = _vt_stats(j)
    reputation = int((j.get("data", {}).get("attributes", {}) or {}).get("reputation", 0) or 0)
    result = (stats, reputation, True)
    _vt_cache_put(cache_key, result)
    return result


def check_virustotal(url: str):
    if not VT_API_KEY:
        return None
    try:
        url_stats, url_rep, url_found = _vt_check_url_known(url)
        # If VT has scanned this exact URL before, use it directly.
        if url_found and url_stats and (url_stats["malicious"] + url_stats["suspicious"] + url_stats["harmless"] + url_stats["undetected"]) > 0:
            return {
                "source": "VirusTotal",
                "scope": "url",
                "hit": (url_stats["malicious"] + url_stats["suspicious"]) > 0,
                **url_stats,
                "reputation": url_rep,
            }

        # Otherwise fall back to domain reputation — fast and almost always present.
        host = (urllib.parse.urlparse(url).hostname or "").lower()
        if host:
            dom_stats, dom_rep, dom_found = _vt_check_domain(host)
            if dom_found and dom_stats:
                # Kick off a URL submission in the background so next time we have URL-specific data.
                try:
                    threading.Thread(target=_vt_submit_url, args=(url,), daemon=True).start()
                except Exception:
                    pass
                return {
                    "source": "VirusTotal",
                    "scope": "domain",
                    "hit": (dom_stats["malicious"] + dom_stats["suspicious"]) > 0,
                    **dom_stats,
                    "reputation": dom_rep,
                    "note": f"domain {host} reputation (URL submitted for next time)",
                }

        # Submit and give up for this request.
        try:
            threading.Thread(target=_vt_submit_url, args=(url,), daemon=True).start()
        except Exception:
            pass
        return {"source": "VirusTotal", "hit": False, "note": "unknown to VT, submitted for analysis"}
    except Exception as e:
        return {"source": "VirusTotal", "error": str(e)}


def check_virustotal_ip(ip: str):
    if not VT_API_KEY:
        return None
    cache_key = f"ip:{ip}"
    cached = _vt_cache_get(cache_key)
    if cached is not None:
        return cached
    if not _vt_allow_call():
        return {"source": "VirusTotal", "error": "rate-limited"}
    try:
        status, body = _http_get(
            f"https://www.virustotal.com/api/v3/ip_addresses/{urllib.parse.quote(ip)}",
            headers={"x-apikey": VT_API_KEY},
            timeout=8,
        )
        if status != 200:
            return {"source": "VirusTotal", "error": f"HTTP {status}"}
        j = json.loads(body)
        stats = _vt_stats(j)
        attr = j.get("data", {}).get("attributes", {}) or {}
        result = {
            "source": "VirusTotal",
            "ip": ip,
            "hit": (stats["malicious"] + stats["suspicious"]) > 0,
            **stats,
            "reputation": int(attr.get("reputation", 0) or 0),
            "country": attr.get("country") or "",
            "as_owner": attr.get("as_owner") or "",
        }
        _vt_cache_put(cache_key, result)
        return result
    except Exception as e:
        return {"source": "VirusTotal", "error": str(e)}


def check_gsb(url: str):
    if not GSB_API_KEY:
        return None
    try:
        payload = {
            "client": {"clientId": "mahacyber-safe", "clientVersion": "0.1.0"},
            "threatInfo": {
                "threatTypes": [
                    "MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE",
                    "POTENTIALLY_HARMFUL_APPLICATION",
                ],
                "platformTypes": ["ANY_PLATFORM"],
                "threatEntryTypes": ["URL"],
                "threatEntries": [{"url": url}],
            },
        }
        api = f"https://safebrowsing.googleapis.com/v4/threatMatches:find?key={GSB_API_KEY}"
        status, body = _http_post(
            api,
            data=json.dumps(payload),
            headers={"Content-Type": "application/json"},
            timeout=8,
        )
        j = json.loads(body) if body else {}
        matches = j.get("matches", [])
        return {
            "source": "Google Safe Browsing",
            "hit": bool(matches),
            "matches": [m.get("threatType") for m in matches],
        }
    except Exception as e:
        return {"source": "Google Safe Browsing", "error": str(e)}


def scan_url(raw: str):
    raw = (raw or "").strip()
    if not raw:
        return {"verdict": "suspicious", "reasons": ["Empty input"], "sources": [], "normalised": ""}
    with_scheme = raw if "://" in raw else "https://" + raw
    try:
        uri = urllib.parse.urlparse(with_scheme)
    except Exception:
        return {"verdict": "suspicious", "reasons": ["Could not parse URL"], "sources": [], "normalised": raw}

    sources = []
    hits = 0
    reasons = heuristic(uri)

    demo = check_demo_blocklist(with_scheme)
    sources.append(demo)
    if demo.get("hit"):
        hits += 3
        reasons.append("Listed on MahaCyber demo blocklist (test/fake-evil domain)")

    uh = check_urlhaus(with_scheme)
    if uh:
        sources.append(uh)
        if uh.get("hit"):
            hits += 3
            reasons.append(f"Listed on URLhaus blocklist (matched: {uh.get('matched_on')})")

    vt = check_virustotal(with_scheme)
    if vt:
        sources.append(vt)
        if vt.get("hit"):
            hits += 2
            reasons.append(f"VirusTotal flags: {vt.get('malicious',0)} malicious / {vt.get('suspicious',0)} suspicious")

    gsb = check_gsb(with_scheme)
    if gsb:
        sources.append(gsb)
        if gsb.get("hit"):
            hits += 3
            reasons.append("Google Safe Browsing: " + ", ".join(gsb.get("matches", [])))

    if hits >= 2:
        verdict = "malicious"
    elif hits == 1 or len(reasons) >= 3:
        verdict = "malicious"
    elif reasons:
        verdict = "suspicious"
    else:
        verdict = "safe"

    return {
        "verdict": verdict,
        "reasons": reasons,
        "sources": sources,
        "normalised": with_scheme,
    }


# ---------------- SMS fraud inspector ----------------
# Keyword heuristics for common Indian SMS fraud patterns (EN/HI/MR).
# Score weights: high-confidence fraud markers get higher weights.
_SMS_KEYWORDS = [
    # OTP/credential phishing
    (r"\botp\b", 2, "Mentions OTP — legitimate institutions never ask for OTPs over SMS"),
    (r"\b(pin|password|cvv|atm pin)\b", 3, "Asks for PIN / password / CVV"),
    (r"share.{0,15}(otp|pin|code|password)", 4, "Asks you to share an OTP / PIN / password"),
    (r"\bkyc\b", 2, "Mentions KYC — frequent pretext for credential theft"),
    (r"verify.{0,20}(account|aadhaar|pan|kyc|bank)", 3, "Asks to 'verify' an account or document"),
    # Banking lures
    (r"\b(account|a/c|acc).{0,15}(block|suspend|frozen|deactivat)", 3, "Threatens account block / suspension"),
    (r"(bank|card).{0,20}(block|deactivat|expire|suspend)", 3, "Threatens card/bank block or expiry"),
    (r"\b(?:re(?:credit|fund)|cashback)\b.*\b(?:click|link)", 2, "Refund/cashback prompt with a link"),
    # Reward/lottery
    (r"\b(?:won|winner|prize|lottery|lucky draw|gift)\b", 2, "Lottery / prize lure"),
    (r"(?:rs\.?|inr|₹)\s?\d{3,}", 1, "Mentions a large rupee amount"),
    # Job / Loan / Investment scams
    (r"work from home|part.?time job|earn .{0,15}per day|daily income", 3, "Work-from-home / quick-earnings lure"),
    (r"instant loan|pre.?approved loan|loan approved", 2, "Instant / pre-approved loan offer"),
    (r"crypto|bitcoin|usdt|trading signal", 2, "Crypto / trading signal pitch"),
    # Delivery / parcel
    (r"parcel.{0,20}(hold|stuck|customs|undelivered|address)", 3, "Fake parcel / delivery problem"),
    (r"(india post|fedex|dhl|blue dart|dtdc).{0,40}(hold|verify|address)", 3, "Impersonates a courier"),
    # Action prompts
    (r"click.{0,10}(here|link|below)", 2, "Urges you to click a link"),
    (r"(call|dial).{0,15}(\+?\d[\d\s\-]{6,})", 2, "Asks you to call a number"),
    (r"urgent|immediately|within \d+ ?(hour|minute|day)|expires? (today|soon)", 2, "Creates urgency / deadline"),
    (r"forward (this )?(to|sms)", 2, "Asks you to forward the message"),
    # Hindi / Marathi (Devanagari) — common scam phrases
    (r"\bOTP\b|ओटीपी", 2, "Mentions OTP"),
    (r"खाता.{0,15}(बंद|ब्लॉक)", 3, "Threatens to block your account (Hindi)"),
    (r"खाते.{0,15}(बंद|ब्लॉक)", 3, "Threatens to block your account (Marathi)"),
    (r"लॉटरी|इनाम|बम्पर", 2, "Lottery / prize lure (Hindi/Marathi)"),
    (r"लिंक पर क्लिक|लिंकवर क्लिक", 3, "Asks to click a link (Hindi/Marathi)"),
]

# Sender-ID patterns: legit Indian transactional SMS uses 6-char headers like
# VK-HDFCBK / AX-SBIINB. Personal 10-digit numbers in this context = suspect.
_SMS_SENDER_LEGIT_RE = re.compile(r"^[A-Z]{2}-[A-Z0-9]{4,8}$")


def _extract_sms_urls(text: str):
    """Pull http(s) URLs (and bare-domain phishing lookalikes) from SMS body."""
    if not text:
        return []
    urls = re.findall(r"https?://[^\s<>\"\)\]]+", text, re.IGNORECASE)
    if not urls:
        # bare domain fallback
        m = re.findall(
            r"(?:^|\s)((?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}(?:/[^\s]*)?)",
            text, re.IGNORECASE,
        )
        urls = ["http://" + u for u in m]
    # de-dupe preserving order, cap at 5
    seen, out = set(), []
    for u in urls:
        if u in seen:
            continue
        seen.add(u)
        out.append(u)
        if len(out) >= 5:
            break
    return out


def scan_sms(text: str, sender: str = ""):
    text = (text or "").strip()
    if not text:
        return {"verdict": "suspicious", "reasons": ["Empty SMS"], "urls": [], "sender": sender}
    body = text[:1500]  # cap; SMS is small anyway
    reasons = []
    score = 0
    for pattern, weight, why in _SMS_KEYWORDS:
        if re.search(pattern, body, re.IGNORECASE):
            score += weight
            reasons.append(why)

    # Sender-ID check
    sender = (sender or "").strip()
    if sender:
        if re.match(r"^\+?\d{10,13}$", sender):
            score += 2
            reasons.append("Sender is a personal phone number — banks/telcos use header IDs (e.g. VK-HDFCBK)")
        elif not _SMS_SENDER_LEGIT_RE.match(sender) and not sender.isdigit():
            # Header didn't match the standard 2-letter dash + 4-8 alnum format.
            pass

    # Extract URLs and check each via the existing pipeline
    extracted = _extract_sms_urls(body)
    url_results = []
    worst = "safe"
    rank = {"safe": 0, "suspicious": 1, "malicious": 2}
    for u in extracted:
        try:
            r = scan_url(u)
            v = r.get("verdict", "suspicious")
            url_results.append({
                "url": u,
                "verdict": v,
                "reasons": r.get("reasons", []),
            })
            if rank.get(v, 0) > rank.get(worst, 0):
                worst = v
            if v == "malicious":
                score += 4
                reasons.append(f"Embedded URL is malicious: {u}")
            elif v == "suspicious":
                score += 2
                reasons.append(f"Embedded URL is suspicious: {u}")
        except Exception as e:
            url_results.append({"url": u, "verdict": "unknown", "reasons": [f"Lookup error: {e}"]})

    # Final verdict
    if score >= 6 or worst == "malicious":
        verdict = "malicious"
    elif score >= 3 or worst == "suspicious":
        verdict = "suspicious"
    else:
        verdict = "safe"

    # de-dupe reasons preserving order
    seen, dedup = set(), []
    for r in reasons:
        if r not in seen:
            seen.add(r)
            dedup.append(r)

    return {
        "verdict": verdict,
        "reasons": dedup,
        "urls": url_results,
        "sender": sender,
        "score": score,
    }


# ---------------- Cyber news RSS feeds ----------------
RSS_FEEDS = [
    ("The Hacker News", "https://feeds.feedburner.com/TheHackersNews"),
    ("BleepingComputer", "https://www.bleepingcomputer.com/feed/"),
    ("Krebs on Security", "https://krebsonsecurity.com/feed/"),
]

_news_cache = {"items": [], "fetched_at": 0}
_news_lock = threading.Lock()
NEWS_TTL_SECONDS = 6 * 3600  # 6 hours


def _strip_html(s: str) -> str:
    if not s:
        return ""
    # crude tag stripper — sufficient for RSS descriptions
    s = re.sub(r"<[^>]+>", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    # decode a few common entities
    return (
        s.replace("&nbsp;", " ").replace("&amp;", "&")
         .replace("&quot;", '"').replace("&#39;", "'")
         .replace("&lt;", "<").replace("&gt;", ">")
    )


def _parse_rss_date(s: str) -> str:
    if not s:
        return ""
    try:
        dt = parsedate_to_datetime(s)
        return dt.strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        return s


def _fetch_rss(name: str, url: str):
    try:
        req = urllib.request.Request(
            url,
            headers={
                "User-Agent": "Mozilla/5.0 (MahaCyberSafe/0.1; +https://maharashtracyber.gov.in)",
                "Accept": "application/rss+xml, application/xml, text/xml, */*",
            },
        )
        with urllib.request.urlopen(req, timeout=12) as r:
            data = r.read()
        root = ET.fromstring(data)
        # Both RSS 2.0 (channel/item) and Atom (feed/entry); we focus on RSS 2.0 since all feeds we use are RSS.
        items = []
        for it in root.iter("item"):
            title = (it.findtext("title") or "").strip()
            link = (it.findtext("link") or "").strip()
            desc = _strip_html(it.findtext("description") or "")
            pub = _parse_rss_date(it.findtext("pubDate") or "")
            cats = [c.text for c in it.findall("category") if c is not None and c.text]
            if not title:
                continue
            items.append({
                "title": title[:300],
                "summary": desc[:400],
                "link": link,
                "published": pub,
                "category": (cats[0] if cats else "Cyber news")[:60],
                "source": name,
            })
            if len(items) >= 15:
                break
        return items
    except Exception as e:
        print(f"[news] {name} feed failed: {e}")
        return []


def _refresh_news(force=False):
    import time as _t
    now = _t.time()
    if not force and (now - _news_cache["fetched_at"]) < NEWS_TTL_SECONDS and _news_cache["items"]:
        return
    merged = []
    for name, url in RSS_FEEDS:
        merged.extend(_fetch_rss(name, url))
    # newest first
    merged.sort(key=lambda x: x.get("published") or "", reverse=True)
    merged = merged[:60]
    with _news_lock:
        _news_cache["items"] = merged
        _news_cache["fetched_at"] = now
    print(f"[news] cached {len(merged)} items from {len(RSS_FEEDS)} feeds")


def _news_kickoff_background():
    """Refresh once at startup, then every NEWS_TTL_SECONDS in a daemon thread."""
    def _loop():
        import time as _t
        while True:
            try:
                _refresh_news(force=True)
            except Exception as e:
                print(f"[news] refresh loop error: {e}")
            _t.sleep(NEWS_TTL_SECONDS)
    t = threading.Thread(target=_loop, daemon=True)
    t.start()


def get_news_feed():
    """Return a combined payload: advisories (pinned on top) + RSS items."""
    with _lock:
        advisories = [n for n in _load(NEWS_FILE) if n.get("status") == "Published"]
    # advisories newest-first
    advisories.sort(key=lambda x: x.get("updated") or x.get("created") or "", reverse=True)
    _refresh_news()  # lazy refresh in case background hasn't yet
    with _news_lock:
        items = list(_news_cache["items"])
        fetched_at = _news_cache["fetched_at"]
    return {
        "advisories": advisories,
        "news": items,
        "news_fetched_at": datetime.fromtimestamp(fetched_at).strftime("%Y-%m-%d %H:%M:%S") if fetched_at else "",
        "news_sources": [n for n, _ in RSS_FEEDS],
    }


class Handler(SimpleHTTPRequestHandler):
    # Serve static files from the project root
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    # ---------------- helpers ----------------
    def _json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,PATCH,DELETE,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(body)

    def _client_ip(self):
        # Honor X-Forwarded-For if a reverse proxy is in front; else peer.
        fwd = self.headers.get("X-Forwarded-For", "").split(",")[0].strip()
        return fwd or self.client_address[0]

    def _read_body(self):
        length = int(self.headers.get("Content-Length", "0"))
        if not length:
            return {}
        raw = self.rfile.read(length)
        try:
            return json.loads(raw.decode())
        except Exception:
            return {}

    def end_headers(self):
        # CORS for all static responses too (admin console fetches from same origin anyway,
        # but this lets you open admin_console/index.html via file:// during dev).
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def log_message(self, fmt, *args):
        # Slimmer log
        print(f"[{self.log_date_time_string()}] {self.address_string()} - {fmt % args}")

    # ---------------- routing ----------------
    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,PATCH,DELETE,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/api/health":
            return self._json(200, {"ok": True, "time": now_iso()})
        if path == "/api/integrations":
            return self._json(200, get_integrations_status())
        if path == "/api/devices":
            with _lock:
                return self._json(200, _load(DEVICES_FILE))
        if path == "/api/threats":
            with _lock:
                return self._json(200, _load(THREATS_FILE))
        if path == "/api/sos":
            with _lock:
                return self._json(200, _load(INCIDENTS_FILE))
        if path == "/api/news":
            qs = urllib.parse.parse_qs(urlparse(self.path).query)
            published_only = qs.get("published", ["false"])[0].lower() == "true"
            with _lock:
                items = _load(NEWS_FILE)
            if published_only:
                items = [n for n in items if n.get("status") == "Published"]
            return self._json(200, items)
        if path == "/api/news/feed":
            return self._json(200, get_news_feed())
        if path == "/api/audit":
            qs = urllib.parse.parse_qs(urlparse(self.path).query)
            try:
                limit = min(int(qs.get("limit", ["500"])[0]), 5000)
            except Exception:
                limit = 500
            with _lock:
                items = _load(AUDIT_FILE)[:limit]
            return self._json(200, items)
        if path == "/api/grievances":
            qs = urllib.parse.parse_qs(urlparse(self.path).query)
            device_id = qs.get("deviceId", [""])[0]
            with _lock:
                items = _load(GRIEVANCES_FILE)
            if device_id:
                items = [g for g in items if g.get("deviceId") == device_id]
            return self._json(200, items)
        if path == "/api/scans":
            qs = urllib.parse.parse_qs(urlparse(self.path).query)
            try:
                limit = min(int(qs.get("limit", ["500"])[0]), 5000)
            except Exception:
                limit = 500
            with _lock:
                items = _load(SCANS_FILE)[:limit]
            return self._json(200, items)
        if path == "/api/scans/summary":
            qs = urllib.parse.parse_qs(urlparse(self.path).query)
            try:
                days = int(qs.get("days", ["7"])[0])
            except Exception:
                days = 7
            return self._json(200, scans_summary(days))
        return super().do_GET()

    def do_POST(self):
        path = urlparse(self.path).path

        if path == "/api/devices/register":
            body = self._read_body()
            device_id = body.get("deviceId")
            if not device_id:
                return self._json(400, {"error": "deviceId required"})
            entry = {
                "id": device_id,
                "citizen": body.get("citizen") or f"citizen_{device_id[-6:].lower()}",
                "model": body.get("model", "Unknown"),
                "os": body.get("os", "Unknown"),
                "appVer": body.get("appVer", "0.0.0"),
                "registered": body.get("registered") or now_iso(),
                "lastSeen": now_iso(),
                "rasp": body.get("rasp", "clean"),
                "status": body.get("status", "Active"),
                "location": body.get("location", "Unknown"),
            }
            with _lock:
                devices = _load(DEVICES_FILE)
                existing = next((d for d in devices if d["id"] == device_id), None)
                is_new = existing is None
                if existing:
                    entry["registered"] = existing.get("registered", entry["registered"])
                    existing.update(entry)
                else:
                    devices.append(entry)
                _save(DEVICES_FILE, devices)
            if is_new:
                audit_log(
                    action="DEVICE_REGISTER",
                    user=entry.get("citizen") or "anonymous",
                    ip=self._client_ip(),
                    detail=f"{entry['id']} · {entry.get('model','')} · {entry.get('os','')}",
                )
            return self._json(200, {"ok": True, "device": entry})

        if path == "/api/threats":
            body = self._read_body()
            device_id = body.get("deviceId")
            if not device_id:
                return self._json(400, {"error": "deviceId required"})
            evt = {
                "id": int(datetime.now().timestamp() * 1000),
                "user": body.get("citizen") or f"citizen_{device_id[-6:].lower()}",
                "deviceId": device_id,
                "type": body.get("type", "Unknown"),
                "severity": body.get("severity", "low"),
                "timestamp": now_iso(),
                "device": body.get("model", "Unknown"),
                "resolved": False,
            }
            highest = body.get("severity", "clean")
            with _lock:
                threats = _load(THREATS_FILE)
                threats.insert(0, evt)
                threats = threats[:500]  # cap
                _save(THREATS_FILE, threats)

                # Update the device's RASP status to the worst-known severity
                devices = _load(DEVICES_FILE)
                d = next((x for x in devices if x["id"] == device_id), None)
                if d:
                    order = ["clean", "low", "medium", "high", "critical"]
                    cur = d.get("rasp", "clean")
                    if order.index(highest) > order.index(cur):
                        d["rasp"] = highest
                    if highest in ("high", "critical"):
                        d["status"] = "Flagged"
                    d["lastSeen"] = now_iso()
                    _save(DEVICES_FILE, devices)
            audit_log(
                action="THREAT_REPORTED",
                user=evt.get("user") or "anonymous",
                ip=self._client_ip(),
                detail=f"{evt['type']} ({evt['severity']}) on {evt.get('device','')}",
            )
            return self._json(200, {"ok": True, "event": evt})

        if path == "/api/scan/url":
            body = self._read_body()
            target = body.get("url", "")
            t0 = datetime.now()
            result = scan_url(target)
            latency = int((datetime.now() - t0).total_seconds() * 1000)
            # Skip auto-logging if the caller will record explicitly (e.g. QR
            # scanner records as kind=qr after analysing the decoded URL).
            if not body.get("noLog"):
                kind = body.get("kind") or "url"
                record_scan(
                    kind=kind if kind in _VALID_SCAN_KINDS else "url",
                    verdict=result.get("verdict", "unknown"),
                    target=target,
                    device_id=body.get("deviceId", ""),
                    citizen=body.get("citizen", ""),
                    latency_ms=latency,
                    ip=self._client_ip(),
                )
            return self._json(200, result)

        if path == "/api/scan/sms":
            body = self._read_body()
            text = (body.get("text") or "").strip()
            sender = (body.get("sender") or "").strip()
            if not text:
                return self._json(400, {"error": "sms text is required"})
            t0 = datetime.now()
            result = scan_sms(text, sender=sender)
            latency = int((datetime.now() - t0).total_seconds() * 1000)
            # Truncated target so the admin sees the gist without storing whole body.
            target_preview = (sender + " | " if sender else "") + text[:120]
            record_scan(
                kind="sms",
                verdict=result.get("verdict", "unknown"),
                target=target_preview,
                device_id=body.get("deviceId", ""),
                citizen=body.get("citizen", ""),
                latency_ms=latency,
                ip=self._client_ip(),
            )
            return self._json(200, result)

        if path == "/api/scan/ip":
            body = self._read_body()
            ip = (body.get("ip") or "").strip()
            if not re.match(r"^\d{1,3}(\.\d{1,3}){3}$", ip):
                return self._json(400, {"error": "valid IPv4 required"})
            t0 = datetime.now()
            result = check_virustotal_ip(ip) or {"error": "VT disabled"}
            latency = int((datetime.now() - t0).total_seconds() * 1000)
            if "error" not in result:
                record_scan(
                    kind="ip",
                    verdict="malicious" if result.get("hit") else "clean",
                    target=ip,
                    device_id=body.get("deviceId", ""),
                    citizen=body.get("citizen", ""),
                    latency_ms=latency,
                    ip=self._client_ip(),
                )
            return self._json(200, result)

        if path == "/api/scans":
            body = self._read_body()
            entry = record_scan(
                kind=body.get("kind", ""),
                verdict=body.get("verdict", "unknown"),
                target=body.get("target", ""),
                device_id=body.get("deviceId", ""),
                citizen=body.get("citizen", ""),
                latency_ms=body.get("latency_ms", 0),
                ip=self._client_ip(),
            )
            if entry is None:
                return self._json(400, {"error": "invalid kind"})
            return self._json(200, {"ok": True, "entry": entry})

        if path == "/api/sos":
            body = self._read_body()
            device_id = body.get("deviceId") or ""
            lat = body.get("lat")
            lng = body.get("lng")
            if lat is None or lng is None:
                return self._json(400, {"error": "lat/lng required"})
            incident = {
                "id": int(datetime.now().timestamp() * 1000),
                "deviceId": device_id,
                "citizen": body.get("citizen") or (f"citizen_{device_id[-6:].lower()}" if device_id else "anonymous"),
                "lat": float(lat),
                "lng": float(lng),
                "accuracy": float(body.get("accuracy") or 0),
                "message": (body.get("message") or "").strip()[:500],
                "model": body.get("model", "Unknown"),
                "os": body.get("os", "Unknown"),
                "appVer": body.get("appVer", ""),
                "timestamp": now_iso(),
                "status": "Open",
            }
            with _lock:
                items = _load(INCIDENTS_FILE)
                items.insert(0, incident)
                items = items[:1000]
                _save(INCIDENTS_FILE, items)
            audit_log(
                action="SOS_TRIGGERED",
                user=incident.get("citizen") or "anonymous",
                ip=self._client_ip(),
                detail=f"#{incident['id']} at {incident['lat']:.5f},{incident['lng']:.5f} (±{incident['accuracy']:.0f}m)",
            )
            return self._json(200, {"ok": True, "incident": incident})

        if path == "/api/news":
            body = self._read_body()
            title = (body.get("title") or "").strip()
            if not title:
                return self._json(400, {"error": "title required"})
            entry = {
                "id": _next_news_id(),
                "title": title[:200],
                "summary": (body.get("summary") or "").strip()[:500],
                "body": (body.get("body") or "").strip()[:8000],
                "category": (body.get("category") or "Advisory").strip()[:60],
                "lang": (body.get("lang") or "EN").strip()[:20],
                "status": body.get("status") if body.get("status") in ("Draft", "Pending Approval", "Published") else "Draft",
                "created": now_iso(),
                "updated": now_iso(),
            }
            with _lock:
                items = _load(NEWS_FILE)
                items.insert(0, entry)
                _save(NEWS_FILE, items)
            audit_log(
                action="NEWS_CREATE",
                user="admin",
                ip=self._client_ip(),
                detail=f"#{entry['id']} · {entry['status']} · {entry['title'][:60]}",
            )
            return self._json(200, {"ok": True, "item": entry})

        if path == "/api/breach":
            body = self._read_body()
            t0 = datetime.now()
            result = check_breach(body.get("email", ""))
            latency = int((datetime.now() - t0).total_seconds() * 1000)
            breach_count = len((result or {}).get("breaches") or [])
            record_scan(
                kind="breach",
                verdict="breached" if breach_count > 0 else "clean",
                target=(body.get("email") or "")[:120],
                device_id=body.get("deviceId", ""),
                citizen=body.get("citizen", ""),
                latency_ms=latency,
                ip=self._client_ip(),
            )
            return self._json(200, result)

        if path == "/api/audit":
            body = self._read_body()
            action = (body.get("action") or "").strip()
            if not action:
                return self._json(400, {"error": "action required"})
            entry = audit_log(
                action=action[:80],
                user=(body.get("user") or "admin")[:80],
                ip=self._client_ip(),
                detail=(body.get("detail") or "")[:300],
            )
            return self._json(200, {"ok": True, "entry": entry})

        if path == "/api/grievances":
            body = self._read_body()
            subject = (body.get("subject") or "").strip()
            desc = (body.get("description") or "").strip()
            if not subject:
                return self._json(400, {"error": "subject required"})
            if not desc:
                return self._json(400, {"error": "description required"})
            category = (body.get("category") or "Other").strip()
            if category not in _VALID_GRIEVANCE_CATEGORIES:
                category = "Other"
            device_id = (body.get("deviceId") or "").strip()
            citizen = (body.get("citizen") or "").strip() or (
                f"citizen_{device_id[-6:].lower()}" if device_id else "anonymous"
            )
            entry = {
                "id": _next_grievance_id(),
                "citizen": citizen[:80],
                "contact": (body.get("contact") or "").strip()[:120],
                "subject": subject[:200],
                "category": category,
                "description": desc[:4000],
                "deviceId": device_id,
                "model": (body.get("model") or "").strip()[:80],
                "os": (body.get("os") or "").strip()[:40],
                "appVer": (body.get("appVer") or "").strip()[:20],
                "status": "Open",
                "adminNote": "",
                "date": now_iso()[:10],
                "created": now_iso(),
                "updated": now_iso(),
            }
            with _lock:
                items = _load(GRIEVANCES_FILE)
                items.insert(0, entry)
                items = items[:2000]
                _save(GRIEVANCES_FILE, items)
            audit_log(
                action="GRIEVANCE_CREATE",
                user=citizen,
                ip=self._client_ip(),
                detail=f"{entry['id']} · {category} · {subject[:60]}",
            )
            return self._json(200, {"ok": True, "item": entry})

        if path == "/api/wipe":
            with _lock:
                _save(DEVICES_FILE, [])
                _save(THREATS_FILE, [])
                _save(INCIDENTS_FILE, [])
                _save(SCANS_FILE, [])
                _save(GRIEVANCES_FILE, [])
            audit_log(action="WIPE_ALL", user="admin", ip=self._client_ip(),
                      detail="Cleared all devices, threats and SOS incidents")
            return self._json(200, {"ok": True})

        self._json(404, {"error": "not found"})

    def do_PATCH(self):
        path = urlparse(self.path).path
        m = re.match(r"^/api/news/(\d+)$", path)
        if m:
            target = int(m.group(1))
            body = self._read_body()
            allowed = ("title", "summary", "body", "category", "lang", "status")
            with _lock:
                items = _load(NEWS_FILE)
                it = next((x for x in items if x.get("id") == target), None)
                if not it:
                    return self._json(404, {"error": "not found"})
                changed = []
                for k in allowed:
                    if k in body and body[k] is not None:
                        if it.get(k) != body[k]:
                            changed.append(k)
                        it[k] = body[k]
                it["updated"] = now_iso()
                _save(NEWS_FILE, items)
            audit_log(
                action="NEWS_PUBLISH" if "status" in changed and it.get("status") == "Published" else "NEWS_UPDATE",
                user="admin",
                ip=self._client_ip(),
                detail=f"#{target} · changed: {','.join(changed) or 'none'}",
            )
            return self._json(200, {"ok": True, "item": it})

        m = re.match(r"^/api/grievances/(G-\d{4}-\d{4})$", path)
        if m:
            target = m.group(1)
            body = self._read_body()
            new_status = body.get("status")
            note = body.get("adminNote")
            if new_status is not None and new_status not in _VALID_GRIEVANCE_STATUSES:
                return self._json(400, {"error": "invalid status"})
            with _lock:
                items = _load(GRIEVANCES_FILE)
                it = next((x for x in items if x.get("id") == target), None)
                if not it:
                    return self._json(404, {"error": "not found"})
                if new_status is not None:
                    it["status"] = new_status
                if note is not None:
                    it["adminNote"] = str(note)[:1000]
                it["updated"] = now_iso()
                _save(GRIEVANCES_FILE, items)
            audit_log(
                action=f"GRIEVANCE_{(new_status or 'UPDATE').upper().replace(' ','_')}",
                user="admin",
                ip=self._client_ip(),
                detail=f"{target} → {new_status or 'note updated'}",
            )
            return self._json(200, {"ok": True, "item": it})

        m = re.match(r"^/api/sos/(\d+)$", path)
        if m:
            target = int(m.group(1))
            body = self._read_body()
            new_status = body.get("status")
            if new_status not in ("Open", "Acknowledged", "Resolved"):
                return self._json(400, {"error": "invalid status"})
            with _lock:
                items = _load(INCIDENTS_FILE)
                found = False
                for it in items:
                    if it.get("id") == target:
                        it["status"] = new_status
                        it["updated"] = now_iso()
                        found = True
                        break
                if not found:
                    return self._json(404, {"error": "not found"})
                _save(INCIDENTS_FILE, items)
            audit_log(
                action=f"SOS_{new_status.upper()}",
                user="admin",
                ip=self._client_ip(),
                detail=f"Incident #{target} → {new_status}",
            )
            return self._json(200, {"ok": True})
        return self._json(404, {"error": "not found"})

    def do_DELETE(self):
        path = urlparse(self.path).path
        m = re.match(r"^/api/devices/([^/]+)$", path)
        if m:
            target = m.group(1)
            with _lock:
                devices = _load(DEVICES_FILE)
                devices = [d for d in devices if d["id"] != target]
                _save(DEVICES_FILE, devices)
            audit_log(
                action="DEVICE_DELETE",
                user="admin",
                ip=self._client_ip(),
                detail=f"Removed {target}",
            )
            return self._json(200, {"ok": True})
        m = re.match(r"^/api/news/(\d+)$", path)
        if m:
            target = int(m.group(1))
            with _lock:
                items = _load(NEWS_FILE)
                items = [x for x in items if x.get("id") != target]
                _save(NEWS_FILE, items)
            audit_log(action="NEWS_DELETE", user="admin", ip=self._client_ip(), detail=f"Deleted advisory #{target}")
            return self._json(200, {"ok": True})
        self._json(404, {"error": "not found"})


class ThreadedHTTPServer(HTTPServer):
    """Threaded so multiple device POSTs don't block each other."""
    daemon_threads = True

    def process_request(self, request, client_address):
        threading.Thread(target=self._handle, args=(request, client_address), daemon=True).start()

    def _handle(self, request, client_address):
        try:
            self.finish_request(request, client_address)
        finally:
            self.shutdown_request(request)


if __name__ == "__main__":
    _seed_news_if_empty()
    _news_kickoff_background()
    port = int(os.environ.get("PORT", "8000"))
    bind = os.environ.get("BIND", "0.0.0.0")
    server = ThreadedHTTPServer((bind, port), Handler)
    print(f"MahaCyber Safe server: http://{bind}:{port}/")
    print(f"  Static root : {ROOT}")
    print(f"  Data dir    : {DATA_DIR}")
    print(f"  API         : /api/devices, /api/threats, /api/health")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
