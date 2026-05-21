import 'package:flutter/foundation.dart';
import 'package:freerasp/freerasp.dart';

import '../services/backend_client.dart';

/// Categorises a single detected RASP threat for UI consumption.
enum RaspThreatType {
  appIntegrity,
  debug,
  deviceBinding,
  deviceId,
  hooks,
  passcode,
  privilegedAccess,
  screenshot,
  screenRecording,
  secureHardwareUnavailable,
  simulator,
  systemVpn,
  unofficialStore,
  obfuscationIssues,
  devMode,
  malware,
}

extension RaspThreatTypeX on RaspThreatType {
  String get title {
    switch (this) {
      case RaspThreatType.appIntegrity:
        return 'App tampering detected';
      case RaspThreatType.debug:
        return 'Debugger attached';
      case RaspThreatType.deviceBinding:
        return 'Device binding changed';
      case RaspThreatType.deviceId:
        return 'Device identity changed';
      case RaspThreatType.hooks:
        return 'Runtime hooking detected';
      case RaspThreatType.passcode:
        return 'Device passcode not set';
      case RaspThreatType.privilegedAccess:
        return 'Rooted / jailbroken device';
      case RaspThreatType.screenshot:
        return 'Screenshot captured';
      case RaspThreatType.screenRecording:
        return 'Screen recording active';
      case RaspThreatType.secureHardwareUnavailable:
        return 'Secure hardware unavailable';
      case RaspThreatType.simulator:
        return 'Emulator / simulator detected';
      case RaspThreatType.systemVpn:
        return 'System VPN active';
      case RaspThreatType.unofficialStore:
        return 'Installed from unofficial store';
      case RaspThreatType.obfuscationIssues:
        return 'Obfuscation issue';
      case RaspThreatType.devMode:
        return 'Developer mode enabled';
      case RaspThreatType.malware:
        return 'Known malware detected on device';
    }
  }

  /// Short citizen-friendly recommendation.
  String get advice {
    switch (this) {
      case RaspThreatType.appIntegrity:
        return 'This installation may have been modified. Reinstall CyberSafe from the official Play Store / App Store.';
      case RaspThreatType.debug:
        return 'A debugger is attached. Close any debugging tools to keep your session secure.';
      case RaspThreatType.deviceBinding:
        return 'Re-authenticate to re-bind your account to this device.';
      case RaspThreatType.deviceId:
        return 'Device identity has changed. Verify your account.';
      case RaspThreatType.hooks:
        return 'A runtime instrumentation framework (e.g. Frida) was detected. Remove it before continuing.';
      case RaspThreatType.passcode:
        return 'Please set a device PIN, pattern, or biometric for stronger protection.';
      case RaspThreatType.privilegedAccess:
        return 'Rooted / jailbroken devices significantly weaken security. Use a stock device for sensitive actions.';
      case RaspThreatType.screenshot:
        return 'A screenshot was taken. Avoid sharing screens containing OTPs or personal data.';
      case RaspThreatType.screenRecording:
        return 'Screen recording is active. Stop recording before performing sensitive actions.';
      case RaspThreatType.secureHardwareUnavailable:
        return 'This device lacks a secure hardware enclave. Sensitive credentials are at higher risk.';
      case RaspThreatType.simulator:
        return 'App is running on an emulator. Use a real device for sensitive activity.';
      case RaspThreatType.systemVpn:
        return 'A system VPN is active. Make sure you trust the VPN provider.';
      case RaspThreatType.unofficialStore:
        return 'App was sideloaded or installed from an unofficial source. Reinstall from the official store.';
      case RaspThreatType.obfuscationIssues:
        return 'Build obfuscation issue. Contact support.';
      case RaspThreatType.devMode:
        return 'Developer mode is enabled — switch it off when not actively developing.';
      case RaspThreatType.malware:
        return 'A potentially malicious application was detected. Uninstall it from your device.';
    }
  }

  RaspSeverity get severity {
    switch (this) {
      case RaspThreatType.appIntegrity:
      case RaspThreatType.hooks:
      case RaspThreatType.privilegedAccess:
      case RaspThreatType.malware:
        return RaspSeverity.critical;
      case RaspThreatType.debug:
      case RaspThreatType.simulator:
      case RaspThreatType.unofficialStore:
      case RaspThreatType.deviceBinding:
      case RaspThreatType.deviceId:
        return RaspSeverity.high;
      case RaspThreatType.screenRecording:
      case RaspThreatType.passcode:
      case RaspThreatType.systemVpn:
      case RaspThreatType.secureHardwareUnavailable:
        return RaspSeverity.medium;
      case RaspThreatType.screenshot:
      case RaspThreatType.devMode:
      case RaspThreatType.obfuscationIssues:
        return RaspSeverity.low;
    }
  }
}

