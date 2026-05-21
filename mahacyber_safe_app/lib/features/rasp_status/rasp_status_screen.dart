import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/rasp/rasp_service.dart';
import '../../core/theme/app_theme.dart';

class RaspStatusScreen extends StatelessWidget {
  const RaspStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rasp = context.watch<RaspService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Runtime protection'),
        actions: [
          if (rasp.threats.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear log',
              onPressed: rasp.clearThreats,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SummaryCard(rasp: rasp),
          const SizedBox(height: 20),
          const Text(
            'Threat log',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (rasp.threats.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: const [
                    Icon(Icons.shield_outlined, color: AppColors.safe),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No runtime threats observed in this session.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...rasp.threats
                .map((t) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _ThreatTile(event: t),
                    ))
                .toList(),
          const SizedBox(height: 20),
          const _AboutCard(),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.rasp});
  final RaspService rasp;

  @override
  Widget build(BuildContext context) {
    final isClean = rasp.threats.isEmpty;
    final color = !rasp.started
        ? AppColors.textSecondary
        : isClean
            ? AppColors.safe
            : rasp.hasCriticalThreat
                ? AppColors.danger
                : AppColors.warning;

    final label = !rasp.started
        ? 'Initialising'
        : isClean
            ? 'Device is healthy'
            : '${rasp.threats.length} threat${rasp.threats.length == 1 ? '' : 's'} detected';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(
                isClean ? Icons.verified_user : Icons.gpp_maybe,
                color: color,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RASP status',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rasp.started
                        ? 'Provided by Talsec freeRASP'
                        : 'Initialising runtime protection…',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreatTile extends StatelessWidget {
  const _ThreatTile({required this.event});
  final RaspThreatEvent event;

  Color _colorFor(RaspSeverity s) {
    switch (s) {
      case RaspSeverity.low:
        return AppColors.primary;
      case RaspSeverity.medium:
        return const Color(0xFFB28704);
      case RaspSeverity.high:
        return AppColors.warning;
      case RaspSeverity.critical:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(event.type.severity);
    final df = DateFormat('dd MMM, HH:mm:ss');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    event.type.severity.name.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  df.format(event.detectedAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              event.type.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              event.type.advice,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (event.details != null) ...[
              const SizedBox(height: 6),
              Text(
                'Details: ${event.details}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFEDF2FB),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary),
                SizedBox(width: 8),
                Text('What is RASP?',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Runtime Application Self-Protection (RASP) continuously monitors the device and app for signs of compromise — '
              'rooted devices, debuggers, hooking frameworks like Frida, tampered builds, sideloaded installs, screen recording, '
              'and more. If anything risky is detected, the app warns you and can block sensitive actions.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
