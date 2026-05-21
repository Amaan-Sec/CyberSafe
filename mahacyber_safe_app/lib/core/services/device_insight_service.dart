import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Bridge to the native PackageManager / KeyguardManager / etc. Single source of
/// truth for installed-apps + device-security signals.
class DeviceInsightService {
  static const _channel = MethodChannel('mahacyber.safe/device_insight');

  /// One entry per installed package. `includeIcons:true` returns base64 PNGs (~few KB each).
  Future<List<AppInfo>> listInstalledApps({bool includeIcons = true}) async {
    final raw = await _channel.invokeMethod<List<dynamic>>(
      'listInstalledApps',
      {'includeIcons': includeIcons},
    );
    if (raw == null) return const [];
    return raw
        .cast<Map<dynamic, dynamic>>()
        .map((m) => AppInfo.fromMap(m.cast<String, dynamic>()))
        .toList();
  }

  Future<DeviceSecuritySignals> deviceSecurityChecks() async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('deviceSecurityChecks');
    return DeviceSecuritySignals.fromMap((raw ?? {}).cast<String, dynamic>());
  }

  Future<void> openAppSettings(String packageName) =>
      _channel.invokeMethod('openAppSettings', {'package': packageName});

  Future<void> uninstallApp(String packageName) =>
      _channel.invokeMethod('uninstallApp', {'package': packageName});

  Future<void> openSecuritySettings() => _channel.invokeMethod('openSecuritySettings');

  Future<void> openDeveloperSettings() => _channel.invokeMethod('openDeveloperSettings');

  Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod('openAccessibilitySettings');

  Future<List<AccessibilityServiceEntry>> listAccessibilityServices() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('listAccessibilityServices');
    if (raw == null) return const [];
    return raw
        .cast<Map<dynamic, dynamic>>()
        .map((m) => AccessibilityServiceEntry.fromMap(m.cast<String, dynamic>()))
        .toList();
  }
}

/// One installed accessibility service entry, as reported by AccessibilityManager.
class AccessibilityServiceEntry {
  AccessibilityServiceEntry({
    required this.packageName,
    required this.component,
    required this.serviceLabel,
    required this.appName,
    required this.isSystem,
    required this.installer,
    required this.firstInstall,
    required this.lastUpdate,
    required this.enabled,
    required this.capabilities,
    required this.description,
  });

  final String packageName;
  final String component;
  final String serviceLabel;
  final String appName;
  final bool isSystem;
  final String? installer;
  final DateTime firstInstall;
  final DateTime lastUpdate;
  final bool enabled;
  final List<String> capabilities;
  final String description;

  bool get isFromPlayStore =>
      installer == 'com.android.vending' || installer == 'com.google.android.feedback';

  /// Suspicious sideloaded service: enabled + not system + not installed via
  /// Play Store. This is the canonical "banking malware via AnyDesk" pattern.
  bool get isSideloadedAndEnabled => enabled && !isSystem && !isFromPlayStore;

  /// Known remote-access / control labels often abused by scammers.
  bool get matchesRemoteControlName {
    final n = '$appName $serviceLabel'.toLowerCase();
    const flags = [
      'anydesk', 'teamviewer', 'quicksupport', 'remote control', 'remote desk',
      'airdroid', 'screen share', 'remote support', 'logmein', 'splashtop',
      'rustdesk', 'screen record', 'mirror screen',
    ];
    return flags.any(n.contains);
  }

  /// Aggregate risk: red = enabled + (sideloaded OR remote-control name).
  /// Yellow = installed-but-disabled remote-control app.
  /// Green = system / Play-store assistive tech (TalkBack etc).
  AccessibilityRisk get risk {
    if (enabled && (isSideloadedAndEnabled || matchesRemoteControlName)) {
      return AccessibilityRisk.high;
    }
    if (matchesRemoteControlName) return AccessibilityRisk.medium;
    if (enabled && !isSystem && !isFromPlayStore) return AccessibilityRisk.medium;
    return AccessibilityRisk.low;
  }