enum RaspSeverity { low, medium, high, critical }

class RaspThreatEvent {
  RaspThreatEvent({
    required this.type,
    required this.detectedAt,
    this.details,
  });

  final RaspThreatType type;
  final DateTime detectedAt;
  final String? details;
}

/// Bridges Talsec freeRASP into a Provider-friendly state holder.
///
/// Production checklist before shipping:
///   - Replace placeholder package name / bundle id with the real ones.
///   - Replace signingCertHashes with the SHA-256 of your release keystore.
///   - Replace iOS bundleIds + teamId with the real Apple Team ID.
///   - Replace watcherMail with the security inbox.
///   - Set isProd: true for release builds.
class RaspService extends ChangeNotifier {
  RaspService({BackendClient? backend}) : _backend = backend ?? BackendClient();

  final BackendClient _backend;
  final List<RaspThreatEvent> _threats = [];
  bool _started = false;

  BackendClient get backend => _backend;

  List<RaspThreatEvent> get threats => List.unmodifiable(_threats);
  bool get started => _started;
  bool get hasCriticalThreat =>
      _threats.any((t) => t.type.severity == RaspSeverity.critical);
  bool get hasAnyThreat => _threats.isNotEmpty;

  /// Highest severity currently observed, or null if clean.
  RaspSeverity? get highestSeverity {
    if (_threats.isEmpty) return null;
    return _threats
        .map((t) => t.type.severity)
        .reduce((a, b) => a.index >= b.index ? a : b);
  }

  Future<void> start() async {
    if (_started) return;

    final config = TalsecConfig(
      androidConfig: AndroidConfig(
        packageName: 'in.gov.maharashtracyber.safe',
        signingCertHashes: const [
          // TODO: replace with SHA-256 of release keystore (Base64-encoded).
          'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
        ],
        supportedStores: const [],
      ),
      iosConfig: IOSConfig(
        bundleIds: const ['in.gov.maharashtracyber.safe'],
        teamId: 'XXXXXXXXXX', // TODO: replace with Apple Team ID.
      ),
      watcherMail: 'security@cybersafe.local',
      isProd: kReleaseMode,
    );

    final callback = ThreatCallback(
      onAppIntegrity: () => _record(RaspThreatType.appIntegrity),
      onDebug: () => _record(RaspThreatType.debug),
      onDeviceBinding: () => _record(RaspThreatType.deviceBinding),
      onDeviceID: () => _record(RaspThreatType.deviceId),
      onHooks: () => _record(RaspThreatType.hooks),
      onPasscode: () => _record(RaspThreatType.passcode),
      onPrivilegedAccess: () => _record(RaspThreatType.privilegedAccess),
      onScreenshot: () => _record(RaspThreatType.screenshot),
      onScreenRecording: () => _record(RaspThreatType.screenRecording),
      onSecureHardwareNotAvailable: () =>
          _record(RaspThreatType.secureHardwareUnavailable),
      onSimulator: () => _record(RaspThreatType.simulator),
      onSystemVPN: () => _record(RaspThreatType.systemVpn),
      onUnofficialStore: () => _record(RaspThreatType.unofficialStore),
      onObfuscationIssues: () => _record(RaspThreatType.obfuscationIssues),
      onDevMode: () => _record(RaspThreatType.devMode),
      onMalware: (malware) => _record(
        RaspThreatType.malware,
        details: malware
            .whereType<SuspiciousAppInfo>()
            .map((m) => m.packageInfo.packageName)
            .join(', '),
      ),
    );

    try {
      Talsec.instance.attachListener(callback);
      await Talsec.instance.start(config);
      _started = true;
      notifyListeners();
    } catch (e, st) {
      debugPrint('RASP start failed: $e\n$st');
    }
  }

  void _record(RaspThreatType type, {String? details}) {
    // De-duplicate repeated identical threat fires within the same session.
    if (_threats.any((t) => t.type == type)) return;
    _threats.add(
      RaspThreatEvent(
        type: type,
        detectedAt: DateTime.now(),
        details: details,
      ),
    );
    notifyListeners();
    // Fire-and-forget report to backend so the admin console sees this device's state.
    _backend.reportThreat(
      type: type.title,
      severity: type.severity.name,
      details: details,
    );
  }

  void clearThreats() {
    _threats.clear();
    notifyListeners();
  }
}
