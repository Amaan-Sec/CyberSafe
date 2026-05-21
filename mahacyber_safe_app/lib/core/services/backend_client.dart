import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Talks to the MahaCyber Safe prototype backend.
///
/// Endpoint is hardcoded here for the prototype — in production this should
/// come from a build flavour / remote config.
class BackendClient {
  static const String _baseUrl = 'http://164.52.194.98:8000';

  static const _kDeviceIdKey = 'mcs_device_id';
  static const _kCitizenKey = 'mcs_citizen_email';

  String? _deviceId;
  String? _model;
  String? _os;
  String? _appVer;
  String? _citizen;

  /// Persist the citizen identity (email used at login) and immediately
  /// re-register the device so the admin console reflects the new owner.
  Future<void> setCitizen(String email) async {
    _citizen = email.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCitizenKey, _citizen!);
    await registerDevice();
  }

  Future<String?> _getCitizen() async {
    if (_citizen != null) return _citizen;
    final prefs = await SharedPreferences.getInstance();
    _citizen = prefs.getString(_kCitizenKey);
    return _citizen;
  }

  Future<String> _getOrCreateDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();

    // Prefer a stable hardware identifier so the same physical device keeps the
    // same ID across uninstall/reinstall (SharedPreferences gets wiped on
    // uninstall, so a locally-generated UUID would fragment the same device
    // into multiple registrations).
    String? hardwareId;
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        // ANDROID_ID is stable per (signing key, user) on the device.
        hardwareId = a.id;
      } else if (Platform.isIOS) {
        final i = await plugin.iosInfo;
        // identifierForVendor is stable per app vendor on the device.
        hardwareId = i.identifierForVendor;
      }
    } catch (e) {
      debugPrint('hardware id lookup failed: $e');
    }

    String id;
    if (hardwareId != null && hardwareId.isNotEmpty) {
      // Make it shortish and recognisable: DEV-<first 12 chars uppercased>.
      final clean = hardwareId.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
      final src = clean.isNotEmpty ? clean : hardwareId;
      id = 'DEV-${src.toUpperCase().substring(0, src.length < 12 ? src.length : 12)}';
    } else {
      // Fallback: cached UUID-ish id (only used on platforms without hardware id).
      id = prefs.getString(_kDeviceIdKey) ?? () {
        final rnd = DateTime.now().microsecondsSinceEpoch.toRadixString(16) +
            (DateTime.now().millisecond * 7919).toRadixString(16);
        return 'DEV-${rnd.toUpperCase().padLeft(12, '0').substring(0, 12)}';
      }();
    }

    await prefs.setString(_kDeviceIdKey, id);
    _deviceId = id;
    return id;
  }

  Future<void> _collectDeviceMeta() async {
    if (_model != null) return;
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        _model = '${a.manufacturer} ${a.model}'.trim();
        _os = 'Android ${a.version.release}';
      } else if (Platform.isIOS) {
        final i = await plugin.iosInfo;
        _model = i.utsname.machine;
        _os = '${i.systemName} ${i.systemVersion}';
      } else {
        _model = 'Unknown';
        _os = Platform.operatingSystem;
      }
      final pkg = await PackageInfo.fromPlatform();
      _appVer = '${pkg.version}+${pkg.buildNumber}';
    } catch (e) {
      debugPrint('device meta collection failed: $e');
      _model ??= 'Unknown';
      _os ??= 'Unknown';
      _appVer ??= '0.0.0';
    }
  }

  /// Register the device with the backend. Safe to call repeatedly — it upserts.
  Future<void> registerDevice() async {
    try {
      final id = await _getOrCreateDeviceId();
      await _collectDeviceMeta();
      final citizen = await _getCitizen();
      final body = jsonEncode({
        'deviceId': id,
        if (citizen != null && citizen.isNotEmpty) 'citizen': citizen,
        'model': _model,
        'os': _os,
        'appVer': _appVer,
        'rasp': 'clean',
        'status': 'Active',
      });
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/api/devices/register'),
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 8));
      debugPrint('Device register: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      debugPrint('Device register failed: $e');
    }
  }

  /// Trigger an SOS incident on the backend. Returns the server-assigned
  /// incident id, or null on failure.
  Future<int?> triggerSos({
    required double lat,
    required double lng,
    required double accuracy,
    String? message,
  }) async {
    try {
      final id = await _getOrCreateDeviceId();
      await _collectDeviceMeta();
      final citizen = await _getCitizen();
      final body = jsonEncode({
        'deviceId': id,
        if (citizen != null && citizen.isNotEmpty) 'citizen': citizen,
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'message': message ?? '',
        'model': _model,
        'os': _os,
        'appVer': _appVer,
      });
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/api/sos'),
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        return (j['incident'] as Map?)?['id'] as int?;
      }
    } catch (e) {
      debugPrint('SOS trigger failed: $e');
    }
    return null;
  }

  /// Identity bundle for tagging scans/threats sent to the backend.
  Future<Map<String, String>> identityFields() async {
    final id = await _getOrCreateDeviceId();
    await _collectDeviceMeta();
    final citizen = await _getCitizen();
    return {
      'deviceId': id,
      if (citizen != null && citizen.isNotEmpty) 'citizen': citizen,
    };
  }

  /// Log a scan event so the admin "URL / QR Scans (7d)" tile and the
  /// Scan Analytics charts reflect real on-device activity.
  ///
  /// [kind] must be one of: url, qr, wifi, breach, ip, call_forward.
  /// [verdict] one of: safe, suspicious, malicious, clean, breached, unknown.
  Future<void> recordScan({
    required String kind,
    required String verdict,
    String target = '',
    int latencyMs = 0,
  }) async {
    try {
      final ident = await identityFields();
      final body = jsonEncode({
        ...ident,
        'kind': kind,
        'verdict': verdict,
        'target': target,
        'latency_ms': latencyMs,
      });
      await http
          .post(
            Uri.parse('$_baseUrl/api/scans'),
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('recordScan failed: $e');
    }
  }

  /// Send an SMS to the server-side fraud inspector. Returns the parsed
  /// verdict map or null on failure.
  Future<Map<String, dynamic>?> scanSms({
    required String text,
    String sender = '',
  }) async {
    try {
      final ident = await identityFields();
      final body = jsonEncode({
        ...ident,
        'text': text,
        'sender': sender,
      });
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/api/scan/sms'),
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('scanSms failed: $e');
    }
    return null;
  }

  /// File a grievance / support ticket. Returns the server-assigned ID.
  Future<String?> submitGrievance({
    required String subject,
    required String category,
    required String description,
    String contact = '',
  }) async {
    try {
      final id = await _getOrCreateDeviceId();
      await _collectDeviceMeta();
      final citizen = await _getCitizen();
      final body = jsonEncode({
        'deviceId': id,
        if (citizen != null && citizen.isNotEmpty) 'citizen': citizen,
        'subject': subject,
        'category': category,
        'description': description,
        'contact': contact,
        'model': _model,
        'os': _os,
        'appVer': _appVer,
      });
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/api/grievances'),
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        return (j['item'] as Map?)?['id'] as String?;
      }
    } catch (e) {
      debugPrint('submitGrievance failed: $e');
    }
    return null;
  }

  /// Fetch this device's own grievances (for the "My Tickets" list).
  Future<List<Map<String, dynamic>>> myGrievances() async {
    try {
      final id = await _getOrCreateDeviceId();
      final resp = await http
          .get(Uri.parse('$_baseUrl/api/grievances?deviceId=$id'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('myGrievances failed: $e');
    }
    return const [];
  }

  /// Report a single RASP threat. Fire-and-forget.
  Future<void> reportThreat({
    required String type,
    required String severity,
    String? details,
  }) async {
    try {
      final id = await _getOrCreateDeviceId();
      await _collectDeviceMeta();
      final citizen = await _getCitizen();
      final body = jsonEncode({
        'deviceId': id,
        if (citizen != null && citizen.isNotEmpty) 'citizen': citizen,
        'type': type,
        'severity': severity,
        'model': _model,
        'details': details,
      });
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/api/threats'),
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 8));
      debugPrint('Threat report: ${resp.statusCode}');
    } catch (e) {
      debugPrint('Threat report failed: $e');
    }
  }
}
