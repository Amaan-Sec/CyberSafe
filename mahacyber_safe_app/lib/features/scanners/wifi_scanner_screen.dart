import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../../core/i18n/language_picker.dart';
import '../../core/services/backend_client.dart';
import '../../core/services/wifi_risk_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/speak_button.dart';

class WifiScannerScreen extends StatefulWidget {
  const WifiScannerScreen({super.key});

  @override
  State<WifiScannerScreen> createState() => _WifiScannerScreenState();
}

class _WifiScannerScreenState extends State<WifiScannerScreen> {
  final NetworkInfo _info = NetworkInfo();

  bool _loading = false;
  String? _error;
  Map<String, String?> _connected = {};
  List<AccessPointLite> _aps = const [];
  Set<String> _sharedSsids = const {};
  Set<String> _conflictingSsids = const {};

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Both location and wifi-state permissions are needed on Android for SSIDs
    // and scan results.
    final loc = await Permission.locationWhenInUse.request();
    if (!loc.isGranted) {
      setState(() {
        _loading = false;
        _error = 'Location permission is needed on Android to read Wi-Fi details.';
      });
      return;
    }

    try {
      // Connected network details
      final connected = await Future.wait([
        _info.getWifiName(),
        _info.getWifiBSSID(),
        _info.getWifiIP(),
        _info.getWifiGatewayIP(),
        _info.getWifiSubmask(),
      ]);

      // Available networks via WifiManager
      final can = await WiFiScan.instance.canStartScan(askPermissions: true);
      List<AccessPointLite> aps = const [];
      if (can == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
        final canGet = await WiFiScan.instance.canGetScannedResults(askPermissions: true);
        if (canGet == CanGetScannedResults.yes) {
          final raw = await WiFiScan.instance.getScannedResults();
          aps = raw
              .where((r) => r.ssid.trim().isNotEmpty)
              .map((r) => AccessPointLite(
                    ssid: r.ssid,
                    bssid: r.bssid,
                    signalDbm: r.level,
                    frequencyMhz: r.frequency,
                    capabilities: r.capabilities,
                    classification: WifiRiskService.classify(r.capabilities),
                  ))
              .toList()
            ..sort((a, b) => b.signalDbm.compareTo(a.signalDbm));
        }
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _connected = {
          'SSID': connected[0]?.replaceAll('"', ''),
          'BSSID': connected[1],
          'IP address': connected[2],
          'Gateway': connected[3],
          'Subnet mask': connected[4],
        };
        _aps = aps;
        _sharedSsids = WifiRiskService.evilTwinSsids(aps);
        _conflictingSsids = WifiRiskService.conflictingEncryptionSsids(aps);
      });

