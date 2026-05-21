import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/locale_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';

/// Tap to read `text` aloud in the currently selected language. Sarvam if a key
/// is configured, otherwise device TTS.
class SpeakButton extends StatefulWidget {
  const SpeakButton({
    super.key,
    required this.text,
    this.label,
    this.compact = false,
  });

  /// The text to read.
  final String text;

  /// Optional override label. Defaults to "Read aloud" in the current locale.
  final String? label;

  /// Compact icon-only variant.
  final bool compact;

  @override
  State<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<SpeakButton> {
  bool _speaking = false;

  Future<void> _toggle() async {
    final tts = context.read<TtsService>();
    final lang = context.read<LocaleService>().current.languageCode;
    if (_speaking) {
      await tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    try {
      await tts.speak(widget.text, lang);
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  void dispose() {
    // best-effort: do NOT cancel a session-shared TtsService, just stop playback
    // if this button initiated it
    if (_speaking) {
      // ignore: discarded_futures
      context.read<TtsService>().stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(_speaking ? Icons.stop_circle : Icons.volume_up,
        color: AppColors.primary, size: 20);
    if (widget.compact) {
      return IconButton(
        tooltip: _speaking ? 'Stop' : 'Read aloud',
        icon: icon,
        onPressed: widget.text.trim().isEmpty ? null : _toggle,
      );
    }
    return OutlinedButton.icon(
      onPressed: widget.text.trim().isEmpty ? null : _toggle,
      icon: icon,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
      ),
      label: Text(_speaking ? 'Stop' : (widget.label ?? 'Read aloud')),
    );
  }
}
