import 'package:flutter/material.dart';

import '../../core/services/device_insight_service.dart';
import '../../core/theme/app_theme.dart';
import 'adware_scanner_service.dart';

class AdwareScannerScreen extends StatefulWidget {
  const AdwareScannerScreen({super.key});

  @override
  State<AdwareScannerScreen> createState() => _AdwareScannerScreenState();
}

enum _Filter { all, riskyOnly, sideloadedOnly }

class _AdwareScannerScreenState extends State<AdwareScannerScreen> {
  final _service = AdwareScannerService();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<_Row> _all = const [];
  bool _includeSystem = false;
  _Filter _filter = _Filter.riskyOnly;

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
      final signals = await _service.scan();
      final rows = signals
          .map((s) => _Row(s: s, score: AdwareScore.compute(s)))
          .toList()
        ..sort((a, b) => b.score.score.compareTo(a.score.score));
      if (!mounted) return;
      setState(() {
        _all = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<_Row> get _visible {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _all.where((r) {
      if (!_includeSystem && r.s.isSystem) return false;
      switch (_filter) {
        case _Filter.riskyOnly:
          if (r.score.level == AdwareRisk.clean ||
              r.score.level == AdwareRisk.low) return false;
          break;
        case _Filter.sideloadedOnly:
          if (r.s.isFromPlayStore) return false;
          break;
        case _Filter.all:
          break;
      }
      if (q.isEmpty) return true;
      return r.s.appName.toLowerCase().contains(q) ||
          r.s.packageName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final high = _all.where((r) => r.score.level == AdwareRisk.high).length;
    final med = _all.where((r) => r.score.level == AdwareRisk.medium).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adware Scanner'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.danger),
                        const SizedBox(height: 8),
                        Text('Scan failed: $_error',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    _SummaryCard(high: high, medium: med, total: _all.length),
                    _Controls(
                      controller: _searchCtrl,
                      filter: _filter,
                      includeSystem: _includeSystem,
                      onFilter: (f) => setState(() => _filter = f),
                      onSystem: (v) => setState(() => _includeSystem = v),
                      onSearch: () => setState(() {}),
                    ),
                    Expanded(
                      child: _visible.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No matching apps. Try toggling "Include system apps" or switching to All.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _visible.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, indent: 72, endIndent: 16),
                              itemBuilder: (_, i) => _AppTile(
                                row: _visible[i],
                                onTap: () => _showDetail(_visible[i]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  void _showDetail(_Row row) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DetailSheet(
        row: row,
        onUninstall: () async {
          Navigator.of(context).pop();
          await DeviceInsightService().uninstallApp(row.s.packageName);
        },
        onSettings: () async {
          Navigator.of(context).pop();
          await DeviceInsightService().openAppSettings(row.s.packageName);
        },
      ),
    );
  }
}

class _Row {
  _Row({required this.s, required this.score});
  final AdwareSignals s;
  final AdwareScore score;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.high, required this.medium, required this.total});
  final int high;
  final int medium;
  final int total;

  @override
  Widget build(BuildContext context) {
    final color = high > 0
        ? AppColors.danger
        : medium > 0
            ? AppColors.warning
            : AppColors.safe;
    final headline = high > 0
        ? '$high high-risk app${high == 1 ? '' : 's'} found'
        : medium > 0
            ? '$medium suspicious app${medium == 1 ? '' : 's'}'
            : 'No adware-like apps detected';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            high > 0
                ? Icons.warning_amber_rounded
                : medium > 0
                    ? Icons.info_outline
                    : Icons.verified_user_outlined,
            color: color,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'Scanned $total app${total == 1 ? '' : 's'} for known ad-network '
                  'SDKs, overlay abuse and auto-start patterns.',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.filter,
    required this.includeSystem,
    required this.onFilter,
    required this.onSystem,
    required this.onSearch,
  });

  final TextEditingController controller;
  final _Filter filter;
  final bool includeSystem;
  final ValueChanged<_Filter> onFilter;
  final ValueChanged<bool> onSystem;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: (_) => onSearch(),
            decoration: const InputDecoration(
              hintText: 'Search app name or package',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Risky only'),
                  selected: filter == _Filter.riskyOnly,
                  onSelected: (_) => onFilter(_Filter.riskyOnly),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Sideloaded'),
                  selected: filter == _Filter.sideloadedOnly,
                  onSelected: (_) => onFilter(_Filter.sideloadedOnly),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('All apps'),
                  selected: filter == _Filter.all,
                  onSelected: (_) => onFilter(_Filter.all),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: const Text('Include system'),
                  selected: includeSystem,
                  onSelected: onSystem,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.row, required this.onTap});
  final _Row row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(row.score.level);
    final subtitle = <String>[
      if (row.s.adSdkCount > 0)
        '${row.s.adSdkCount} ad-SDK${row.s.adSdkCount == 1 ? '' : 's'}',
      if (row.s.hasOverlayGranted) 'Overlay granted',
      if (row.s.declaresAccessibility) 'Accessibility',
      if (!row.s.isFromPlayStore && !row.s.isSystem) 'Sideloaded',
    ].join(' · ');

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(
          row.score.level == AdwareRisk.clean
              ? Icons.verified
              : Icons.adb_rounded,
          color: color,
        ),
      ),
      title: Text(row.s.appName,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle.isEmpty ? row.s.packageName : subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${row.score.score}',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Color _colorFor(AdwareRisk r) => switch (r) {
        AdwareRisk.high => AppColors.danger,
        AdwareRisk.medium => AppColors.warning,
        AdwareRisk.low => AppColors.primary,
        AdwareRisk.clean => AppColors.safe,
      };
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({
    required this.row,
    required this.onUninstall,
    required this.onSettings,
  });
  final _Row row;
  final VoidCallback onUninstall;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final color = switch (row.score.level) {
      AdwareRisk.high => AppColors.danger,
      AdwareRisk.medium => AppColors.warning,
      AdwareRisk.low => AppColors.primary,
      AdwareRisk.clean => AppColors.safe,
    };
    final levelLabel = switch (row.score.level) {
      AdwareRisk.high => 'High adware risk',
      AdwareRisk.medium => 'Suspicious',
      AdwareRisk.low => 'Low risk',
      AdwareRisk.clean => 'Clean',
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.adb_rounded, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(row.s.appName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                Text(
                  levelLabel,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(row.s.packageName,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 14),
            if (row.score.reasons.isEmpty)
              const Text('No adware-style behaviour detected for this app.'),
            ...row.score.reasons.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.adjust, size: 14, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ),
            if (row.s.adSdkMatches.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Matched ad-network SDKs',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: row.s.adSdkMatches
                    .map((m) => Chip(
                          label: Text(m, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Settings'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger),
                    onPressed: onUninstall,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Uninstall'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
