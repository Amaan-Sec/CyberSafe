import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/services/backend_client.dart';
import '../../core/services/url_safety_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/speak_button.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  String? _payload;
  UrlAnalysis? _analysis;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_payload != null) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;

    setState(() {
      _payload = value;
      _analysis = null;
    });
    _controller.stop();

    final isUrlLike = value.startsWith('http') ||
        (value.contains('.') && !value.contains(' '));
    if (isUrlLike) {
      // kind: 'qr' tells the backend to count this in the QR-scans bucket
      // rather than the URL-scans bucket (admin Scan Analytics).
      UrlSafetyService.analyse(value, kind: 'qr').then((a) {
        if (!mounted) return;
        setState(() => _analysis = a);
      });
    } else {
      // Non-URL QR payload (vCard, WiFi config, plain text) — still counted
      // as a QR scan so analytics reflect actual usage.
      BackendClient().recordScan(
        kind: 'qr',
        verdict: 'unknown',
        target: value.length > 120 ? value.substring(0, 120) : value,
      );
    }
  }

  void _resume() {
    setState(() {
      _payload = null;
      _analysis = null;
    });
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR'),
        actions: [
          IconButton(
            tooltip: 'Toggle torch',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Switch camera',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_payload != null) _ResultSheet(
            payload: _payload!,
            analysis: _analysis,
            onScanAgain: _resume,
          ),
        ],
      ),
    );
  }
}

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({
    required this.payload,
    required this.analysis,
    required this.onScanAgain,
  });

  final String payload;
  final UrlAnalysis? analysis;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final verdictColor = switch (analysis?.verdict) {
      UrlVerdict.safe => AppColors.safe,
      UrlVerdict.suspicious => AppColors.warning,
      UrlVerdict.malicious => AppColors.danger,
      _ => AppColors.primary,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code, color: verdictColor),
                const SizedBox(width: 8),
                Text(
                  analysis == null
                      ? 'QR contents'
                      : switch (analysis!.verdict) {
                          UrlVerdict.safe => 'Looks safe',
                          UrlVerdict.suspicious => 'Suspicious link',
                          UrlVerdict.malicious => 'Likely malicious',
                        },
                  style: TextStyle(
                    color: verdictColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              payload,
              style: const TextStyle(fontSize: 13),
            ),
            if (analysis != null && analysis!.reasons.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...analysis!.reasons.map(
                (r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $r'),
                ),
              ),
            ],
            const SizedBox(height: 10),
            SpeakButton(
              text: () {
                final parts = <String>[];
                if (analysis != null) {
                  switch (analysis!.verdict) {
                    case UrlVerdict.safe: parts.add('Looks safe.'); break;
                    case UrlVerdict.suspicious: parts.add('Suspicious link.'); break;
                    case UrlVerdict.malicious: parts.add('Likely malicious.'); break;
                  }
                  if (analysis!.reasons.isNotEmpty) parts.add('Findings: ${analysis!.reasons.join('. ')}.');
                } else {
                  parts.add('QR contents.');
                }
                parts.add(payload);
                return parts.join(' ');
              }(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onScanAgain,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan another'),
            ),
          ],
        ),
      ),
    );
  }
}
