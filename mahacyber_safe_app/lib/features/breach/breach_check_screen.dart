import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/i18n/language_picker.dart';
import '../../core/services/backend_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/speak_button.dart';

class BreachCheckScreen extends StatefulWidget {
  const BreachCheckScreen({super.key});

  @override
  State<BreachCheckScreen> createState() => _BreachCheckScreenState();
}

class _BreachCheckScreenState extends State<BreachCheckScreen> {
  static const String _endpoint = 'http://164.52.194.98:8000/api/breach';

  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  _BreachResult? _result;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final email = _ctrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });

    try {
      final ident = await BackendClient().identityFields();
      final resp = await http
          .post(
            Uri.parse(_endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, ...ident}),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        throw Exception('Server returned HTTP ${resp.statusCode}');
      }
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      if (j['ok'] != true) {
        throw Exception(j['error'] ?? 'Unknown error');
      }
      final breaches = ((j['breaches'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_Breach.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = _BreachResult(
          email: email,
          breaches: breaches,
          source: (j['source'] ?? 'XposedOrNot') as String,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not check breaches: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email breach check'),
        actions: const [LanguagePicker()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Check whether your email address has appeared in known data breaches. We query XposedOrNot — your email is sent over HTTPS to their public API.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline),
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : const Icon(Icons.search),
              label: Text(_loading ? 'Checking…' : 'Check breaches'),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.warning),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!)),
                    ],
                  ),
                ),
              ),
            if (_result != null) _ResultSection(result: _result!),
          ],
        ),
      ),
    );
  }
}

class _BreachResult {
  const _BreachResult({required this.email, required this.breaches, required this.source});
  final String email;
  final List<_Breach> breaches;
  final String source;
}

class _Breach {
  const _Breach({
    required this.name,
    required this.date,
    required this.records,
    required this.data,
    required this.description,
    required this.industry,
  });

  final String name;
  final String date;
  final int records;
  final String data;
  final String description;
  final String industry;

  factory _Breach.fromJson(Map<String, dynamic> j) => _Breach(
        name: (j['name'] ?? '') as String,
        date: (j['date'] ?? '') as String,
        records: (j['records'] is num) ? (j['records'] as num).toInt() : 0,
        data: (j['data'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        industry: (j['industry'] ?? '') as String,
      );
}

String _summariseBreachesForSpeech(_BreachResult r) {
  final names = r.breaches.take(5).map((b) {
    if (b.date.isNotEmpty) return '${b.name} ${b.date}';
    return b.name;
  }).join(', ');
  final tail = r.breaches.length > 5 ? ' and ${r.breaches.length - 5} more.' : '.';
  return 'Warning. ${r.breaches.length} breaches found for this email address. '
      'Top breaches: $names$tail '
      'Recommended actions: change the password on each affected service, never reuse passwords, '
      'and enable two factor authentication wherever available.';
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.result});
  final _BreachResult result;

  String _formatRecords(int n) {
    if (n <= 0) return '';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M records';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K records';
    return '$n records';
  }

  @override
  Widget build(BuildContext context) {
    if (result.breaches.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.safe.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.verified, color: AppColors.safe, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No known breaches for this address.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text('Source: ${result.source}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SpeakButton(
                compact: true,
                text: 'Good news. No known breaches were found for this email address. Keep using unique strong passwords for each service.',
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.danger.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gpp_bad, color: AppColors.danger, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${result.breaches.length} breach${result.breaches.length == 1 ? '' : 'es'} found',
                        style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    SpeakButton(
                      compact: true,
                      text: _summariseBreachesForSpeech(result),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Source: ${result.source}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                const Text('Recommended actions:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('• Change the password on each affected service.'),
                const Text('• Never reuse passwords — use a password manager.'),
                const Text('• Enable 2FA wherever available.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...result.breaches.map(
          (b) => Card(
            child: ExpansionTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFEBEE),
                child: Icon(Icons.shield_outlined, color: AppColors.danger),
              ),
              title: Text(b.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                [
                  if (b.date.isNotEmpty) b.date,
                  if (b.records > 0) _formatRecords(b.records),
                  if (b.industry.isNotEmpty) b.industry,
                ].join(' • '),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              children: [
                if (b.data.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Leaked data:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(b.data),
                  ),
                ],
                if (b.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(b.description,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
