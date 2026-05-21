/// Classifies a Wi-Fi access point from its `capabilities` string and flags
/// session-level threats like evil-twin / unchanged-factory SSID.
///
/// Android's `WifiManager.getScanResults()` returns each AP's `capabilities`
/// as a bracketed string, e.g.:
///   "[WPA2-PSK-CCMP][WPS][ESS]"
///   "[WPA-PSK-CCMP+TKIP][WPA2-PSK-CCMP+TKIP][ESS]"
///   "[WEP][ESS]"
///   "[ESS]"          ← open
///   "[WPA3-SAE+FT/SAE-CCMP][ESS]"
library;

enum WifiEncryption { open, wep, wpa, wpa2, wpa3, unknown }
enum WifiRisk { low, medium, high, unknown }

class WifiClassification {
  WifiClassification({
    required this.encryption,
    required this.risk,
    required this.label,
    required this.shortBadge,
    required this.reason,
  });
  final WifiEncryption encryption;
  final WifiRisk risk;
  final String label;       // human-readable e.g. "WPA2 (Personal)"
  final String shortBadge;  // for chip — "WPA2"
  final String reason;
}

class WifiRiskService {
  /// Map capabilities → classification.
  static WifiClassification classify(String capabilities) {
    final c = capabilities.toUpperCase();
    // WPA3 first (string also contains "WPA" so must be checked first)
    if (c.contains('WPA3') || c.contains('SAE')) {
      return WifiClassification(
        encryption: WifiEncryption.wpa3,
        risk: WifiRisk.low,
        label: 'WPA3',
        shortBadge: 'WPA3',
        reason: 'Modern, strong encryption.',
      );
    }
    if (c.contains('WPA2')) {
      return WifiClassification(
        encryption: WifiEncryption.wpa2,
        risk: WifiRisk.low,
        label: 'WPA2',
        shortBadge: 'WPA2',
        reason: 'Standard secure encryption.',
      );
    }
    if (c.contains('WPA-')) {
      return WifiClassification(
        encryption: WifiEncryption.wpa,
        risk: WifiRisk.medium,
        label: 'WPA (legacy)',
        shortBadge: 'WPA',
        reason: 'WPA1 is outdated and crackable in some configurations.',
      );
    }
    if (c.contains('WEP')) {
      return WifiClassification(
        encryption: WifiEncryption.wep,
        risk: WifiRisk.high,
        label: 'WEP (insecure)',
        shortBadge: 'WEP',
        reason: 'WEP can be broken in minutes. Avoid this network.',
      );
    }
    // No encryption tag → open
    // "[ESS]" alone or "[WPS][ESS]" → open
    final hasAuthTag = RegExp(r'\[(WPA|WEP|SAE|RSN|IEEE8021X|PSK|EAP)').hasMatch(c);
    if (!hasAuthTag) {
      return WifiClassification(
        encryption: WifiEncryption.open,
        risk: WifiRisk.high,
        label: 'Open (no encryption)',
        shortBadge: 'OPEN',
        reason: 'Anyone on this network can read your unencrypted traffic.',
      );
    }
    return WifiClassification(
      encryption: WifiEncryption.unknown,
      risk: WifiRisk.unknown,
      label: 'Unknown encryption',
      shortBadge: '?',
      reason: 'Could not determine encryption.',
    );
  }

  /// Default / factory SSID name patterns. Routers shipped with these names
  /// frequently still have the default admin password.
  static final _defaultSsidPatterns = <RegExp>[
    RegExp(r'^(TP-LINK|TPLINK)[_-]', caseSensitive: false),
    RegExp(r'^(DLINK|D-LINK)[_-]?', caseSensitive: false),
    RegExp(r'^Tenda[_-]?', caseSensitive: false),
    RegExp(r'^NETGEAR[\d_-]', caseSensitive: false),
    RegExp(r'^Linksys[\d_-]', caseSensitive: false),
    RegExp(r'^ASUS_', caseSensitive: false),
    RegExp(r'^BELKIN\.', caseSensitive: false),
    RegExp(r'^(JioFi|Jio-Fi)', caseSensitive: false),
    RegExp(r'^(Airtel_Hotspot|Airtel-)', caseSensitive: false),
    RegExp(r'^(Free|Public)[\s_-]?(WiFi|Wi-Fi|Wifi)', caseSensitive: false),
    RegExp(r'^(default|setup|admin)$', caseSensitive: false),
  ];

  static bool isLikelyDefaultSsid(String ssid) {
    final s = ssid.trim();
    if (s.isEmpty) return false;
    return _defaultSsidPatterns.any((re) => re.hasMatch(s));
  }

  /// Returns the set of SSIDs that have more than one BSSID reporting them —
  /// suggesting either a multi-AP (mesh / extender, legitimate) or an evil twin.
  /// Caller should additionally check encryption inconsistency to firm up the
  /// "evil twin" call.
  static Set<String> evilTwinSsids(List<AccessPointLite> aps) {
    final byName = <String, Set<String>>{};
    for (final ap in aps) {
      final s = ap.ssid.trim();
      if (s.isEmpty) continue; // hidden APs share blank SSID legitimately
      byName.putIfAbsent(s, () => <String>{}).add(ap.bssid.toLowerCase());
    }
    return byName.entries.where((e) => e.value.length > 1).map((e) => e.key).toSet();
  }

  /// Sharper evil-twin: two APs with same SSID but different encryption types.
  /// That's the classic "rogue clone" signature — attacker drops encryption to
  /// trick clients into auto-connecting.
  static Set<String> conflictingEncryptionSsids(List<AccessPointLite> aps) {
    final byName = <String, Set<WifiEncryption>>{};
    for (final ap in aps) {
      final s = ap.ssid.trim();
      if (s.isEmpty) continue;
      byName.putIfAbsent(s, () => <WifiEncryption>{}).add(ap.classification.encryption);
    }
    return byName.entries.where((e) => e.value.length > 1).map((e) => e.key).toSet();
  }

  /// Compute overall risk from encryption + SSID warnings.
  static WifiRisk overallRisk({
    required WifiRisk encryptionRisk,
    required bool defaultSsid,
    required bool sharedSsid,
    required bool conflictingEnc,
  }) {
    if (conflictingEnc) return WifiRisk.high;
    if (encryptionRisk == WifiRisk.high) return WifiRisk.high;
    if (defaultSsid && encryptionRisk == WifiRisk.medium) return WifiRisk.high;
    if (encryptionRisk == WifiRisk.medium) return WifiRisk.medium;
    if (defaultSsid || sharedSsid) return WifiRisk.medium;
    return encryptionRisk; // low or unknown
  }
}

/// Lightweight value-object so the risk service doesn't depend on the
/// platform `WiFiAccessPoint` type.
class AccessPointLite {
  AccessPointLite({
    required this.ssid,
    required this.bssid,
    required this.signalDbm,
    required this.frequencyMhz,
    required this.capabilities,
    required this.classification,
  });
  final String ssid;
  final String bssid;
  final int signalDbm;
  final int frequencyMhz;
  final String capabilities;
  final WifiClassification classification;

  /// 0..4 bars from RSSI dBm (Android's standard convention).
  int get signalBars {
    if (signalDbm >= -55) return 4;
    if (signalDbm >= -67) return 3;
    if (signalDbm >= -77) return 2;
    if (signalDbm >= -87) return 1;
    return 0;
  }

  String get band {
    if (frequencyMhz >= 5925) return '6 GHz';
    if (frequencyMhz >= 5000) return '5 GHz';
    return '2.4 GHz';
  }
}
