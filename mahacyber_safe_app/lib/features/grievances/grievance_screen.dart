import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/backend_client.dart';
import '../../core/theme/app_theme.dart';

const _categories = <String>[
  'Financial Fraud',
  'Phishing',
  'Malware',
  'Account Security',
  'Identity Theft',
  'Cyberbullying',
  'Fake Apps',
  'Other',
];

class GrievanceScreen extends StatefulWidget {
  const GrievanceScreen({super.key});

  @override
  State<GrievanceScreen> createState() => _GrievanceScreenState();
}

class _GrievanceScreenState extends State<GrievanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);
  final _backend = BackendClient();
  Future<List<Map<String, dynamic>>>? _myTickets;

  @override
  void initState() {
    super.initState();
    _loadMyTickets();
  }

  void _loadMyTickets() {
    setState(() => _myTickets = _backend.myGrievances());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File a Grievance'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note), text: 'New ticket'),
            Tab(icon: Icon(Icons.list_alt), text: 'My tickets'),
            Tab(icon: Icon(Icons.support_agent), text: 'Helplines'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _NewTicketTab(onSubmitted: () {
            _loadMyTickets();
            _tab.animateTo(1);
          }),
          _MyTicketsTab(
            future: _myTickets,
            onRefresh: _loadMyTickets,
          ),
          const _HelplinesTab(),
        ],
      ),
    );
  }
}

class _NewTicketTab extends StatefulWidget {
  const _NewTicketTab({required this.onSubmitted});
  final VoidCallback onSubmitted;

  @override
  State<_NewTicketTab> createState() => _NewTicketTabState();
}

class _NewTicketTabState extends State<_NewTicketTab> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _contact = TextEditingController();
  String _category = _categories.first;
  bool _submitting = false;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final id = await BackendClient().submitGrievance(
      subject: _subject.text.trim(),
      category: _category,
      description: _description.text.trim(),
      contact: _contact.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit. Please try again.')),
      );
      return;
    }
    _subject.clear();
    _description.clear();
    _contact.clear();
    setState(() => _category = _categories.first);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ticket $id raised — we will get back to you.')),
    );
    widget.onSubmitted();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Report a cyber incident, scam or app issue to the CyberSafe '
              'team. We respond within 48 hours.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subject,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'e.g. Lost ₹15,000 to UPI scam',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 5) ? 'Min 5 characters' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 20) ? 'Min 20 characters' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contact,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'Phone or email (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_submitting ? 'Submitting…' : 'Submit ticket'),
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: '1930')),
              icon: const Icon(Icons.phone_in_talk, color: AppColors.danger),
              label: const Text(
                'Active financial fraud? Call 1930 now',
                style: TextStyle(color: AppColors.danger),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelplinesTab extends StatelessWidget {
  const _HelplinesTab();

  static const _helplines = <_Helpline>[
    _Helpline(
      label: 'National Cybercrime Helpline',
      number: '1930',
      subtitle: 'For financial fraud — report within 24 hours',
      icon: Icons.account_balance,
      accent: AppColors.danger,
    ),
    _Helpline(
      label: 'Police Emergency',
      number: '112',
      subtitle: 'All-India emergency response',
      icon: Icons.local_police,
      accent: AppColors.danger,
    ),
    _Helpline(
      label: 'Women Helpline',
      number: '1091',
      subtitle: 'For online harassment / stalking',
      icon: Icons.diversity_3,
      accent: Color(0xFFC2185B),
    ),
    _Helpline(
      label: 'Child Helpline',
      number: '1098',
      subtitle: 'Cyberbullying / online abuse of minors',
      icon: Icons.child_care,
      accent: Color(0xFF6750A4),
    ),
  ];

  static const _links = <_LinkItem>[
    _LinkItem(
      label: 'cybercrime.gov.in',
      url: 'https://cybercrime.gov.in',
      subtitle: 'File a detailed complaint online (I4C portal)',
    ),
    _LinkItem(
      label: 'Sancharsaathi (DoT)',
      url: 'https://sancharsaathi.gov.in',
      subtitle: 'Report stolen/lost mobile + spam SMS',
    ),
  ];

  Future<void> _call(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not dial $number')),
      );
    }
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Tap a number to dial. For UPI / banking fraud, call 1930 within 24 hours — '
          'the longer you wait, the harder recovery becomes.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        ..._helplines.map((h) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: h.accent.withOpacity(0.15),
                  child: Icon(h.icon, color: h.accent),
                ),
                title: Text(h.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(h.subtitle),
                trailing: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(h.display ?? h.number,
                        style: TextStyle(
                            color: h.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const Icon(Icons.call, size: 18, color: AppColors.safe),
                  ],
                ),
                onTap: () => _call(context, h.number),
              ),
            )),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text('Official portals',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        ..._links.map((l) => Card(
              child: ListTile(
                leading: const Icon(Icons.public, color: AppColors.primary),
                title: Text(l.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(l.subtitle),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _open(context, l.url),
              ),
            )),
        const SizedBox(height: 16),
        Card(
          color: const Color(0xFFFFF8E1),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Keep handy before you report',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text('• Transaction ID / UTR (for financial fraud)\n'
                    '• Screenshot of the message, call or app\n'
                    '• Phone number / UPI ID / website of the scammer\n'
                    '• Approximate time the incident happened',
                    style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Helpline {
  const _Helpline({
    required this.label,
    required this.number,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.display,
  });
  final String label;
  final String number;
  final String? display;
  final String subtitle;
  final IconData icon;
  final Color accent;
}

class _LinkItem {
  const _LinkItem({required this.label, required this.url, required this.subtitle});
  final String label;
  final String url;
  final String subtitle;
}

class _MyTicketsTab extends StatelessWidget {
  const _MyTicketsTab({required this.future, required this.onRefresh});
  final Future<List<Map<String, dynamic>>>? future;
  final VoidCallback onRefresh;

  Color _statusColor(String s) {
    switch (s) {
      case 'Resolved':
        return AppColors.safe;
      case 'Open':
        return AppColors.primary;
      case 'Escalated':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Icon(Icons.inbox_outlined, size: 48, color: Colors.black26),
                SizedBox(height: 8),
                Center(
                  child: Text(
                    'No tickets yet.\nPull to refresh.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final g = list[i];
              final status = (g['status'] ?? 'Open') as String;
              final color = _statusColor(status);
              return Card(
                child: ListTile(
                  title: Text(g['subject'] ?? ''),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${g['id']} · ${g['category']}',
                          style: const TextStyle(fontSize: 11)),
                      if ((g['adminNote'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Note: ${g['adminNote']}',
                            style: const TextStyle(
                                fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
