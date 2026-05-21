import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/strings.dart';
import '../../core/services/backend_client.dart';
import '../../core/theme/app_theme.dart';

class CallForwardingScreen extends StatelessWidget {
  const CallForwardingScreen({super.key});

  static const _actions = <_CfAction>[
    _CfAction(
      titleKey: 'cf.checkAll',
      subtitleKey: 'cf.checkAllSub',
      code: '*#21#',
      verdict: 'unknown',
      color: AppColors.primary,
      icon: Icons.search,
    ),
    _CfAction(
      titleKey: 'cf.disableAll',
      subtitleKey: 'cf.disableAllSub',
      code: '##002#',
      verdict: 'safe',
      color: AppColors.safe,
      icon: Icons.block,
    ),
    _CfAction(
      titleKey: 'cf.disableUncond',
      subtitleKey: 'cf.disableUncondSub',
      code: '##21#',
      verdict: 'safe',
      color: AppColors.warning,
      icon: Icons.phone_disabled,
    ),
  ];

  Future<void> _runUssd(BuildContext context, _CfAction a) async {
    // `#` must be URL-encoded as %23 for tel: URIs.
    final encoded = a.code.replaceAll('#', '%23');
    final uri = Uri.parse('tel:$encoded');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t(context, 'cf.dialerFailed'))),
      );
      return;
    }
    // Log the user-initiated action.
    BackendClient().recordScan(
      kind: 'call_forward',
      verdict: a.verdict,
      target: a.code,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${S.t(context, 'cf.dialed')} ${a.code}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t(context, 'cf.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.30)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.t(context, 'cf.whyTitle'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(S.t(context, 'cf.whyBody'),
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._actions.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ActionCard(action: a, onTap: () => _runUssd(context, a)),
              )),
          const SizedBox(height: 8),
          Text(S.t(context, 'cf.note'),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
        ],
      ),
    );
  }
}

class _CfAction {
  const _CfAction({
    required this.titleKey,
    required this.subtitleKey,
    required this.code,
    required this.verdict,
    required this.color,
    required this.icon,
  });
  final String titleKey;
  final String subtitleKey;
  final String code;
  final String verdict;
  final Color color;
  final IconData icon;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, required this.onTap});
  final _CfAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(action.icon, color: action.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.t(context, action.titleKey),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(S.t(context, action.subtitleKey),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: action.color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(action.code,
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: action.color,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.call, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
