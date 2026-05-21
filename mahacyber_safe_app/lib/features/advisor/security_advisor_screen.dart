import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/language_picker.dart';
import '../../core/rasp/rasp_service.dart';
import '../../core/services/device_insight_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/speak_button.dart';

/// Combines RASP runtime signals with platform-level checks from
/// DeviceInsightService to produce a citizen-friendly device health view.
class SecurityAdvisorScreen extends StatefulWidget {
  const SecurityAdvisorScreen({super.key});

  @override
  State<SecurityAdvisorScreen> createState() => _SecurityAdvisorScreenState();
}

class _SecurityAdvisorScreenState extends State<SecurityAdvisorScreen> {
  final _svc = DeviceInsightService();
  DeviceSecuritySignals? _signals;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _svc.deviceSecurityChecks();
      if (!mounted) return;
      setState(() {
        _signals = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rasp = context.watch<RaspService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security advisor'),
        actions: [
          const LanguagePicker(),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _buildBody(rasp, _signals!),
    );
  }

  Widget _buildBody(RaspService rasp, DeviceSecuritySignals s) {
    bool tripped(RaspThreatType t) => rasp.threats.any((e) => e.type == t);

    final checks = <_Check>[
      _Check(
        label: 'Device is not rooted / jailbroken',
        passed: !tripped(RaspThreatType.privilegedAccess),
        advice: 'Use a stock, unmodified device. Rooted devices weaken sandboxing.',
        category: 'Critical',
      ),
      _Check(
        label: 'Screen lock (PIN / pattern / biometric) is set',
        passed: s.screenLockSet,
        advice: 'Open Settings → Security → Screen lock and set a PIN, pattern or password.',
        category: 'Critical',
        fix: _svc.openSecuritySettings,
      ),
      _Check(
        label: 'Biometric authentication enrolled',
        passed: s.biometricEnrolled,
        advice: s.biometricAvailable
            ? 'Enroll your fingerprint or face in Settings → Security for fast, strong unlock.'
            : 'This device has no biometric hardware. A strong PIN is your best alternative.',
        category: 'Recommended',
        fix: s.biometricAvailable ? _svc.openSecuritySettings : null,
      ),
      _Check(
        label: 'Device storage is encrypted',
        passed: s.encryptionEnabled,
        advice: 'Encryption protects your data if the device is lost or stolen. Android 10+ encrypts by default.',
        category: 'Critical',
      ),
      _Check(
        label: 'OS is reasonably recent',
        passed: s.sdkInt >= 28, // Android 9+
        advice: 'Older Android versions miss security patches. Update via Settings → System → System update.',
        category: 'Critical',
      ),
      _Check(
        label: 'Developer options are OFF',
        passed: !s.developerMode,
        advice: 'Developer mode unlocks debugging tools that attackers can abuse. Turn it off in Settings → System.',
        category: 'Recommended',
        fix: _svc.openDeveloperSettings,
      ),
      _Check(
        label: 'USB debugging is OFF',
        passed: !s.usbDebugging,
        advice: 'USB debugging lets a connected computer read your phone\'s data. Disable when not actively developing.',
        category: 'Recommended',
        fix: _svc.openDeveloperSettings,
      ),
      _Check(
        label: 'No app tampering detected',
        passed: !tripped(RaspThreatType.appIntegrity),
        advice: 'Reinstall CyberSafe from the official source.',
        category: 'Critical',
      ),
      _Check(
        label: 'No runtime hooking (Frida / Xposed)',
        passed: !tripped(RaspThreatType.hooks),
        advice: 'Hooking frameworks can intercept your sensitive data. Remove them.',
        category: 'Critical',
      ),
      _Check(
        label: 'Running on a real device',
        passed: !tripped(RaspThreatType.simulator),
        advice: 'Avoid running sensitive workflows on emulators.',
        category: 'Recommended',
      ),
      _Check(
        label: 'Installed from an official store',
        passed: !tripped(RaspThreatType.unofficialStore),
        advice: 'Side-loaded APKs can be modified — install from Play Store / App Store.',
        category: 'Recommended',
      ),
      _Check(
        label: 'No debugger attached',
        passed: !tripped(RaspThreatType.debug),
        advice: 'Close any debugging or USB tools while using the app.',
        category: 'Recommended',
      ),
      _Check(
        label: 'Screen is not being recorded',
        passed: !tripped(RaspThreatType.screenRecording),
        advice: 'Stop any screen recorders before performing sensitive actions.',
        category: 'Recommended',
      ),
      _Check(
        label: 'No known malware on device',
        passed: !tripped(RaspThreatType.malware),
        advice: 'Uninstall any apps flagged as malicious and run a security scan.',
        category: 'Critical',
      ),
      _Check(
        label: 'VPN connection',
        passed: true,
        advice: s.vpnActive
            ? 'A VPN is currently active — verify it is one you trust.'
            : 'No VPN connected. For untrusted networks, consider a reputable VPN.',
        category: 'Informational',
        informational: true,
        informationalDetail: s.vpnActive ? 'VPN ACTIVE' : 'No VPN',
      ),
    ];

    // Score: critical checks weighted 2x, recommended 1x, informational 0
    int gotWeighted = 0, maxWeighted = 0;
    for (final c in checks) {
      final w = c.category == 'Critical' ? 2 : c.category == 'Recommended' ? 1 : 0;
      maxWeighted += w;
      if (c.passed) gotWeighted += w;
    }
    final score = maxWeighted == 0 ? 0 : ((gotWeighted / maxWeighted) * 100).round();

    final critical = checks.where((c) => c.category == 'Critical').toList();
    final recommended = checks.where((c) => c.category == 'Recommended').toList();
    final info = checks.where((c) => c.category == 'Informational').toList();

    final criticalFails = critical.where((c) => !c.passed).toList();
    final recommendedFails = recommended.where((c) => !c.passed).toList();
    final speech = _buildSpeechSummary(score, criticalFails, recommendedFails);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ScoreCard(score: score, signals: s),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: SpeakButton(text: speech, label: 'Read aloud'),
        ),
        const SizedBox(height: 12),
        if (criticalFails.isNotEmpty) _sectionHeader('Critical issues', AppColors.danger),
        ...criticalFails.map((c) => _CheckTile(check: c)),
        if (recommendedFails.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionHeader('Recommended actions', AppColors.warning),
          ...recommendedFails.map((c) => _CheckTile(check: c)),
        ],
        const SizedBox(height: 12),
        _sectionHeader('Passed checks', AppColors.safe),
        ...checks.where((c) => c.passed && !c.informational).map((c) => _CheckTile(check: c)),
        if (info.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionHeader('Informational', AppColors.primary),
          ...info.map((c) => _CheckTile(check: c)),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Container(width: 4, height: 18, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }
}

class _Check {
  const _Check({
    required this.label,
    required this.passed,
    required this.advice,
    required this.category,
    this.fix,
    this.informational = false,
    this.informationalDetail,
  });
  final String label;
  final bool passed;
  final String advice;
  final String category;
  final Future<void> Function()? fix;
  final bool informational;
  final String? informationalDetail;
}

String _buildSpeechSummary(int score, List<_Check> criticalFails, List<_Check> recommendedFails) {
  final grade = _grade(score);
  final buf = StringBuffer();
  buf.write('Your device security score is $score out of 100. Grade: $grade. ');
  if (criticalFails.isEmpty && recommendedFails.isEmpty) {
    buf.write('All checks passed. Your device is in great shape.');
    return buf.toString();
  }
  if (criticalFails.isNotEmpty) {
    buf.write('Critical issues: ');
    buf.write(criticalFails.map((c) => c.label).join('. '));
    buf.write('. ');
  }
  if (recommendedFails.isNotEmpty) {
    buf.write('Recommended actions: ');
    buf.write(recommendedFails.map((c) => c.label).join('. '));
    buf.write('. ');
  }
  return buf.toString();
}

String _grade(int score) {
  if (score >= 90) return 'A';
  if (score >= 80) return 'B';
  if (score >= 65) return 'C';
  if (score >= 50) return 'D';
  return 'F';
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score, required this.signals});
  final int score;
  final DeviceSecuritySignals signals;

