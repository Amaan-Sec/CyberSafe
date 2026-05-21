import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'locale_service.dart';

/// Compact menu button that lets the user switch UI + TTS language.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, this.compact = true});

  /// When true, shows just a globe icon. When false, shows globe + current
  /// language name (use on screens with room in the AppBar).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<LocaleService>();
    return PopupMenuButton<Locale>(
      tooltip: 'Language',
      icon: compact
          ? const Icon(Icons.translate)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.translate, size: 20),
                const SizedBox(width: 4),
                Text(svc.displayName, style: const TextStyle(fontSize: 13)),
              ],
            ),
      onSelected: svc.set,
      itemBuilder: (_) => [
        for (final l in LocaleService.supported)
          PopupMenuItem(
            value: l,
            child: Row(
              children: [
                if (svc.current == l)
                  const Icon(Icons.check, size: 16, color: Colors.green)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(_nameFor(l)),
              ],
            ),
          ),
      ],
    );
  }

  static String _nameFor(Locale l) {
    switch (l.languageCode) {
      case 'hi':
        return 'हिन्दी (Hindi)';
      case 'mr':
        return 'मराठी (Marathi)';
      default:
        return 'English';
    }
  }
}
