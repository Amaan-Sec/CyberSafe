/// Centralised place for third-party API keys used by the prototype.
///
/// In production these should come from a build-flavour `--dart-define` or a
/// remote config service. For the prototype we keep them here so the demo is
/// self-contained and reproducible.
class ApiKeys {
  // ============================================================
  // Sarvam AI — Indic text-to-speech (Marathi / Hindi / English)
  // ============================================================
  // Get your key from https://dashboard.sarvam.ai/admin/api-keys and pass it
  // at build time:  flutter build apk --dart-define=SARVAM_KEY=sk_xxx
  // Leave unset to fall back to the on-device flutter_tts engine.
  static const String sarvamTts =
      String.fromEnvironment('SARVAM_KEY', defaultValue: '');

  /// Sarvam TTS endpoint.
  static const String sarvamTtsEndpoint = 'https://api.sarvam.ai/text-to-speech';

  /// Speaker / voice. As of bulbul:v2 the valid speakers are: anushka,
  /// abhilash, manisha, vidya, arya, karun, hitesh, etc. `anushka` is a clear
  /// female voice that handles Hindi / Marathi / English well.
  static const String sarvamSpeaker = 'anushka';

  /// Sarvam model. `bulbul:v2` is the current production Indic-tuned model
  /// (v1 was deprecated). v3 is in beta.
  static const String sarvamModel = 'bulbul:v2';

  /// Whether the prototype should use Sarvam at all. If the key is missing we
  /// short-circuit to the device engine without making a doomed network call.
  static bool get sarvamConfigured =>
      sarvamTts.isNotEmpty && !sarvamTts.startsWith('YOUR_');
}