  factory AccessibilityServiceEntry.fromMap(Map<String, dynamic> m) =>
      AccessibilityServiceEntry(
        packageName: (m['packageName'] ?? '') as String,
        component: (m['component'] ?? '') as String,
        serviceLabel: (m['serviceLabel'] ?? '') as String,
        appName: (m['appName'] ?? '') as String,
        isSystem: (m['isSystem'] ?? false) as bool,
        installer: m['installer'] as String?,
        firstInstall:
            DateTime.fromMillisecondsSinceEpoch((m['firstInstall'] ?? 0) as int),
        lastUpdate:
            DateTime.fromMillisecondsSinceEpoch((m['lastUpdate'] ?? 0) as int),
        enabled: (m['enabled'] ?? false) as bool,
        capabilities:
            ((m['capabilities'] as List?) ?? const []).cast<String>(),
        description: (m['description'] ?? '') as String,
      );
}

enum AccessibilityRisk { high, medium, low }


class AppInfo {
  AppInfo({
    required this.packageName,
    required this.appName,
    required this.isSystem,
    required this.hasLauncher,
    required this.installer,
    required this.firstInstall,
    required this.lastUpdate,
    required this.versionName,
    required this.targetSdk,
    required this.permissions,
    required this.grantedPermissions,
    this.iconPng,
  });

  final String packageName;
  final String appName;
  final bool isSystem;
  final bool hasLauncher;
  final String? installer;
  final DateTime firstInstall;
  final DateTime lastUpdate;
  final String versionName;
  final int targetSdk;
  final List<String> permissions;
  final List<String> grantedPermissions;
  final Uint8List? iconPng;

  bool get isFromPlayStore =>
      installer == 'com.android.vending' || installer == 'com.google.android.feedback';

  /// Apps usually flagged as hidden if they have no launcher icon AND aren't a system framework.
  bool get isLikelyHidden => !hasLauncher && !_isFrameworkPackage(packageName);

  static bool _isFrameworkPackage(String pkg) =>
      pkg.startsWith('android') ||
      pkg.startsWith('com.android') ||
      pkg.startsWith('com.google.android.gms') ||
      pkg.startsWith('com.google.android.gsf') ||
      pkg.startsWith('com.qualcomm') ||
      pkg.startsWith('com.mediatek');

  /// Suspicious naming heuristics — generic names that scams often use.
  bool get hasSuspiciousName {
    final n = appName.toLowerCase();
    const flags = ['system update', 'update service', 'system service', 'system care',
                   'kyc', 'verify your account', 'wallet helper', 'flash player',
                   'video downloader pro', 'cleaner pro'];
    return flags.any(n.contains);
  }

  factory AppInfo.fromMap(Map<String, dynamic> m) {
    final iconStr = m['icon'] as String?;
    return AppInfo(
      packageName: (m['packageName'] ?? '') as String,
      appName: (m['appName'] ?? '') as String,
      isSystem: (m['isSystem'] ?? false) as bool,
      hasLauncher: (m['hasLauncher'] ?? false) as bool,
      installer: m['installer'] as String?,
      firstInstall: DateTime.fromMillisecondsSinceEpoch((m['firstInstall'] ?? 0) as int),
      lastUpdate: DateTime.fromMillisecondsSinceEpoch((m['lastUpdate'] ?? 0) as int),
      versionName: (m['versionName'] ?? '') as String,
      targetSdk: ((m['targetSdk'] ?? 0) as num).toInt(),
      permissions: ((m['permissions'] as List?) ?? const []).cast<String>(),
      grantedPermissions: ((m['grantedPermissions'] as List?) ?? const []).cast<String>(),
      iconPng: iconStr == null ? null : base64Decode(iconStr),
    );
  }
}

