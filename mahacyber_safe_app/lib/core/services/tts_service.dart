import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/api_keys.dart';

/// Two-tier text-to-speech.
///
/// Primary: Sarvam AI `text-to-speech` (high-quality Marathi / Hindi / English
/// voices, server-side). Sarvam returns base64 WAV which we save to a temp file
/// and play via audioplayers.
///
/// Fallback: device `flutter_tts` engine. Used when no Sarvam key is configured
/// or when the Sarvam call fails for any reason. The device engine may or may
/// not have a Marathi/Hindi voice installed depending on the phone.
class TtsService {
  final FlutterTts _device = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  bool _isSpeaking = false;
  String? _lastTempPath;

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    try {
      await _device.awaitSpeakCompletion(true);
      await _device.setSpeechRate(0.45);
      await _device.setVolume(1.0);
    } catch (e) {
      debugPrint('flutter_tts init failed: $e');
    }
  }

  /// Stop any in-flight speech (server or device).
  Future<void> stop() async {
    _isSpeaking = false;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _device.stop();
    } catch (_) {}
  }

  /// Speak `text` in the given locale code (`en`, `hi`, `mr`).
  /// Returns when audio has finished or playback was stopped.
  Future<void> speak(String text, String localeCode) async {
    if (text.trim().isEmpty) return;
    await stop();
    _isSpeaking = true;
    try {
      if (ApiKeys.sarvamConfigured) {
        final ok = await _speakViaSarvam(text, localeCode);
        if (ok) return;
        // fall through to device fallback on failure
      }
      await _speakViaDevice(text, localeCode);
    } finally {
      _isSpeaking = false;
    }
  }

  Future<bool> _speakViaSarvam(String text, String localeCode) async {
    final target = _sarvamTargetCode(localeCode);
    // Sarvam caps the request to ~500 characters per chunk for the bulbul model.
    final chunks = _chunk(text, 480);
    final tempDir = await getTemporaryDirectory();

    for (var i = 0; i < chunks.length; i++) {
      if (!_isSpeaking) return true; // user pressed stop mid-speech
      try {
        final body = jsonEncode({
          'inputs': [chunks[i]],
          'target_language_code': target,
          'speaker': ApiKeys.sarvamSpeaker,
          'pitch': 0,
          'pace': 1.0,
          'loudness': 1.5,
          'speech_sample_rate': 22050,
          'enable_preprocessing': true,
          'model': ApiKeys.sarvamModel,
        });
        final resp = await http
            .post(
              Uri.parse(ApiKeys.sarvamTtsEndpoint),
              headers: {
                'Content-Type': 'application/json',
                'api-subscription-key': ApiKeys.sarvamTts,
              },
              body: body,
            )
            .timeout(const Duration(seconds: 25));
        if (resp.statusCode != 200) {
          debugPrint('Sarvam TTS HTTP ${resp.statusCode}: ${resp.body}');
          return false;
        }
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        final audios = (j['audios'] as List?)?.cast<String>() ?? const [];
        if (audios.isEmpty) {
          debugPrint('Sarvam TTS returned no audio');
          return false;
        }
        final bytes = base64Decode(audios.first);
        final f = File('${tempDir.path}/mcs_tts_${DateTime.now().microsecondsSinceEpoch}.wav');
        await f.writeAsBytes(bytes);
        _lastTempPath = f.path;

        final completer = Completer<void>();
        late StreamSubscription sub;
        sub = _player.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
          sub.cancel();
        });
        await _player.play(DeviceFileSource(f.path));
        await completer.future;
      } catch (e) {
        debugPrint('Sarvam TTS chunk $i failed: $e');
        return false;
      }
    }
    return true;
  }

  Future<void> _speakViaDevice(String text, String localeCode) async {
    final lang = _deviceLangCode(localeCode);
    try {
      await _device.setLanguage(lang);
    } catch (_) {}
    try {
      await _device.speak(text);
    } catch (e) {
      debugPrint('flutter_tts speak failed: $e');
    }
  }

  static String _sarvamTargetCode(String code) {
    switch (code) {
      case 'hi':
        return 'hi-IN';
      case 'mr':
        return 'mr-IN';
      default:
        return 'en-IN';
    }
  }

  static String _deviceLangCode(String code) {
    switch (code) {
      case 'hi':
        return 'hi-IN';
      case 'mr':
        return 'mr-IN';
      default:
        return 'en-IN';
    }
  }

  /// Split into chunks at sentence boundaries when possible, then hard-cap.
  static List<String> _chunk(String text, int maxLen) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= maxLen) return [cleaned];

    final parts = <String>[];
    final sentences = cleaned.split(RegExp(r'(?<=[.!?।])\s+'));
    var buf = StringBuffer();
    for (final s in sentences) {
      if (buf.length + s.length + 1 > maxLen) {
        if (buf.isNotEmpty) {
          parts.add(buf.toString().trim());
          buf = StringBuffer();
        }
        if (s.length > maxLen) {
          for (var i = 0; i < s.length; i += maxLen) {
            parts.add(s.substring(i, i + maxLen > s.length ? s.length : i + maxLen));
          }
        } else {
          buf.write(s);
          buf.write(' ');
        }
      } else {
        buf.write(s);
        buf.write(' ');
      }
    }
    if (buf.isNotEmpty) parts.add(buf.toString().trim());
    return parts;
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
