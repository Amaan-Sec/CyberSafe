import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_service.dart';

/// Lists relevant permissions for this app and their current status.
///
/// On Android, listing *other* apps' permissions is not possible without
/// platform-side queries that need REQUEST_INSTALL_PACKAGES + system intents.
/// For the prototype we focus on the app's own permission posture — a useful
/// signal for citizens about what we asked for.
class AppPermissionsScreen extends StatefulWidget {
  const AppPermissionsScreen({super.key});

  @override
  State<AppPermissionsScreen> createState() => _AppPermissionsScreenState();
}

class _AppPermissionsScreenState extends State<AppPermissionsScreen> {
  bool _loading = true;
  final Map<Permission, PermissionStatus> _statuses = {};

  static const _watched = <_PermInfo>[
    _PermInfo(
      permission: Permission.camera,
      label: 'Camera',
      reason: 'Required to scan QR codes.',
      riskIfGranted: 'Low',
    ),
    _PermInfo(
      permission: Permission.location,
      label: 'Location',
      reason: 'Required by Android to read Wi-Fi details and for SOS.',
      riskIfGranted: 'Medium — reveals where you are.',
    ),
    _PermInfo(
      permission: Permission.notification,
      label: 'Notifications',
      reason: 'Used for cyber advisories and alerts.',
      riskIfGranted: 'Low',
    ),
    _PermInfo(
      permission: Permission.contacts,
      label: 'Contacts',
      reason: 'Optional — used by SOS to notify trusted contacts.',
      riskIfGranted: 'High — exposes your address book.',
    ),
    _PermInfo(
      permission: Permission.phone,
      label: 'Phone',
      reason: 'Optional — used to detect call-forwarding for OTP safety.',
      riskIfGranted: 'High — phone state is sensitive.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    for (final p in _watched) {
      _statuses[p.permission] = await p.permission.status;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _request(Permission p) async {
    final result = await p.request();
    if (!mounted) return;
    setState(() => _statuses[p] = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App permissions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _watched.length + 2, // appearance card + spacer
              itemBuilder: (_, i) {
                if (i == 0) return const _AppearanceCard();
                if (i == 1) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(4, 18, 0, 10),
                    child: Text(
                      'Permissions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                final info = _watched[i - 2];
                final status =
                    _statuses[info.permission] ?? PermissionStatus.denied;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PermissionTile(
                    info: info,
                    status: status,
                    onTap: () async {
                      if (status.isPermanentlyDenied) {
                        await openAppSettings();
                      } else {
                        await _request(info.permission);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final mode = context.watch<ThemeModeService>().mode;
    final service = context.read<ThemeModeService>();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: AppGradients.cyberAccent,
                ),
                child: const Icon(Icons.palette_outlined,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appearance',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        )),
                    Text(
                      'Pick a theme — system follows your phone setting.',
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ThemeChip(
                  label: 'System',
                  icon: Icons.brightness_auto,
                  selected: mode == ThemeMode.system,
                  onTap: () => service.set(ThemeMode.system),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ThemeChip(
                  label: 'Light',
                  icon: Icons.light_mode_outlined,
                  selected: mode == ThemeMode.light,
                  onTap: () => service.set(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ThemeChip(
                  label: 'Dark',
                  icon: Icons.dark_mode_outlined,
                  selected: mode == ThemeMode.dark,
                  onTap: () => service.set(ThemeMode.dark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : palette.hairlineSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : palette.hairline,
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20,
                color: selected ? Colors.white : palette.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermInfo {
  const _PermInfo({
    required this.permission,
    required this.label,
    required this.reason,
    required this.riskIfGranted,
  });

  final Permission permission;
  final String label;
  final String reason;
  final String riskIfGranted;
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.info,
    required this.status,
    required this.onTap,
  });

  final _PermInfo info;
  final PermissionStatus status;
  final VoidCallback onTap;

  ({Color color, String label, IconData icon}) get _statusStyle {
    if (status.isGranted) {
      return (
        color: AppColors.safe,
        label: 'Granted',
        icon: Icons.check_circle,
      );
    }
    if (status.isPermanentlyDenied) {
      return (
        color: AppColors.danger,
        label: 'Blocked',
        icon: Icons.block,
      );
    }
    return (
      color: AppColors.warning,
      label: 'Not granted',
      icon: Icons.warning_amber_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _statusStyle;
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: s.color.withOpacity(0.12),
          child: Icon(s.icon, color: s.color),
        ),
        title: Text(info.label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(info.reason,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text('Risk: ${info.riskIfGranted}',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        trailing: TextButton(
          onPressed: onTap,
          child: Text(
            status.isGranted
                ? 'Manage'
                : status.isPermanentlyDenied
                    ? 'Open settings'
                    : 'Allow',
          ),
        ),
      ),
    );
  }
}