/// Maps an Android permission constant to a citizen-friendly bundle.
class PermissionRisk {
  const PermissionRisk({required this.label, required this.risk, required this.reason});
  final String label;
  final RiskLevel risk;
  final String reason;
}

enum RiskLevel { high, medium, low, unknown }

/// Permissions classifier — single source of truth.
class PermissionCatalog {
  static const Map<String, PermissionRisk> _map = {
    // HIGH
    'android.permission.CAMERA': PermissionRisk(label: 'Camera', risk: RiskLevel.high,
        reason: 'Can record video and take pictures silently in the background.'),
    'android.permission.RECORD_AUDIO': PermissionRisk(label: 'Microphone', risk: RiskLevel.high,
        reason: 'Can record audio at any time.'),
    'android.permission.READ_CONTACTS': PermissionRisk(label: 'Read contacts', risk: RiskLevel.high,
        reason: 'Can read your entire address book.'),
    'android.permission.WRITE_CONTACTS': PermissionRisk(label: 'Modify contacts', risk: RiskLevel.high,
        reason: 'Can add or delete contacts.'),
    'android.permission.READ_SMS': PermissionRisk(label: 'Read SMS', risk: RiskLevel.high,
        reason: 'Can read every SMS including OTPs and banking messages.'),
    'android.permission.RECEIVE_SMS': PermissionRisk(label: 'Intercept SMS', risk: RiskLevel.high,
        reason: 'Can intercept incoming SMS before you see them.'),
    'android.permission.SEND_SMS': PermissionRisk(label: 'Send SMS', risk: RiskLevel.high,
        reason: 'Can send premium-rate SMS at your cost.'),
    'android.permission.ACCESS_FINE_LOCATION': PermissionRisk(label: 'Precise location', risk: RiskLevel.high,
        reason: 'Tracks your GPS location.'),
    'android.permission.ACCESS_BACKGROUND_LOCATION': PermissionRisk(label: 'Background location', risk: RiskLevel.high,
        reason: 'Tracks location even when the app is closed.'),
    'android.permission.READ_EXTERNAL_STORAGE': PermissionRisk(label: 'Read all files', risk: RiskLevel.high,
        reason: 'Can read photos, documents and anything on storage.'),
    'android.permission.WRITE_EXTERNAL_STORAGE': PermissionRisk(label: 'Modify storage', risk: RiskLevel.high,
        reason: 'Can write, modify or delete files on storage.'),
    'android.permission.MANAGE_EXTERNAL_STORAGE': PermissionRisk(label: 'All-files access', risk: RiskLevel.high,
        reason: 'Has unrestricted access to every file on the device.'),
    'android.permission.PACKAGE_USAGE_STATS': PermissionRisk(label: 'Usage stats', risk: RiskLevel.high,
        reason: 'Can see which apps you open and for how long.'),
    'android.permission.SYSTEM_ALERT_WINDOW': PermissionRisk(label: 'Draw over apps', risk: RiskLevel.high,
        reason: 'Can overlay phishing prompts on top of any app.'),
    'android.permission.BIND_ACCESSIBILITY_SERVICE': PermissionRisk(label: 'Accessibility service', risk: RiskLevel.high,
        reason: 'Can read on-screen text and simulate taps — strongest hijack power.'),
    'android.permission.BIND_DEVICE_ADMIN': PermissionRisk(label: 'Device admin', risk: RiskLevel.high,
        reason: 'Can wipe your phone, change lock-screen password, or block uninstall.'),
    'android.permission.REQUEST_INSTALL_PACKAGES': PermissionRisk(label: 'Install other apps', risk: RiskLevel.high,
        reason: 'Can install other APKs — main vector for dropper malware.'),
    'android.permission.READ_CALL_LOG': PermissionRisk(label: 'Read call log', risk: RiskLevel.high,
        reason: 'Can read who you call and when.'),
    'android.permission.WRITE_CALL_LOG': PermissionRisk(label: 'Modify call log', risk: RiskLevel.high,
        reason: 'Can alter or delete call history entries.'),
    'android.permission.ANSWER_PHONE_CALLS': PermissionRisk(label: 'Answer calls', risk: RiskLevel.high,
        reason: 'Can answer incoming calls without you.'),
    'android.permission.PROCESS_OUTGOING_CALLS': PermissionRisk(label: 'Intercept outgoing calls', risk: RiskLevel.high,
        reason: 'Can intercept or redirect outgoing calls.'),

    // MEDIUM
    'android.permission.CALL_PHONE': PermissionRisk(label: 'Make phone calls', risk: RiskLevel.medium,
        reason: 'Can place calls (including premium numbers) without confirmation.'),
    'android.permission.READ_PHONE_STATE': PermissionRisk(label: 'Phone identity', risk: RiskLevel.medium,
        reason: 'Reads IMEI, SIM serial, phone number.'),
    'android.permission.READ_PHONE_NUMBERS': PermissionRisk(label: 'Phone number', risk: RiskLevel.medium,
        reason: 'Reads your phone number.'),
    'android.permission.READ_CALENDAR': PermissionRisk(label: 'Read calendar', risk: RiskLevel.medium,
        reason: 'Can read your calendar events.'),
    'android.permission.WRITE_CALENDAR': PermissionRisk(label: 'Modify calendar', risk: RiskLevel.medium,
        reason: 'Can add or remove calendar events.'),
    'android.permission.ACCESS_COARSE_LOCATION': PermissionRisk(label: 'Approximate location', risk: RiskLevel.medium,
        reason: 'Tracks rough location from Wi-Fi / cell towers.'),
    'android.permission.BODY_SENSORS': PermissionRisk(label: 'Body sensors', risk: RiskLevel.medium,
        reason: 'Reads heart-rate / health sensor data.'),
    'android.permission.GET_ACCOUNTS': PermissionRisk(label: 'List accounts', risk: RiskLevel.medium,
        reason: 'Can see Google/Email accounts on your device.'),
    'android.permission.BLUETOOTH_CONNECT': PermissionRisk(label: 'Bluetooth pairing', risk: RiskLevel.medium,
        reason: 'Can pair with nearby Bluetooth devices.'),
    'android.permission.NFC': PermissionRisk(label: 'NFC', risk: RiskLevel.medium,
        reason: 'Can read/write NFC tags near the phone.'),
    'android.permission.QUERY_ALL_PACKAGES': PermissionRisk(label: 'List all apps', risk: RiskLevel.medium,
        reason: 'Can enumerate every other app installed.'),

    // LOW
    'android.permission.INTERNET': PermissionRisk(label: 'Internet', risk: RiskLevel.low,
        reason: 'Standard — needed by almost every app.'),
    'android.permission.ACCESS_NETWORK_STATE': PermissionRisk(label: 'Network state', risk: RiskLevel.low,
        reason: 'Can check Wi-Fi / mobile connectivity.'),
    'android.permission.ACCESS_WIFI_STATE': PermissionRisk(label: 'Wi-Fi state', risk: RiskLevel.low,
        reason: 'Can read Wi-Fi connection details.'),
    'android.permission.VIBRATE': PermissionRisk(label: 'Vibrate', risk: RiskLevel.low,
        reason: 'Can vibrate the phone.'),
    'android.permission.POST_NOTIFICATIONS': PermissionRisk(label: 'Show notifications', risk: RiskLevel.low,
        reason: 'Can post notifications.'),
    'android.permission.FOREGROUND_SERVICE': PermissionRisk(label: 'Foreground service', risk: RiskLevel.low,
        reason: 'Can run with a persistent notification.'),
    'android.permission.WAKE_LOCK': PermissionRisk(label: 'Keep awake', risk: RiskLevel.low,
        reason: 'Can keep the screen / CPU awake.'),
    'android.permission.RECEIVE_BOOT_COMPLETED': PermissionRisk(label: 'Auto-start at boot', risk: RiskLevel.low,
        reason: 'Starts automatically when phone restarts.'),
  };

