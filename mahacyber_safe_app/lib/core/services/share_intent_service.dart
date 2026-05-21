import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Receives `ACTION_SEND` text/plain intents from other apps (WhatsApp, SMS,
/// browsers) and routes them to the URL scanner.
class ShareIntentService {
  ShareIntentService._();
  static final ShareIntentService instance = ShareIntentService._();

  static const _channel = MethodChannel(
    'in.gov.maharashtracyber.mahacyber_safe/share_intent',
  );

  /// Called by the app when a URL has been shared in.
  void Function(String url)? onUrlShared;

  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShared') {
        final raw = (call.arguments as String?) ?? '';
        _handle(raw);
      }
    });
    // Drain any cold-start payload.
    _channel.invokeMethod<String>('getInitial').then((raw) {
      if (raw != null && raw.isNotEmpty) _handle(raw);
    }).catchError((Object e) {
      debugPrint('share_intent getInitial failed: $e');
    });
  }

  void _handle(String raw) {
    final url = extractFirstUrl(raw);
    if (url == null) return;
    onUrlShared?.call(url);
  }

  /// Pulls the first http(s) URL out of an arbitrary shared text payload.
  /// Returns null if no URL is found.
  static String? extractFirstUrl(String text) {
    final match = RegExp(
      r'https?://[^\s<>"\)\]]+',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) return match.group(0);
    // Bare domain fallback: e.g. "sbi-online.in/login"
    final bare = RegExp(
      r'(?:^|\s)((?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,})(/[^\s]*)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (bare != null) {
      final host = bare.group(1)!;
      final path = bare.group(2) ?? '';
      return 'http://$host$path';
    }
    return null;
  }
}
