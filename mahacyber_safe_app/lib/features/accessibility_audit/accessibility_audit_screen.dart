import 'package:flutter/material.dart';

import '../../core/i18n/strings.dart';
import '../../core/services/backend_client.dart';
import '../../core/services/device_insight_service.dart';
import '../../core/theme/app_theme.dart';

class AccessibilityAuditScreen extends StatefulWidget {
  const AccessibilityAuditScreen({super.key});

  @override
  State<AccessibilityAuditScreen> createState() =>
      _AccessibilityAuditScreenState();
}

class _AccessibilityAuditScreenState extends State<AccessibilityAuditScreen> {
  final _svc = DeviceInsightService();
  List<AccessibilityServiceEntry>? _entries;
  String? _error;
  bool _loading = true;
  bool _logged = false;

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
      final list = await _svc.listAccessibilityServices();
      list.sort((a, b) {
        // Risk desc, then enabled desc, then name asc.
        int cmp = b.risk.index.compareTo(a.risk.index);
        if (cmp != 0) return cmp;
        cmp = (b.enabled ? 1 : 0).compareTo(a.enabled ? 1 : 0);
        if (cmp != 0) return cmp;
        return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
      });
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loading = false;
      });
      _logScan(list);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _logScan(List<AccessibilityServiceEntry> list) {
    if (_logged) return;
    _logged = true;
    final hasHigh = list.any((e) => e.risk == AccessibilityRisk.high);
    final hasMed = list.any((e) => e.risk == AccessibilityRisk.medium);
    final verdict = hasHigh
        ? 'malicious'
        : hasMed
            ? 'suspicious'
            : 'safe';
    BackendClient().recordScan(
      kind: 'accessibility',
      verdict: verdict,
      target:
          '${list.length} services · ${list.where((e) => e.enabled).length} enabled',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t(context, 'a11y.title')),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorBox(
                  message: _error!,
                  onRetry: _load,
                )
              : _AccessibilityList(
                  entries: _entries ?? const [],
                  onOpenSettings: () => _svc.openAccessibilitySettings(),
                  onOpenApp: (pkg) => _svc.openAppSettings(pkg),
                ),
    );
  }
}

class _AccessibilityList extends StatelessWidget {
  const _AccessibilityList({
    required this.entries,
    required this.onOpenSettings,
    required this.onOpenApp,
  });

  final List<AccessibilityServiceEntry> entries;
  final VoidCallback onOpenSettings;
  final void Function(String packageName) onOpenApp;

  @override
  Widget build(BuildContext context) {
    final enabledCount = entries.where((e) => e.enabled).length;
    final highCount =
        entries.where((e) => e.risk == AccessibilityRisk.high).length;
    final medCount =
        entries.where((e) => e.risk == AccessibilityRisk.medium).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: highCount > 0
                ? AppColors.danger.withOpacity(0.10)
                : medCount > 0
                    ? AppColors.warning.withOpacity(0.10)
                    : AppColors.safe.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highCount > 0
                  ? AppColors.danger.withOpacity(0.30)
                  : medCount > 0
                      ? AppColors.warning.withOpacity(0.30)
                      : AppColors.safe.withOpacity(0.30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    highCount > 0
                        ? Icons.dangerous
                        : medCount > 0
                            ? Icons.warning_amber_rounded
                            : Icons.verified,
                    color: highCount > 0
                        ? AppColors.danger
                        : medCount > 0
                            ? AppColors.warning
                            : AppColors.safe,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      highCount > 0
                          ? S.t(context, 'a11y.summaryHigh')
                          : medCount > 0
                              ? S.t(context, 'a11y.summaryMed')
                              : S.t(context, 'a11y.summarySafe'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${entries.length} ${S.t(context, 'a11y.installed')} · '
                '$enabledCount ${S.t(context, 'a11y.enabled')} · '
                '$highCount ${S.t(context, 'a11y.highRisk')}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_accessibility),
                label: Text(S.t(context, 'a11y.openSettings')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          S.t(context, 'a11y.whyMatters'),
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                S.t(context, 'a11y.noneFound'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ServiceCard(
                  entry: e,
                  onOpen: () => onOpenApp(e.packageName),
                ),
              )),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.entry, required this.onOpen});
  final AccessibilityServiceEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (entry.risk) {
      AccessibilityRisk.high => (AppColors.danger, S.t(context, 'a11y.riskHigh')),
      AccessibilityRisk.medium => (AppColors.warning, S.t(context, 'a11y.riskMed')),
      AccessibilityRisk.low => (AppColors.safe, S.t(context, 'a11y.riskLow')),
    };
    final source = entry.isFromPlayStore
        ? 'Play Store'
        : entry.isSystem
            ? 'System'
            : entry.installer ?? S.t(context, 'a11y.sideloaded');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
              const SizedBox(width: 8),
              if (entry.enabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(S.t(context, 'a11y.enabled').toUpperCase(),
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.danger)),
                ),
              const Spacer(),
              IconButton(
                tooltip: S.t(context, 'a11y.openApp'),
                icon: const Icon(Icons.open_in_new, size: 18),
                onPressed: onOpen,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(entry.appName,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          if (entry.serviceLabel != entry.appName)
            Text(entry.serviceLabel,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(entry.packageName,
              style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.shop_outlined,
                  size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(source,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          if (entry.capabilities.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: entry.capabilities
                  .map((c) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(4),
                          border:
                              Border.all(color: Colors.black12),
                        ),
                        child: Text(c.replaceAll('_', ' '),
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary)),
                      ))
                  .toList(),
            ),
          ],
          if (entry.matchesRemoteControlName) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.flag, size: 14, color: AppColors.danger),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    S.t(context, 'a11y.remoteControlFlag'),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(S.t(context, 'common.retry')),
          ),
        ],
      ),
    );
  }
}