  Color get _color {
    if (score >= 85) return AppColors.safe;
    if (score >= 60) return AppColors.warning;
    return AppColors.danger;
  }

  String get _label {
    if (score >= 85) return 'Healthy';
    if (score >= 60) return 'Needs attention';
    return 'At risk';
  }

  @override
  Widget build(BuildContext context) {
    final grade = _grade(score);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _color.withOpacity(0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 104, height: 104,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 104, height: 104,
                        child: CircularProgressIndicator(
                          value: score / 100,
                          strokeWidth: 8,
                          backgroundColor: _color.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation(_color),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(grade,
                              style: TextStyle(color: _color, fontSize: 26, fontWeight: FontWeight.w800, height: 1.0)),
                          const SizedBox(height: 4),
                          Text('$score / 100',
                              style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w700, height: 1.0)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Device security score',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(_label,
                          style: TextStyle(color: _color, fontSize: 18, fontWeight: FontWeight.w800),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      const Text(
                        'Computed live from RASP + platform checks.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('Android', signals.androidVersion),
                _stat('Patch', signals.securityPatch.isEmpty ? '—' : signals.securityPatch),
                _stat('Device', '${signals.manufacturer} ${signals.model}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Flexible(
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({required this.check});
  final _Check check;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    if (check.informational) {
      color = AppColors.primary;
      icon = Icons.info_outline;
    } else if (check.passed) {
      color = AppColors.safe;
      icon = Icons.check_circle;
    } else {
      color = AppColors.danger;
      icon = Icons.error;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color),
          ),
          title: Text(check.label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(check.advice, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          trailing: check.fix != null && !check.passed
              ? TextButton(onPressed: check.fix, child: const Text('Fix'))
              : (check.informationalDetail != null
                  ? Text(check.informationalDetail!,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color))
                  : null),
          isThreeLine: true,
        ),
      ),
    );
  }
}
