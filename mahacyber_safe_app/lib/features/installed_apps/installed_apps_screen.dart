import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/device_insight_service.dart';
import '../../core/theme/app_theme.dart';
import 'app_detail_screen.dart';

class InstalledAppsScreen extends StatefulWidget {
  const InstalledAppsScreen({super.key});

  @override
  State<InstalledAppsScreen> createState() => _InstalledAppsScreenState();
}

enum _SortMode { riskDesc, nameAsc, recentInstall }

class _InstalledAppsScreenState extends State<InstalledAppsScreen> {
  final _service = DeviceInsightService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<_Row> _all = const [];
  bool _riskyOnly = false;
  bool _includeSystem = false;
  String _permFilter = '';
  _SortMode _sort = _SortMode.riskDesc;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apps = await _service.listInstalledApps(includeIcons: true);
      final rows = apps
          .map((a) => _Row(a: a, score: AppRiskScore.compute(a)))
          .toList();
      if (!mounted) return;
      setState(() {
        _all = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not enumerate apps: $e';
      });
    }
  }

  List<_Row> get _visible {
    final q = _searchCtrl.text.trim().toLowerCase();
    var list = _all.where((r) {
      if (!_includeSystem && r.a.isSystem) return false;
      if (_riskyOnly && r.score.level != RiskLevel.high) return false;
      if (_permFilter.isNotEmpty &&
          !r.a.grantedPermissions
              .any((p) => p.toLowerCase().contains(_permFilter.toLowerCase()))) {
        return false;
      }
      if (q.isNotEmpty &&
          !(r.a.appName.toLowerCase().contains(q) ||
              r.a.packageName.toLowerCase().contains(q))) return false;
      return true;
    }).toList();

    switch (_sort) {
      case _SortMode.riskDesc:
        list.sort((a, b) => b.score.score.compareTo(a.score.score));
        break;
      case _SortMode.nameAsc:
        list.sort((a, b) => a.a.appName.toLowerCase().compareTo(b.a.appName.toLowerCase()));
        break;
      case _SortMode.recentInstall:
        list.sort((a, b) => b.a.firstInstall.compareTo(a.a.firstInstall));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Installed apps'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _buildList(),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final list = _visible;
    final totalRisky = _all.where((r) => r.score.level == RiskLevel.high).length;

    return Column(
      children: [
        Container(
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search app name or package',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: Text('Risky only ($totalRisky)'),
                            selected: _riskyOnly,
                            onSelected: (v) => setState(() => _riskyOnly = v),
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('Include system apps'),
                            selected: _includeSystem,
                            onSelected: (v) => setState(() => _includeSystem = v),
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: Text('Permission: ${_permFilter.isEmpty ? "any" : _permFilter}'),
                            avatar: const Icon(Icons.filter_list, size: 18),
                            onPressed: _pickPermissionFilter,
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<_SortMode>(
                    icon: const Icon(Icons.sort),
                    onSelected: (m) => setState(() => _sort = m),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: _SortMode.riskDesc, child: Text('Risk (high → low)')),
                      PopupMenuItem(value: _SortMode.nameAsc, child: Text('Name (A → Z)')),
                      PopupMenuItem(value: _SortMode.recentInstall, child: Text('Recently installed')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('No apps match these filters.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _AppTile(
                    row: list[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AppDetailScreen(app: list[i].a, score: list[i].score),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  void _pickPermissionFilter() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Filter by permission'),
        children: [
          for (final entry in const [
            ['(any)', ''],
            ['CAMERA', 'CAMERA'],
            ['MICROPHONE', 'RECORD_AUDIO'],
            ['LOCATION', 'LOCATION'],
            ['READ_SMS', 'READ_SMS'],
            ['READ_CONTACTS', 'READ_CONTACTS'],
            ['CALL_PHONE', 'CALL_PHONE'],
            ['ACCESSIBILITY', 'ACCESSIBILITY'],
            ['DEVICE_ADMIN', 'DEVICE_ADMIN'],
            ['INSTALL_PACKAGES', 'INSTALL_PACKAGES'],
            ['SYSTEM_ALERT', 'SYSTEM_ALERT'],
          ])
            SimpleDialogOption(
              child: Text(entry[0]),
              onPressed: () => Navigator.of(context).pop(entry[1]),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _permFilter = picked);
  }
}

class _Row {
  _Row({required this.a, required this.score});
  final AppInfo a;
  final AppRiskScore score;
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.row, required this.onTap});
  final _Row row;
  final VoidCallback onTap;

  Color _colorFor(RiskLevel r) {
    switch (r) {
      case RiskLevel.high: return AppColors.danger;
      case RiskLevel.medium: return AppColors.warning;
      case RiskLevel.low: return AppColors.safe;
      default: return AppColors.textSecondary;
    }
  }

  String _labelFor(RiskLevel r) {
    switch (r) {
      case RiskLevel.high: return 'HIGH RISK';
      case RiskLevel.medium: return 'MEDIUM';
      case RiskLevel.low: return 'LOW';
      default: return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    final c = _colorFor(row.score.level);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _icon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.a.appName,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: c.withOpacity(0.3)),
                            ),
                            child: Text(_labelFor(row.score.level),
                                style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.a.packageName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6, runSpacing: 4,
                        children: [
                          _pill(Icons.warning_amber_rounded, '${row.score.high} high', AppColors.danger),
                          _pill(Icons.shield_outlined, '${row.score.medium} med', AppColors.warning),
                          _pill(Icons.check, '${row.score.low} low', AppColors.safe),
                          if (!row.a.hasLauncher)
                            _pill(Icons.visibility_off_outlined, 'No launcher', AppColors.danger),
                          if (!row.a.isFromPlayStore && !row.a.isSystem)
                            _pill(Icons.download_outlined, 'Sideloaded', AppColors.warning),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Installed ${df.format(row.a.firstInstall)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _icon() {
    if (row.a.iconPng != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(row.a.iconPng!, width: 44, height: 44, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.android, color: AppColors.primary),
    );
  }

  Widget _pill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