      // Record one scan event tagged with the worst risk seen this sweep,
      // so admin analytics show real Wi-Fi scan counts.
      if (aps.isNotEmpty) {
        final hasHigh = aps.any((a) => a.classification.risk == WifiRisk.high) ||
            _conflictingSsids.isNotEmpty;
        final hasMed = aps.any((a) => a.classification.risk == WifiRisk.medium);
        final verdict = hasHigh
            ? 'malicious'
            : hasMed
                ? 'suspicious'
                : 'safe';
        BackendClient().recordScan(
          kind: 'wifi',
          verdict: verdict,
          target: (_connected['SSID'] ?? '').isNotEmpty
              ? _connected['SSID']!
              : '${aps.length} APs',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to read Wi-Fi: $e';
      });
    }
  }

  AccessPointLite? _matchConnectedAp() {
    final bssid = (_connected['BSSID'] ?? '').toLowerCase();
    if (bssid.isEmpty) return null;
    for (final ap in _aps) {
      if (ap.bssid.toLowerCase() == bssid) return ap;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi safety'),
        actions: [
          const LanguagePicker(),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _scan),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _scan,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildConnectedCard(),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Card(
                      color: const Color(0xFFFDECEA),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                      ),
                    ),
                  if (_conflictingSsids.isNotEmpty) _evilTwinBanner(),
                  const SizedBox(height: 16),
                  _availableHeader(),
                  const SizedBox(height: 8),
                  if (_aps.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          'No nearby networks visible. On Android 10+ scan rates are throttled — wait a moment and refresh.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ..._aps.map((ap) => _ApRow(
                          ap: ap,
                          isConnected: ap.bssid.toLowerCase() == (_connected['BSSID'] ?? '').toLowerCase(),
                          sharedSsid: _sharedSsids.contains(ap.ssid),
                          conflictingEnc: _conflictingSsids.contains(ap.ssid),
                          defaultName: WifiRiskService.isLikelyDefaultSsid(ap.ssid),
                        )),
                ],
              ),
            ),
    );
  }

  Widget _buildConnectedCard() {
    final ssid = (_connected['SSID'] ?? '').trim();
    final bssid = _connected['BSSID'] ?? '';
    final connectedAp = _matchConnectedAp();

    if (ssid.isEmpty || bssid.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.wifi_off, color: AppColors.textSecondary, size: 28),
              SizedBox(width: 12),
              Expanded(child: Text('Not connected to Wi-Fi. Connect first to see encryption details.')),
            ],
          ),
        ),
      );
    }

    final classification = connectedAp?.classification;
    final defaultName = WifiRiskService.isLikelyDefaultSsid(ssid);
    final sharedSsid = _sharedSsids.contains(ssid);
    final conflictingEnc = _conflictingSsids.contains(ssid);

    final overall = WifiRiskService.overallRisk(
      encryptionRisk: classification?.risk ?? WifiRisk.unknown,
      defaultSsid: defaultName,
      sharedSsid: sharedSsid,
      conflictingEnc: conflictingEnc,
    );
    final color = _colorFor(overall);

    final speech = StringBuffer()
      ..write('Connected to $ssid. ')
      ..write('Encryption: ${classification?.label ?? "unknown"}. ')
      ..write('Risk level: ${_levelLabel(overall)}. ');
    if (conflictingEnc) speech.write('Warning: another nearby network with the same name uses different encryption — possible evil twin. ');
    if (defaultName) speech.write('Warning: this SSID looks like a factory-default router name — change the admin password if you own this router. ');

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.35), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi, color: color, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ssid,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      Text('Connected · ${_levelLabel(overall)} risk',
                          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                ),
                SpeakButton(compact: true, text: speech.toString()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _encChip(classification),
                const SizedBox(width: 6),
                if (defaultName) _warnChip('Default name'),
                if (defaultName) const SizedBox(width: 6),
                if (conflictingEnc) _warnChip('Evil-twin'),
                if (conflictingEnc) const SizedBox(width: 6),
                if (sharedSsid && !conflictingEnc) _infoChip('Multiple APs'),
              ],
            ),
            const SizedBox(height: 12),
            _row('SSID', ssid),
            _row('BSSID', bssid),
            _row('IP address', _connected['IP address'] ?? '—'),
            _row('Gateway', _connected['Gateway'] ?? '—'),
            _row('Subnet mask', _connected['Subnet mask'] ?? '—'),
            if (connectedAp != null) ...[
              _row('Signal', '${connectedAp.signalDbm} dBm · ${connectedAp.signalBars}/4 bars'),
              _row('Band', connectedAp.band),
              _row('Encryption', classification?.label ?? 'unknown'),
            ],
            if (classification != null && classification.risk != WifiRisk.low) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(classification.reason, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _evilTwinBanner() {
    final names = _conflictingSsids.join(', ');
    return Card(
      color: const Color(0xFFFDECEA),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Possible evil-twin networks detected',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger)),
                  const SizedBox(height: 4),
                  Text('Multiple access points are broadcasting "$names" with different encryption types. An attacker may be impersonating a familiar network. Verify with the venue before connecting.',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _availableHeader() {
    return Row(
      children: [
        const Icon(Icons.podcasts, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          'Available networks (${_aps.length})',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _encChip(WifiClassification? c) {
    final color = c == null
        ? AppColors.textSecondary
        : _colorFor(c.risk);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(c?.shortBadge ?? '?',
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }

  Widget _warnChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Text(label,
          style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 10)),
    );
  }

  Widget _infoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 10)),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          Expanded(child: SelectableText(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Color _colorFor(WifiRisk r) {
    switch (r) {
      case WifiRisk.low: return AppColors.safe;
      case WifiRisk.medium: return AppColors.warning;
      case WifiRisk.high: return AppColors.danger;
      default: return AppColors.textSecondary;
    }
  }

  String _levelLabel(WifiRisk r) {
    switch (r) {
      case WifiRisk.low: return 'LOW';
      case WifiRisk.medium: return 'MEDIUM';
      case WifiRisk.high: return 'HIGH';
      default: return 'UNKNOWN';
    }
  }
}

class _ApRow extends StatelessWidget {
  const _ApRow({
    required this.ap,
    required this.isConnected,
    required this.sharedSsid,
    required this.conflictingEnc,
    required this.defaultName,
  });

  final AccessPointLite ap;
  final bool isConnected;
  final bool sharedSsid;
  final bool conflictingEnc;
  final bool defaultName;

  @override
  Widget build(BuildContext context) {
    final overall = WifiRiskService.overallRisk(
      encryptionRisk: ap.classification.risk,
      defaultSsid: defaultName,
      sharedSsid: sharedSsid,
      conflictingEnc: conflictingEnc,
    );
    final color = _colorFor(overall);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isConnected
              ? BorderSide(color: AppColors.primary.withOpacity(0.5), width: 1.5)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _signalIcon(ap.signalBars, color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ap.ssid,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isConnected) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.link, size: 14, color: AppColors.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${ap.bssid.toLowerCase()} · ${ap.band} · ${ap.signalDbm} dBm',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontFamily: 'monospace')),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5, runSpacing: 4,
                      children: [
                        _chip(ap.classification.shortBadge, _colorFor(ap.classification.risk)),
                        _chip(_levelLabel(overall), color, filled: true),
                        if (conflictingEnc) _chip('EVIL-TWIN', AppColors.danger, filled: true),
                        if (defaultName) _chip('Default name', AppColors.warning),
                        if (sharedSsid && !conflictingEnc) _chip('Multi-AP', AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _signalIcon(int bars, Color color) {
    IconData icon;
    switch (bars) {
      case 4: icon = Icons.signal_wifi_4_bar; break;
      case 3: icon = Icons.network_wifi_3_bar; break;
      case 2: icon = Icons.network_wifi_2_bar; break;
      case 1: icon = Icons.network_wifi_1_bar; break;
      default: icon = Icons.signal_wifi_0_bar;
    }
    return Icon(icon, color: color, size: 28);
  }

  Widget _chip(String label, Color color, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? color : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
        border: filled ? null : Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
            color: filled ? Colors.white : color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          )),
    );
  }

  Color _colorFor(WifiRisk r) {
    switch (r) {
      case WifiRisk.low: return AppColors.safe;
      case WifiRisk.medium: return AppColors.warning;
      case WifiRisk.high: return AppColors.danger;
      default: return AppColors.textSecondary;
    }
  }

  String _levelLabel(WifiRisk r) {
    switch (r) {
      case WifiRisk.low: return 'LOW';
      case WifiRisk.medium: return 'MEDIUM';
      case WifiRisk.high: return 'HIGH';
      default: return 'UNKNOWN';
    }
  }
}
