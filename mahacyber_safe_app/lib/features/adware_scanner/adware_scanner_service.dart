import 'package:flutter/services.dart';

/// Bridge to the native `getAdwareSignals` channel method. One [AdwareSignals]
/// per installed package, with the heuristics needed to compute a per-app
/// adware-risk score.
class AdwareScannerService {
  static const _channel = MethodChannel('mahacyber.safe/device_insight');

  Future<List<AdwareSignals>> scan() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('getAdwareSignals');
    if (raw == null) return const [];
    return raw
        .cast<Map<dynamic, dynamic>>()
        .map((m) => AdwareSignals.fromMap(m.cast<String, dynamic>()))
        .toList();
  }
}

/// Raw signals collected for one app — no scoring yet.
class AdwareSignals {
  AdwareSignals({
    required this.packageName,
    required this.appName,
    required this.isSystem,
    required this.installer,
    required this.isFromPlayStore,
    required this.firstInstall,
    required this.lastUpdate,
    required this.versionName,
    required this.adSdkMatches,
    required this.hasOverlayGranted,
    required this.declaresOverlay,
    required this.declaresAccessibility,
    required this.declaresBootCompleted,
    required this.declaresWakeLock,
    required this.declaresInstallPkgs,
    required this.declaresQueryAll,
    required this.hasInternet,
  });

  final String packageName;
  final String appName;
  final bool isSystem;
  final String? installer;
  final bool isFromPlayStore;
  final DateTime firstInstall;
  final DateTime lastUpdate;
  final String versionName;
  final List<String> adSdkMatches;
  final bool hasOverlayGranted;
  final bool declaresOverlay;
  final bool declaresAccessibility;
  final bool declaresBootCompleted;
  final bool declaresWakeLock;
  final bool declaresInstallPkgs;
  final bool declaresQueryAll;
  final bool hasInternet;

  int get adSdkCount => adSdkMatches.length;

  factory AdwareSignals.fromMap(Map<String, dynamic> m) => AdwareSignals(
        packageName: (m['packageName'] ?? '') as String,
        appName: (m['appName'] ?? '') as String,
        isSystem: (m['isSystem'] ?? false) as bool,
        installer: m['installer'] as String?,
        isFromPlayStore: (m['isFromPlayStore'] ?? false) as bool,
        firstInstall:
            DateTime.fromMillisecondsSinceEpoch((m['firstInstall'] ?? 0) as int),
        lastUpdate:
            DateTime.fromMillisecondsSinceEpoch((m['lastUpdate'] ?? 0) as int),
        versionName: (m['versionName'] ?? '') as String,
        adSdkMatches:
            ((m['adSdkMatches'] as List?) ?? const []).cast<String>(),
        hasOverlayGranted: (m['hasOverlayGranted'] ?? false) as bool,
        declaresOverlay: (m['declaresOverlay'] ?? false) as bool,
        declaresAccessibility:
            (m['declaresAccessibility'] ?? false) as bool,
        declaresBootCompleted:
            (m['declaresBootCompleted'] ?? false) as bool,
        declaresWakeLock: (m['declaresWakeLock'] ?? false) as bool,
        declaresInstallPkgs: (m['declaresInstallPkgs'] ?? false) as bool,
        declaresQueryAll: (m['declaresQueryAll'] ?? false) as bool,
        hasInternet: (m['hasInternet'] ?? false) as bool,
      );
}

enum AdwareRisk { high, medium, low, clean }

/// Per-app adware-risk score. Weights tuned so that:
///   * 3+ ad-SDKs alone = medium
///   * 4+ ad-SDKs + overlay/auto-start = high
///   * Sideloaded + 1+ SDK + overlay = high
///   * No SDKs + no overlay = clean
class AdwareScore {
  AdwareScore({
    required this.score,
    required this.level,
    required this.reasons,
  });

  /// 0 (clean) → 100 (worst).
  final int score;
  final AdwareRisk level;

  /// Human-readable reasons in priority order (use as detail bullets).
  final List<String> reasons;

  static AdwareScore compute(AdwareSignals s) {
    var raw = 0;
    final reasons = <String>[];

    final sdkCount = s.adSdkCount;
    if (sdkCount >= 1) {
      raw += switch (sdkCount) {
        1 => 8,
        2 => 18,
        3 => 30,
        4 => 40,
        _ => 50,
      };
      reasons.add(
        '$sdkCount ad-SDK${sdkCount == 1 ? '' : 's'} bundled: '
        '${s.adSdkMatches.take(4).join(', ')}'
        '${sdkCount > 4 ? ' +${sdkCount - 4} more' : ''}',
      );
    }

    if (s.hasOverlayGranted) {
      raw += 25;
      reasons.add('"Draw over other apps" is currently granted — '
          'can show full-screen ads on top of any app.');
    } else if (s.declaresOverlay) {
      raw += 8;
      reasons.add('Requests "Draw over other apps" permission.');
    }

    if (s.declaresBootCompleted && s.declaresWakeLock) {
      raw += 12;
      reasons.add('Auto-starts at boot and keeps the CPU awake — '
          'typical background ad / data-harvest pattern.');
    } else if (s.declaresBootCompleted) {
      raw += 5;
      reasons.add('Auto-starts at boot.');
    }

    if (s.declaresAccessibility) {
      raw += 18;
      reasons.add('Declares an Accessibility service — '
          'can read the screen and simulate taps.');
    }

    if (s.declaresInstallPkgs) {
      raw += 12;
      reasons.add('Can install other APKs (dropper risk).');
    }

    if (s.declaresQueryAll && !s.isFromPlayStore) {
      raw += 6;
      reasons.add('Sideloaded and enumerates every other app.');
    }

    // Sideload modifier — non-Play apps with even one ad SDK are worth flagging.
    if (!s.isFromPlayStore && !s.isSystem && sdkCount >= 1) {
      raw += 10;
      reasons.add('Sideloaded (not installed from Play Store).');
    }

    final score = raw.clamp(0, 100);
    final level = score >= 55
        ? AdwareRisk.high
        : score >= 28
            ? AdwareRisk.medium
            : score >= 10
                ? AdwareRisk.low
                : AdwareRisk.clean;

    return AdwareScore(score: score, level: level, reasons: reasons);
  }
}
