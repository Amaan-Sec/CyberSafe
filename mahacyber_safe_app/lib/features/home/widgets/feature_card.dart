import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class FeatureCard extends StatefulWidget {
  const FeatureCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = AppColors.primary,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accent;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_pressed ? 0.98 : 1.0),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _pressed
                ? accent.withValues(alpha: 0.6)
                : palette.hairline,
            width: 1.2,
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: isDark ? 0.35 : 0.20),
                    blurRadius: 20,
                    offset: const Offset(0, 0),
                  ),
                ]
              : (isDark ? AppShadows.cardDark : AppShadows.card),
        ),
        child: Stack(
          children: [
            // Accent strip across the top — gives each tile a "circuit"
            // edge while still reading clean on either surface.
            Positioned(
              top: 0,
              left: 18,
              right: 18,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.0),
                      accent,
                      accent.withValues(alpha: 0.0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: isDark ? 0.26 : 0.18),
                          accent.withValues(alpha: isDark ? 0.10 : 0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.30),
                        width: 1,
                      ),
                    ),
                    child: Icon(widget.icon, color: accent, size: 22),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                      letterSpacing: 0.1,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
