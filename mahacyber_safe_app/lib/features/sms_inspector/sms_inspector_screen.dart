import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/i18n/strings.dart';
import '../../core/services/backend_client.dart';
import '../../core/theme/app_theme.dart';

class SmsInspectorScreen extends StatefulWidget {
  const SmsInspectorScreen({super.key});

  @override
  State<SmsInspectorScreen> createState() => _SmsInspectorScreenState();
}

class _SmsInspectorScreenState extends State<SmsInspectorScreen> {
  final _textCtrl = TextEditingController();
  final _senderCtrl = TextEditingController();
  Map<String, dynamic>? _result;
  bool _loading = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _senderCtrl.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _textCtrl.text = data.text!.trim();
      setState(() {});
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t(context, 'sms.clipboardEmpty'))),
      );
    }
  }

  Future<void> _analyse() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _loading = true;
      _result = null;
    });
    final r = await BackendClient().scanSms(
      text: text,
      sender: _senderCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _result = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t(context, 'sms.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.privacy_tip_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.t(context, 'sms.privacyNote'),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _senderCtrl,
            decoration: InputDecoration(
              labelText: S.t(context, 'sms.senderLabel'),
              hintText: 'e.g. VK-HDFCBK or 9876543210',
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textCtrl,
            maxLines: 6,
            minLines: 4,
            decoration: InputDecoration(
              labelText: S.t(context, 'sms.bodyLabel'),
              hintText: S.t(context, 'sms.bodyHint'),
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.sms_outlined),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.paste),
                  label: Text(S.t(context, 'sms.paste')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _analyse,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Icon(Icons.search),
                  label: Text(_loading
                      ? S.t(context, 'common.refresh')
                      : S.t(context, 'sms.analyse')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_result != null) _SmsVerdictCard(result: _result!),
        ],
      ),
    );
  }
}

class _SmsVerdictCard extends StatelessWidget {
  const _SmsVerdictCard({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final verdict = (result['verdict'] as String?) ?? 'unknown';
    final (color, icon, label) = switch (verdict) {
      'safe' => (AppColors.safe, Icons.verified, S.t(context, 'sms.safe')),
      'suspicious' => (
          AppColors.warning,
          Icons.warning_amber_rounded,
          S.t(context, 'sms.suspicious')
        ),
      'malicious' => (
          AppColors.danger,
          Icons.dangerous,
          S.t(context, 'sms.malicious')
        ),
      _ => (AppColors.textSecondary, Icons.help_outline, verdict),
    };
    final reasons = (result['reasons'] as List?)?.cast<String>() ?? const [];
    final urls = (result['urls'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final score = result['score'];

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (score != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('score $score',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ),
              ],
            ),
            if (reasons.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(S.t(context, 'sms.findings'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...reasons.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(r)),
                      ],
                    ),
                  )),
            ],
            if (urls.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(S.t(context, 'sms.embeddedUrls'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...urls.map((u) {
                final v = (u['verdict'] as String?) ?? 'unknown';
                final c = switch (v) {
                  'safe' => AppColors.safe,
                  'suspicious' => AppColors.warning,
                  'malicious' => AppColors.danger,
                  _ => AppColors.textSecondary,
                };
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    onTap: () {
                      final encoded =
                          Uri.encodeQueryComponent(u['url'] as String);
                      context.push('${AppRoutes.urlScanner}?url=$encoded');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.link, size: 16, color: c),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              u['url'] as String? ?? '',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(v.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: c)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
            if (reasons.isEmpty && urls.isEmpty) ...[
              const SizedBox(height: 12),
              Text(S.t(context, 'sms.cleanNote'),
                  style:
                      const TextStyle(color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}