  static PermissionRisk classify(String permission) {
    return _map[permission] ??
        PermissionRisk(
          label: _humanise(permission),
          risk: RiskLevel.unknown,
          reason: 'No description available for this permission.',
        );
  }

  static String _humanise(String permission) {
    final short = permission.replaceAll('android.permission.', '').replaceAll('_', ' ');
    return short.split(' ').map((w) => w.isEmpty ? w : (w[0] + w.substring(1).toLowerCase())).join(' ');
  }
}

/// Risk score for one app.
class AppRiskScore {
  AppRiskScore({
    required this.high,
    required this.medium,
    required this.low,
    required this.unknown,
    required this.score,
    required this.level,
  });

  final int high;
  final int medium;
  final int low;
  final int unknown;
  final int score; // 0-100
  final RiskLevel level;

  static AppRiskScore compute(AppInfo app) {
    int h = 0, m = 0, l = 0, u = 0;
    // Only count granted permissions (requested but denied don't matter)
    for (final p in app.grantedPermissions) {
      switch (PermissionCatalog.classify(p).risk) {
        case RiskLevel.high: h++; break;
        case RiskLevel.medium: m++; break;
        case RiskLevel.low: l++; break;
        case RiskLevel.unknown: u++; break;
      }
    }
    // Weighted score: 0 (safest) → 100 (worst)
    final raw = h * 12 + m * 5 + l * 1 + u * 2;
    final score = raw.clamp(0, 100);
    final level = score >= 36 ? RiskLevel.high : score >= 12 ? RiskLevel.medium : RiskLevel.low;
    return AppRiskScore(high: h, medium: m, low: l, unknown: u, score: score, level: level);
  }
}

