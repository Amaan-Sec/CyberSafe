import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'backend_client.dart';

/// Verdict from one or more threat-intelligence sources.
enum UrlVerdict { safe, suspicious, malicious }

class UrlAnalysis {
  UrlAnalysis({
    required this.verdict,
    required this.reasons,
    required this.normalised,
    this.sources = const [],
  });

  final UrlVerdict verdict;
  final List<String> reasons;
  final String normalised;

  /// Human-readable list of which engines were consulted and what they said.
  final List<String> sources;
}

class UrlSafetyService {
  static const String _backendUrl =
      'http://164.52.194.98:8000/api/scan/url';

  /// Async: ask the backend (URLhaus + optional VirusTotal/GSB + heuristic),
  /// fall back to local heuristic if the backend is unreachable.
  ///
  /// [kind] tags the scan event the backend persists — pass 'qr' from the
  /// QR scanner so admin analytics distinguish QR scans from typed URLs.
  static Future<UrlAnalysis> analyse(String input, {String kind = 'url'}) async {
    final raw = input.trim();
    if (raw.isEmpty) {
      return UrlAnalysis(
        verdict: UrlVerdict.suspicious,
        reasons: const ['Empty input'],
        normalised: '',
      );
    }

    try {
      final ident = await BackendClient().identityFields();
      final resp = await http
          .post(
            Uri.parse(_backendUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'url': raw, 'kind': kind, ...ident}),
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        final verdict = switch (j['verdict']) {
          'malicious' => UrlVerdict.malicious,
          'suspicious' => UrlVerdict.suspicious,
          _ => UrlVerdict.safe,
        };
        final reasons = (j['reasons'] as List?)?.cast<String>() ?? <String>[];
        final sources = <String>[];
        for (final s in (j['sources'] as List? ?? <dynamic>[])) {
          if (s is! Map) continue;
          final name = (s['source'] ?? '').toString();
          if (name.isEmpty) continue;
          if (s.containsKey('error')) {
            sources.add('$name — unavailable (${s['error']})');
          } else if (name == 'VirusTotal') {
            // VT gets a richer breakdown so the citizen can see the engine vote
            final m = s['malicious'];
            final sus = s['suspicious'];
            final h = s['harmless'];
            final u = s['undetected'];
            if (m != null || sus != null || h != null) {
              final scope = (s['scope'] == 'domain') ? ' (domain rep.)' : '';
              final tag = s['hit'] == true ? 'FLAGGED' : 'clean';
              sources.add(
                  '$name$scope — $tag · $m malicious / $sus suspicious / $h harmless / $u undetected');
            } else if (s.containsKey('note')) {
              sources.add('$name — ${s['note']}');
            } else {
              sources.add('$name — ${s['hit'] == true ? 'FLAGGED' : 'clean'}');
            }
          } else if (s['hit'] == true) {
            sources.add('$name — FLAGGED');
          } else if (s.containsKey('feed_size')) {
            sources.add('$name — clean (checked against ${s['feed_size']} known-bad URLs)');
          } else {
            sources.add('$name — clean');
          }
        }
        return UrlAnalysis(
          verdict: verdict,
          reasons: reasons,
          normalised: (j['normalised'] ?? raw).toString(),
          sources: sources,
        );
      }
    } catch (e) {
      debugPrint('URL scan backend unreachable: $e — using local heuristic');
    }

    return _localHeuristic(raw);
  }

  /// Offline fallback — same rules the prototype shipped with originally.
  static UrlAnalysis _localHeuristic(String raw) {
    final reasons = <String>[];
    final withScheme = raw.contains('://') ? raw : 'https://$raw';
    Uri uri;
    try {
      uri = Uri.parse(withScheme);
    } catch (_) {
      return UrlAnalysis(
        verdict: UrlVerdict.suspicious,
        reasons: const ['Could not parse URL'],
        normalised: raw,
      );
    }

    final host = uri.host.toLowerCase();
    if (uri.scheme == 'http') reasons.add('Uses unencrypted HTTP');
    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host)) {
      reasons.add('Host is a raw IP address');
    }
    const shorteners = [
      'bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'is.gd', 'rb.gy',
      'shorturl.at', 'cutt.ly',
    ];
    if (shorteners.any((s) => host == s || host.endsWith('.$s'))) {
      reasons.add('URL shortener — destination is hidden');
    }
    const suspiciousTlds = [
      '.zip', '.mov', '.country', '.click', '.gq', '.tk', '.cf', '.ml', '.work'
    ];
    if (suspiciousTlds.any(host.endsWith)) reasons.add('Suspicious top-level domain');
    const brandKeywords = [
      'paytm', 'phonepe', 'sbi', 'hdfc', 'icici', 'aadhaar', 'uidai',
      'irctc', 'gov', 'pmkisan', 'kyc',
    ];
    if (brandKeywords.any(host.contains) && !host.endsWith('.gov.in')) {
      reasons.add('Imitates a well-known Indian brand');
    }
    if (host.contains('--') || host.split('.').any((p) => p.length > 24)) {
      reasons.add('Unusual domain structure');
    }
    if (uri.queryParameters.keys.any(
      (k) => k.toLowerCase().contains('otp') ||
          k.toLowerCase().contains('cvv') ||
          k.toLowerCase().contains('pin'),
    )) {
      reasons.add('Asks for sensitive credentials in URL');
    }

    UrlVerdict verdict;
    if (reasons.length >= 3) {
      verdict = UrlVerdict.malicious;
    } else if (reasons.isNotEmpty) {
      verdict = UrlVerdict.suspicious;
    } else {
      verdict = UrlVerdict.safe;
    }
    return UrlAnalysis(
      verdict: verdict,
      reasons: reasons,
      normalised: uri.toString(),
      sources: const ['Local heuristic (backend unreachable)'],
    );
  }
}
