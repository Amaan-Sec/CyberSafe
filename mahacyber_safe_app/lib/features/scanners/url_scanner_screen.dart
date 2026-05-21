import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/language_picker.dart';
import '../../core/services/url_safety_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/speak_button.dart';

class UrlScannerScreen extends StatefulWidget {
  const UrlScannerScreen({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  State<UrlScannerScreen> createState() => _UrlScannerScreenState();
}

class _UrlScannerScreenState extends State<UrlScannerScreen> {
  late final TextEditingController _ctrl;
  UrlAnalysis? _result;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialUrl ?? '');
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _check();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final input = _ctrl.text.trim();
    if (input.isEmpty) return;
    setState(() {
      _loading = true;
      _result = null;
    });
    final r = await UrlSafetyService.analyse(input);
    if (!mounted) return;
    setState(() {
      _result = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check URL'),
        actions: const [LanguagePicker()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL to scan',
                hintText: 'e.g. https://example.com',
                prefixIcon: Icon(Icons.link),
              ),
              onSubmitted: (_) => _check(),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _loading ? null : _check,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : const Icon(Icons.search),
              label: Text(_loading ? 'Checking…' : 'Analyse'),
            ),
            const SizedBox(height: 24),
            if (_result != null) _VerdictCard(result: _result!),
          ],
        ),
      ),
    );
  }
}

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.result});

  final UrlAnalysis result;

  String _ttsText(String label, UrlAnalysis r) {
    final parts = <String>[label, r.normalised];
    if (r.reasons.isNotEmpty) {
      parts.add('Findings: ${r.reasons.join('. ')}.');
    } else {
      parts.add('No suspicious patterns detected. Always remain alert.');
    }
    return parts.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (result.verdict) {
      UrlVerdict.safe => (
          AppColors.safe,
          Icons.verified,
          'Looks safe',
        ),
      UrlVerdict.suspicious => (
          AppColors.warning,
          Icons.warning_amber_rounded,
          'Suspicious',
        ),
      UrlVerdict.malicious => (
          AppColors.danger,
          Icons.dangerous,
          'Likely malicious',
        ),
    };

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SpeakButton(
                  compact: true,
                  text: _ttsText(label, result),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              result.normalised,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (result.reasons.isEmpty)
              const Text(
                'No suspicious patterns detected by our heuristics. Always remain alert.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else ...[
              const Text(
                'Findings:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ...result.reasons.map(
                (r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(r)),
                    ],
                  ),
                ),
              ),
            ],
            if (result.sources.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Sources consulted:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...result.sources.map(
                (s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    '· $s',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (result.verdict == UrlVerdict.safe)
              OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(result.normalised);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open URL'),
              ),
          ],
        ),
      ),
    );
  }
}
