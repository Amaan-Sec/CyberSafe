import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/language_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/speak_button.dart';

class CyberNewsScreen extends StatefulWidget {
  const CyberNewsScreen({super.key});

  @override
  State<CyberNewsScreen> createState() => _CyberNewsScreenState();
}

class _CyberNewsScreenState extends State<CyberNewsScreen> {
  static const String _feedUrl = 'http://164.52.194.98:8000/api/news/feed';

  bool _loading = true;
  String? _error;
  List<_Advisory> _advisories = const [];
  List<_NewsItem> _news = const [];
  String _fetchedAt = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp =
          await http.get(Uri.parse(_feedUrl)).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final advisories = ((j['advisories'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_Advisory.fromJson)
          .toList();
      final news = ((j['news'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_NewsItem.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _advisories = advisories;
        _news = news;
        _fetchedAt = (j['news_fetched_at'] ?? '') as String;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load news: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cyber news & alerts'),
        actions: [
          const LanguagePicker(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.cloud_off, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    final df = DateFormat('dd MMM, HH:mm');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ------ Section 1: CyberSafe advisories (pinned) ------
        Row(
          children: [
            const Icon(Icons.campaign, color: AppColors.danger, size: 20),
            const SizedBox(width: 8),
            const Text(
              'CyberSafe advisories',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'HIGH PRIORITY',
                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_advisories.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No active advisories from CyberSafe right now.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          ..._advisories.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AdvisoryCard(item: a, df: df, onTap: () => _openAdvisory(a)),
              )),

        const SizedBox(height: 20),

        // ------ Section 2: Latest cyber news (RSS) ------
        Row(
          children: [
            const Icon(Icons.public, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Latest cyber news',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            if (_fetchedAt.isNotEmpty)
              Text('Updated $_fetchedAt',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'From The Hacker News, BleepingComputer, Krebs on Security — refreshed every few hours.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        if (_news.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No news loaded.', style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          ..._news.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _NewsCard(item: n, df: df, onTap: () => _openLink(n.link)),
              )),
      ],
    );
  }

  void _openAdvisory(_Advisory a) {
    final df = DateFormat('dd MMM yyyy, HH:mm');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(a.category,
                        style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  const Text('CyberSafe',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 10),
              Text(a.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(df.format(a.date),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              SpeakButton(
                text: [a.title, a.summary, a.body].where((s) => s.isNotEmpty).join('. '),
                label: 'Read aloud',
              ),
              const SizedBox(height: 14),
              Text(a.summary,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
              if (a.body.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(a.body, style: const TextStyle(fontSize: 14, height: 1.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _AdvisoryCard extends StatelessWidget {
  const _AdvisoryCard({required this.item, required this.df, required this.onTap});
  final _Advisory item;
  final DateFormat df;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.danger.withOpacity(0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(item.category,
                        style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  Text(df.format(item.date),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 8),
              Text(item.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(item.summary,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, required this.df, required this.onTap});
  final _NewsItem item;
  final DateFormat df;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(item.source,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  Text(item.date != null ? df.format(item.date!) : '',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(width: 4),
                  const Icon(Icons.open_in_new, size: 12, color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 6),
              Text(item.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3)),
              if (item.summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(item.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary, height: 1.35)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

DateTime? _parseTs(String s) {
  if (s.isEmpty) return null;
  try {
    return DateTime.parse(s.replaceFirst(' ', 'T'));
  } catch (_) {
    return null;
  }
}

class _Advisory {
  _Advisory({
    required this.title,
    required this.summary,
    required this.body,
    required this.date,
    required this.category,
  });
  final String title;
  final String summary;
  final String body;
  final DateTime date;
  final String category;

  factory _Advisory.fromJson(Map<String, dynamic> j) {
    final ts = (j['updated'] ?? j['created'] ?? '') as String;
    return _Advisory(
      title: (j['title'] ?? '') as String,
      summary: (j['summary'] ?? '') as String,
      body: (j['body'] ?? '') as String,
      date: _parseTs(ts) ?? DateTime.now(),
      category: (j['category'] ?? 'Advisory') as String,
    );
  }
}

class _NewsItem {
  _NewsItem({
    required this.title,
    required this.summary,
    required this.link,
    required this.date,
    required this.source,
  });
  final String title;
  final String summary;
  final String link;
  final DateTime? date;
  final String source;

  factory _NewsItem.fromJson(Map<String, dynamic> j) => _NewsItem(
        title: (j['title'] ?? '') as String,
        summary: (j['summary'] ?? '') as String,
        link: (j['link'] ?? '') as String,
        date: _parseTs((j['published'] ?? '') as String),
        source: (j['source'] ?? 'News') as String,
      );
}
