import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/device_insight_service.dart';
import '../../core/theme/app_theme.dart';

class AppDetailScreen extends StatelessWidget {
  const AppDetailScreen({super.key, required this.app, required this.score});

  final AppInfo app;
  final AppRiskScore score;

  Color _colorFor(RiskLevel r) {
    switch (r) {
      case RiskLevel.high: return AppColors.danger;
      case RiskLevel.medium: return AppColors.warning;
      case RiskLevel.low: return AppColors.safe;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy, HH:mm');
    final svc = DeviceInsightService();
    // Group granted permissions by risk
    final byRisk = <RiskLevel, List<MapEntry<String, PermissionRisk>>>{
      RiskLevel.high: [], RiskLevel.medium: [], RiskLevel.low: [], RiskLevel.unknown: [],
    };
    for (final p in app.grantedPermissions) {
      final r = PermissionCatalog.classify(p);
      byRisk[r.risk]!.add(MapEntry(p, r));
    }
    final levelColor = _colorFor(score.level);

    return Scaffold(
      appBar: AppBar(
        title: Text(app.appName, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _icon(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.appName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                        const SizedBox(height: 2),
                        Text(app.packageName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('v${app.versionName} · target SDK ${app.targetSdk}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: levelColor.withOpacity(0.3), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: levelColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: levelColor.withOpacity(0.3)),
                        ),
                        alignment: Alignment.center,
                        child: Text('${score.score}',
                            style: TextStyle(color: levelColor, fontSize: 22, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              score.level == RiskLevel.high
                                  ? 'High risk app'
                                  : score.level == RiskLevel.medium
                                      ? 'Medium risk app'
                                      : 'Low risk app',
                              style: TextStyle(color: levelColor, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text('${score.high} high · ${score.medium} medium · ${score.low} low · ${score.unknown} unknown permissions granted',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (score.level == RiskLevel.high || !app.hasLauncher || (!app.isFromPlayStore && !app.isSystem)) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    const Text('Recommended actions', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    if (score.high > 0)
                      _recItem('Revoke unused high-risk permissions',
                          'Open app settings → Permissions, deny anything this app does not genuinely need.'),
                    if (!app.hasLauncher && !app.isSystem)
                      _recItem('This app has no launcher icon',
                          'A hidden icon is a common sign of stalkerware or aggressive ads. Uninstall if you do not recognise it.'),
                    if (!app.isFromPlayStore && !app.isSystem)
                      _recItem('Installed outside Play Store',
                          'This app was sideloaded. Verify the source — Play Protect cannot vouch for it.'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => svc.openAppSettings(app.packageName),
                            icon: const Icon(Icons.settings),
                            label: const Text('App settings'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Uninstall app?'),
                                  content: Text('Open the system uninstall flow for ${app.appName}?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Uninstall'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) await svc.uninstallApp(app.packageName);
                            },
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('Uninstall'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => svc.openAppSettings(app.packageName),
                      icon: const Icon(Icons.settings),
                      label: const Text('Open app settings'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _metaCard(df),
          const SizedBox(height: 16),
          if (byRisk[RiskLevel.high]!.isNotEmpty)
            _permSection('High-risk permissions granted', byRisk[RiskLevel.high]!, AppColors.danger),
          if (byRisk[RiskLevel.medium]!.isNotEmpty)
            _permSection('Medium-risk permissions granted', byRisk[RiskLevel.medium]!, AppColors.warning),
          if (byRisk[RiskLevel.low]!.isNotEmpty)
            _permSection('Low-risk permissions granted', byRisk[RiskLevel.low]!, AppColors.safe),
          if (byRisk[RiskLevel.unknown]!.isNotEmpty)
            _permSection('Other permissions', byRisk[RiskLevel.unknown]!, AppColors.textSecondary),
          const SizedBox(height: 16),
          _allRequestedCard(),
        ],
      ),
    );
  }

  Widget _icon() {
    if (app.iconPng != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(app.iconPng!, width: 56, height: 56, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.android, color: AppColors.primary, size: 30),
    );
  }

  Widget _metaCard(DateFormat df) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Install info', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _kv('Installed', df.format(app.firstInstall)),
            _kv('Last updated', df.format(app.lastUpdate)),
            _kv('Installer', app.installer ?? '(unknown)'),
            _kv('From Play Store', app.isFromPlayStore ? 'Yes' : 'No'),
            _kv('System app', app.isSystem ? 'Yes' : 'No'),
            _kv('Launcher icon', app.hasLauncher ? 'Yes' : 'No (hidden)'),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(k, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _permSection(String title, List<MapEntry<String, PermissionRisk>> items, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                const Spacer(),
                Text('${items.length}', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.value.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(e.value.reason, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(e.key, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _allRequestedCard() {
    final notGranted = app.permissions.where((p) => !app.grantedPermissions.contains(p)).toList();
    if (notGranted.isEmpty) return const SizedBox.shrink();
    return Card(
      child: ExpansionTile(
        title: const Text('Requested but not granted'),
        subtitle: Text('${notGranted.length} permissions', style: const TextStyle(color: AppColors.textSecondary)),
        children: notGranted.map((p) {
          final r = PermissionCatalog.classify(p);
          return ListTile(
            dense: true,
            title: Text(r.label),
            subtitle: Text(p, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          );
        }).toList(),
      ),
    );
  }

  Widget _recItem(String title, String body) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right, size: 18, color: AppColors.danger),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(body, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
