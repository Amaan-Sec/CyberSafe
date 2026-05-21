import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/rasp/rasp_service.dart';
import '../../core/theme/app_theme.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  static const _kContactsKey = 'mcs_sos_contacts';
  static const _kLastIncidentKey = 'mcs_sos_last';

  bool _sending = false;
  String? _status; // ui-status text
  _LastIncident? _last;
  List<_Contact> _contacts = [];
  final _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kContactsKey) ?? const [];
    final last = prefs.getString(_kLastIncidentKey);
    setState(() {
      _contacts = raw
          .map((e) {
            final parts = e.split('|');
            return parts.length == 2 ? _Contact(parts[0], parts[1]) : null;
          })
          .whereType<_Contact>()
          .toList();
      if (last != null) {
        try {
          final j = jsonDecode(last) as Map<String, dynamic>;
          _last = _LastIncident(
            id: j['id'] as int?,
            lat: (j['lat'] as num).toDouble(),
            lng: (j['lng'] as num).toDouble(),
            timestamp: j['ts'] as String,
          );
        } catch (_) {}
      }
    });
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kContactsKey,
      _contacts.map((c) => '${c.name}|${c.phone}').toList(),
    );
  }

  Future<Position?> _resolveLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _toast('Please enable location services.');
      await Geolocator.openLocationSettings();
      return null;
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      _toast('Location permission permanently denied. Enable from settings.');
      await Geolocator.openAppSettings();
      return null;
    }
    if (perm == LocationPermission.denied) {
      _toast('Location permission required for SOS.');
      return null;
    }
    setState(() => _status = 'Locating you…');
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      // Fall back to last known if GPS is slow.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          _toast('Using last-known location (GPS slow).');
          return last;
        }
      } catch (_) {}
      _toast('Could not get location: $e');
      return null;
    }
  }

  Future<void> _triggerSos() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _status = null;
    });

    final pos = await _resolveLocation();
    if (pos == null) {
      setState(() {
        _sending = false;
        _status = null;
      });
      return;
    }

    setState(() => _status = 'Sending to CyberSafe…');
    final rasp = context.read<RaspService>();
    final incidentId = await rasp.backend.triggerSos(
      lat: pos.latitude,
      lng: pos.longitude,
      accuracy: pos.accuracy,
      message: _msgCtrl.text.trim(),
    );

    final ts = DateTime.now().toIso8601String();
    final last = _LastIncident(
      id: incidentId,
      lat: pos.latitude,
      lng: pos.longitude,
      timestamp: ts,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kLastIncidentKey,
      jsonEncode({'id': incidentId, 'lat': pos.latitude, 'lng': pos.longitude, 'ts': ts}),
    );

    if (!mounted) return;
    setState(() {
      _sending = false;
      _last = last;
      _status = incidentId != null
          ? 'SOS sent. CyberSafe has been notified.'
          : 'Sent locally — backend unreachable. Use SMS option below.';
    });
    _toast(incidentId != null ? 'SOS sent' : 'SOS queued (offline)');

    // Offer to message trusted contacts.
    if (_contacts.isNotEmpty) {
      await _maybeSendSms(pos);
    }
  }

  Future<void> _maybeSendSms(Position pos) async {
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notify trusted contacts?'),
        content: Text(
          'Open your SMS app to send your live location to ${_contacts.length} contact(s)?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Skip')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send SMS')),
        ],
      ),
    );
    if (go != true) return;

    final mapsUrl = 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
    final body =
        'EMERGENCY — I need help. My location: $mapsUrl (±${pos.accuracy.toStringAsFixed(0)} m). '
        '— Sent via CyberSafe.';
    final numbers = _contacts.map((c) => c.phone).join(',');
    final uri = Uri.parse('sms:$numbers?body=${Uri.encodeComponent(body)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _toast('No SMS app available on this device.');
    }
  }

  Future<void> _dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _toast(String m) => Fluttertoast.showToast(msg: m);

  Future<void> _openContactsEditor() async {
    final result = await showModalBottomSheet<List<_Contact>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ContactsEditor(initial: _contacts),
    );
    if (result != null) {
      setState(() => _contacts = result);
      await _saveContacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency SOS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.sos, color: Colors.white, size: 56),
                  const SizedBox(height: 12),
                  const Text(
                    'In immediate danger?',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Trigger SOS to share your live location with CyberSafe and (optionally) your trusted contacts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _msgCtrl,
                    maxLength: 200,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Optional note (what is happening?)',
                      hintStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Colors.black26,
                      counterStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _sending ? null : _triggerSos,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Icon(Icons.alarm),
                    label: Text(_sending ? (_status ?? 'Sending…') : 'Trigger SOS now'),
                  ),
                  if (_status != null && !_sending) ...[
                    const SizedBox(height: 10),
                    Text(_status!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_last != null) _lastIncidentCard(),
            const SizedBox(height: 20),
            _contactsCard(),
            const SizedBox(height: 24),
            const Text('Quick-dial helplines', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _HelplineTile(icon: Icons.local_police, label: 'Police', number: '112', onTap: () => _dial('112')),
            _HelplineTile(icon: Icons.account_balance, label: 'National Cyber Crime Helpline', number: '1930', onTap: () => _dial('1930')),
            _HelplineTile(icon: Icons.woman, label: 'Women helpline', number: '1091', onTap: () => _dial('1091')),
            _HelplineTile(icon: Icons.child_care, label: 'Child helpline', number: '1098', onTap: () => _dial('1098')),
          ],
        ),
      ),
    );
  }

  Widget _lastIncidentCard() {
    final l = _last!;
    final ts = DateTime.tryParse(l.timestamp)?.toLocal();
    final tsStr = ts == null ? l.timestamp : '${ts.toString().split('.').first}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Last SOS', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (l.id != null)
                  Text('#${l.id}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Time: $tsStr'),
            Text('Location: ${l.lat.toStringAsFixed(5)}, ${l.lng.toStringAsFixed(5)}'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('https://maps.google.com/?q=${l.lat},${l.lng}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Open in Maps'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.contact_phone, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Trusted contacts', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openContactsEditor,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
              ],
            ),
            if (_contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Add family or friends who should receive your live location via SMS when you trigger SOS.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ..._contacts.map(
                (c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.person_outline),
                  title: Text(c.name),
                  subtitle: Text(c.phone),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Contact {
  _Contact(this.name, this.phone);
  final String name;
  final String phone;
}

class _LastIncident {
  _LastIncident({required this.id, required this.lat, required this.lng, required this.timestamp});
  final int? id;
  final double lat;
  final double lng;
  final String timestamp;
}

class _ContactsEditor extends StatefulWidget {
  const _ContactsEditor({required this.initial});
  final List<_Contact> initial;

  @override
  State<_ContactsEditor> createState() => _ContactsEditorState();
}

class _ContactsEditorState extends State<_ContactsEditor> {
  late List<_Contact> _items;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.initial);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _add() {
    final n = _nameCtrl.text.trim();
    final p = _phoneCtrl.text.trim();
    if (n.isEmpty || p.isEmpty) return;
    setState(() {
      _items.add(_Contact(n, p));
      _nameCtrl.clear();
      _phoneCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Trusted contacts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ..._items.asMap().entries.map((e) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person),
                title: Text(e.value.name),
                subtitle: Text(e.value.phone),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => setState(() => _items.removeAt(e.key)),
                ),
              )),
          const Divider(),
          Row(
            children: [
              Expanded(child: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'))),
              IconButton(icon: const Icon(Icons.add_circle, color: AppColors.primary), onPressed: _add),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, _items), child: const Text('Save'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _HelplineTile extends StatelessWidget {
  const _HelplineTile({required this.icon, required this.label, required this.number, required this.onTap});

  final IconData icon;
  final String label;
  final String number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(number),
        trailing: IconButton(icon: const Icon(Icons.call, color: AppColors.safe), onPressed: onTap),
      ),
    );
  }
}
