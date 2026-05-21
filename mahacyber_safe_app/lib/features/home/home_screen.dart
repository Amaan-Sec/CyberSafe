import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/i18n/language_picker.dart';
import '../../core/i18n/strings.dart';
import '../../core/rasp/rasp_status_banner.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_service.dart';
import 'widgets/feature_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
                decoration: BoxDecoration(
                  gradient: AppGradients.heroNavy,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppShadows.floating,
                ),
                child: Stack(
                  children: [
                    // Subtle scan-line texture (top-right glow)
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.accent.withOpacity(0.30),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.18),
                                ),
                              ),
                              child: const Icon(Icons.shield_moon,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'MAHACYBER · SAFE',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.6,
                                    ),
                                  ),
                                  Text(
                                    S.t(context, 'home.stayCyberSafe'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const LanguagePicker(compact: true),
                            const _ThemeToggleIconButton(),
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined,
                                  color: Colors.white),
                              onPressed: () => context.push(AppRoutes.news),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.signal.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.signal.withOpacity(0.45),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.signal,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${S.t(context, 'home.greeting')}  ·  PROTECTED',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              sliver: const SliverToBoxAdapter(
                child: RaspStatusBanner(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _SosButton(onTap: () => context.push(AppRoutes.sos)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: AppGradients.cyberAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      S.t(context, 'home.cyberTools'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),
                delegate: SliverChildListDelegate([
                  FeatureCard(
                    icon: Icons.qr_code_scanner,
                    label: S.t(context, 'tile.qr'),
                    subtitle: S.t(context, 'tile.qrSub'),
                    accent: AppColors.primary,
                    onTap: () => context.push(AppRoutes.qrScanner),
                  ),
                  FeatureCard(
                    icon: Icons.link,
                    label: S.t(context, 'tile.url'),
                    subtitle: S.t(context, 'tile.urlSub'),
                    accent: AppColors.accent,
                    onTap: () => context.push(AppRoutes.urlScanner),
                  ),
                  FeatureCard(
                    icon: Icons.wifi_tethering,
                    label: S.t(context, 'tile.wifi'),
                    subtitle: S.t(context, 'tile.wifiSub'),
                    accent: const Color(0xFF6750A4),
                    onTap: () => context.push(AppRoutes.wifiScanner),
                  ),
                  FeatureCard(
                    icon: Icons.privacy_tip_outlined,
                    label: S.t(context, 'tile.breach'),
                    subtitle: S.t(context, 'tile.breachSub'),
                    accent: AppColors.warning,
                    onTap: () => context.push(AppRoutes.breachCheck),
                  ),
                  FeatureCard(
                    icon: Icons.apps,
                    label: S.t(context, 'tile.installedApps'),
                    subtitle: S.t(context, 'tile.installedAppsSub'),
                    accent: const Color(0xFF00897B),
                    onTap: () => context.push(AppRoutes.installedApps),
                  ),
                  FeatureCard(
                    icon: Icons.visibility_off_outlined,
                    label: S.t(context, 'tile.hiddenApps'),
                    subtitle: S.t(context, 'tile.hiddenAppsSub'),
                    accent: AppColors.danger,
                    onTap: () => context.push(AppRoutes.hiddenApps),
                  ),
                  FeatureCard(
                    icon: Icons.adb_rounded,
                    label: S.t(context, 'tile.adware'),
                    subtitle: S.t(context, 'tile.adwareSub'),
                    accent: const Color(0xFFD97706),
                    onTap: () => context.push(AppRoutes.adwareScanner),
                  ),
                  FeatureCard(
                    icon: Icons.health_and_safety_outlined,
                    label: S.t(context, 'tile.advisor'),
                    subtitle: S.t(context, 'tile.advisorSub'),
                    accent: AppColors.safe,
                    onTap: () => context.push(AppRoutes.advisor),
                  ),
                  FeatureCard(
                    icon: Icons.feed_outlined,
                    label: S.t(context, 'tile.news'),
                    subtitle: S.t(context, 'tile.newsSub'),
                    accent: const Color(0xFF455A64),
                    onTap: () => context.push(AppRoutes.news),
                  ),
                  FeatureCard(
                    icon: Icons.verified_user_outlined,
                    label: S.t(context, 'tile.raspStatus'),
                    subtitle: S.t(context, 'tile.raspSub'),
                    accent: AppColors.primary,
                    onTap: () => context.push(AppRoutes.raspStatus),
                  ),
                  FeatureCard(
                    icon: Icons.support_agent,
                    label: S.t(context, 'tile.grievance'),
                    subtitle: S.t(context, 'tile.grievanceSub'),
                    accent: const Color(0xFFE65100),
                    onTap: () => context.push(AppRoutes.grievance),
                  ),
                  FeatureCard(
                    icon: Icons.phone_forwarded,
                    label: S.t(context, 'tile.callForward'),
                    subtitle: S.t(context, 'tile.callForwardSub'),
                    accent: const Color(0xFFAD1457),
                    onTap: () => context.push(AppRoutes.callForwarding),
                  ),
                  FeatureCard(
                    icon: Icons.sms_outlined,
                    label: S.t(context, 'tile.smsInspector'),
                    subtitle: S.t(context, 'tile.smsInspectorSub'),
                    accent: const Color(0xFF1565C0),
                    onTap: () => context.push(AppRoutes.smsInspector),
                  ),
                  FeatureCard(
                    icon: Icons.accessibility_new,
                    label: S.t(context, 'tile.a11yAudit'),
                    subtitle: S.t(context, 'tile.a11yAuditSub'),
                    accent: const Color(0xFF7B1FA2),
                    onTap: () => context.push(AppRoutes.accessibilityAudit),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppGradients.dangerPulse,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33D92D20),
              blurRadius: 18,
              offset: Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sos, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.t(context, 'home.sosTitle'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    S.t(context, 'home.sosSubtitle'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggleIconButton extends StatelessWidget {
  const _ThemeToggleIconButton();

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ThemeModeService>();
    final mode = service.mode;
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    // Effective brightness right now (what the user sees).
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system && platformDark);
    return IconButton(
      tooltip: isDark ? 'Switch to light' : 'Switch to dark',
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: Colors.white,
      ),
      onPressed: () =>
          service.set(isDark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}
