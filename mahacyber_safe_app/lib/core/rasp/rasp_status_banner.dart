import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import 'rasp_service.dart';

/// Compact banner showing live RASP status. Tappable to open the detail screen.
class RaspStatusBanner extends StatelessWidget {
  const RaspStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final rasp = context.watch<RaspService>();
    final severity = rasp.highestSeverity;
    final isClean = severity == null;

    final (Color bg, Color fg, IconData icon, String label) = _styleFor(
      severity,
      started: rasp.started,
      clean: isClean,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push(AppRoutes.raspStatus),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: fg.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device protection (RASP)',
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: fg),
          ],
        ),
      ),
    );
  }

  (Color, Color, IconData, String) _styleFor(
    RaspSeverity? severity, {
    required bool started,
    required bool clean,
  }) {
    if (!started) {
      return (
        const Color(0xFFE2E8F0),
        AppColors.textSecondary,
        Icons.hourglass_top,
        'Initialising…',
      );
    }
    if (clean) {
      return (
        const Color(0xFFE6F4EA),
        AppColors.safe,
        Icons.verified_user,
        'No threats detected on this device',
      );
    }
    switch (severity!) {
      case RaspSeverity.critical:
        return (
          const Color(0xFFFDECEA),
          AppColors.danger,
          Icons.gpp_bad,
          'Critical risk — review immediately',
        );
      case RaspSeverity.high:
        return (
          const Color(0xFFFFF1E6),
          AppColors.warning,
          Icons.warning_amber_rounded,
          'High risk detected',
        );
      case RaspSeverity.medium:
        return (
          const Color(0xFFFFF8E1),
          const Color(0xFFB28704),
          Icons.error_outline,
          'Medium risk detected',
        );
      case RaspSeverity.low:
        return (
          const Color(0xFFEDF2FB),
          AppColors.primary,
          Icons.info_outline,
          'Low-severity advisory',
        );
    }
  }
}
