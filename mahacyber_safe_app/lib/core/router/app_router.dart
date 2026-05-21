import 'package:go_router/go_router.dart';

import '../../features/advisor/security_advisor_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/breach/breach_check_screen.dart';
import '../../features/call_forwarding/call_forwarding_screen.dart';
import '../../features/accessibility_audit/accessibility_audit_screen.dart';
import '../../features/adware_scanner/adware_scanner_screen.dart';
import '../../features/sms_inspector/sms_inspector_screen.dart';
import '../../features/grievances/grievance_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/installed_apps/hidden_apps_screen.dart';
import '../../features/installed_apps/installed_apps_screen.dart';
import '../../features/news/cyber_news_screen.dart';
import '../../features/permissions/app_permissions_screen.dart';
import '../../features/rasp_status/rasp_status_screen.dart';
import '../../features/scanners/qr_scanner_screen.dart';
import '../../features/scanners/url_scanner_screen.dart';
import '../../features/scanners/wifi_scanner_screen.dart';
import '../../features/sos/sos_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../constants/app_constants.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.qrScanner,
        builder: (_, __) => const QrScannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.urlScanner,
        builder: (_, state) => UrlScannerScreen(
          initialUrl: state.uri.queryParameters['url'],
        ),
      ),
      GoRoute(
        path: AppRoutes.wifiScanner,
        builder: (_, __) => const WifiScannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.breachCheck,
        builder: (_, __) => const BreachCheckScreen(),
      ),
      GoRoute(
        path: AppRoutes.permissions,
        builder: (_, __) => const AppPermissionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.advisor,
        builder: (_, __) => const SecurityAdvisorScreen(),
      ),
      GoRoute(
        path: AppRoutes.news,
        builder: (_, __) => const CyberNewsScreen(),
      ),
      GoRoute(
        path: AppRoutes.sos,
        builder: (_, __) => const SosScreen(),
      ),
      GoRoute(
        path: AppRoutes.raspStatus,
        builder: (_, __) => const RaspStatusScreen(),
      ),
      GoRoute(
        path: AppRoutes.installedApps,
        builder: (_, __) => const InstalledAppsScreen(),
      ),
      GoRoute(
        path: AppRoutes.hiddenApps,
        builder: (_, __) => const HiddenAppsScreen(),
      ),
      GoRoute(
        path: AppRoutes.grievance,
        builder: (_, __) => const GrievanceScreen(),
      ),
      GoRoute(
        path: AppRoutes.callForwarding,
        builder: (_, __) => const CallForwardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.smsInspector,
        builder: (_, __) => const SmsInspectorScreen(),
      ),
      GoRoute(
        path: AppRoutes.accessibilityAudit,
        builder: (_, __) => const AccessibilityAuditScreen(),
      ),
      GoRoute(
        path: AppRoutes.adwareScanner,
        builder: (_, __) => const AdwareScannerScreen(),
      ),
    ],
  );
}