/// Aggregate device-security signals (from native).
class DeviceSecuritySignals {
  DeviceSecuritySignals({
    required this.screenLockSet,
    required this.biometricAvailable,
    required this.biometricEnrolled,
    required this.encryptionEnabled,
    required this.encryptionStatus,
    required this.androidVersion,
    required this.sdkInt,
    required this.manufacturer,
    required this.model,
    required this.securityPatch,
    required this.developerMode,
    required this.usbDebugging,
    required this.unknownSourcesUnknown,
    required this.vpnActive,
  });

  final bool screenLockSet;
  final bool biometricAvailable;
  final bool biometricEnrolled;
  final bool encryptionEnabled;
  final int encryptionStatus;
  final String androidVersion;
  final int sdkInt;
  final String manufacturer;
  final String model;
  final String securityPatch;
  final bool developerMode;
  final bool usbDebugging;
  final bool unknownSourcesUnknown;
  final bool vpnActive;

  factory DeviceSecuritySignals.fromMap(Map<String, dynamic> m) => DeviceSecuritySignals(
        screenLockSet: (m['screenLockSet'] ?? false) as bool,
        biometricAvailable: (m['biometricAvailable'] ?? false) as bool,
        biometricEnrolled: (m['biometricEnrolled'] ?? false) as bool,
        encryptionEnabled: (m['encryptionEnabled'] ?? false) as bool,
        encryptionStatus: ((m['encryptionStatus'] ?? 0) as num).toInt(),
        androidVersion: (m['androidVersion'] ?? '') as String,
        sdkInt: ((m['sdkInt'] ?? 0) as num).toInt(),
        manufacturer: (m['manufacturer'] ?? '') as String,
        model: (m['model'] ?? '') as String,
        securityPatch: (m['securityPatch'] ?? '') as String,
        developerMode: (m['developerMode'] ?? false) as bool,
        usbDebugging: (m['usbDebugging'] ?? false) as bool,
        unknownSourcesUnknown: (m['unknownSourcesUnknown'] ?? false) as bool,
        vpnActive: (m['vpnActive'] ?? false) as bool,
      );
}
