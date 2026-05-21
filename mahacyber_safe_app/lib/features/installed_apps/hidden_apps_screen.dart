import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/device_insight_service.dart';
import '../../core/theme/app_theme.dart';
import 'app_detail_screen.dart';

class HiddenAppsScreen extends StatefulWidget {
  const HiddenAppsScreen({super.key});

  @override
  State<HiddenAppsScreen> createState() => _HiddenAppsScreenState();
}

class _HiddenAppsScreenState extends State<HiddenAppsScreen>
    with SingleTickerProviderStateMixin {
  final _svc = DeviceInsightService();
  bool _loading = true;
  String? _error;
  List<AppInfo> _all = const [];
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apps = await _svc.listInstalledApps(includeIcons: true);
      if (!mounted) return;
      setState(() {
        _all = apps;
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

  List<AppInfo> get _hidden =>
      _all.where((a) => a.isLikelyHidden && !a.isSystem).toList();

  List<AppInfo> get _sideloaded =>
      _all.where((a) => !a.isSystem && !a.isFromPlayStore).toList();

  List<AppInfo> get _misleading =>
      _all.where((a) => !a.isSystem && a.hasSuspiciousName).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hidden / risky apps'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: [
            Tab(text: 'Hidden (${_hidden.length})'),
            Tab(text: 'Sideloaded (${_sideloaded.length})'),
            Tab(text: 'Suspicious (${_misleading.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : TabBarView(
                  controller: _tab,
                  children: [
                    _list(_hidden, _hiddenBlurb),
                    _list(_sideloaded, _sideloadedBlurb),
                    _list(_misleading, _misleadingBlurb),
                  ],
                ),
    );
  }

  static const _hiddenBlurb =
      'These apps do not show a launcher icon on your home screen. Some are legitimate (background services), but stalkerware and aggressive ad-loaders also hide this way.';
  static const _sideloadedBlurb =
      'These apps were installed from outside the Play Store. They have not been scanned by Play Protect. Verify the source before trusting them.';
  static const _misleadingBlurb =
      'Apps whose name matches common scam patterns (fake "System Update", "KYC verify", etc). Review carefully.';

  Widget _list(List<AppInfo> list, String blurb) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.safe, size: 48),
            const SizedBox(height: 12),
            const Text('Nothing here — good.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(blurb, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(blurb, style: const TextStyle(fontSize: 12))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...list.map((a) => _row(a)),
      ],
    );
  }

  Widget _row(AppInfo a) {
    final score = AppRiskScore.compute(a);
    final df = DateFormat('dd MMM yyyy');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AppDetailScreen(app: a, score: score)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _icon(a),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.appName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(a.packageName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('Installed ${df.format(a.firstInstall)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text('Installer: ${a.installer ?? "unknown"}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text('${score.high} high · ${score.medium} med · ${score.low} low permissions granted',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                tooltip: 'Uninstall',
                onPressed: () => _svc.uninstallApp(a.packageName),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon(AppInfo a) {
    if (a.iconPng != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(a.iconPng!, width: 40, height: 40, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.visibility_off_outlined, color: AppColors.danger),
    );
  }
}
