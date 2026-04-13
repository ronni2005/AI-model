// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../services/locale_service.dart';
import '../services/speech_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _total = 0, _emergency = 0, _urgent = 0, _normal = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final db = DatabaseService.instance;
    final res = await Future.wait([
      db.totalCount(),
      db.countByRisk('Emergency'),
      db.countByRisk('Urgent'),
      db.countByRisk('Normal'),
    ]);
    if (!mounted) return;
    setState(() {
      _total     = res[0];
      _emergency = res[1];
      _urgent    = res[2];
      _normal    = res[3];
    });
  }

  Future<void> _changeLanguage() async {
    final langs = LocaleService.kLanguages.keys.toList();
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Language'),
        children: langs.map((lang) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, lang),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(lang, style: const TextStyle(fontSize: 16)),
          ),
        )).toList(),
      ),
    );
    if (chosen == null) return;
    final code = LocaleService.kLanguages[chosen]!;
    await LocaleService.instance.load(code);
    SpeechService.instance
        .setLocale(SpeechService.kLocales[chosen] ?? 'en_IN');
    RuralHealthApp.refreshLocale();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App bar ─────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              backgroundColor: AppTheme.primary,
              actions: [
                IconButton(
                  icon: const Icon(Icons.language, color: Colors.white),
                  onPressed: _changeLanguage,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('app_title'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text('CureBay • Offline AI',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.8))),
                  ],
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1B6B3A), Color(0xFF00897B)],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Icon(Icons.local_hospital_rounded,
                          size: 80,
                          color: Colors.white.withOpacity(0.12)),
                    ),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Offline badge ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.normal),
                    ),
                    child: const Row(children: [
                      Icon(Icons.wifi_off_rounded,
                          color: AppTheme.normal, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Fully offline — AI runs on device, no internet needed',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1B5E20),
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                  ).animate().fadeIn(duration: 400.ms),

                  const SizedBox(height: 20),

                  // ── Primary CTA ───────────────────────────────────
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_search_rounded, size: 22),
                    label: Text(tr('start_assessment'),
                        style: const TextStyle(fontSize: 16)),
                    onPressed: () =>
                        Navigator.pushNamed(context, '/assessment')
                            .then((_) => _loadStats()),
                  ).animate()
                      .slideY(begin: 0.3, duration: 400.ms)
                      .fadeIn(duration: 400.ms),

                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    icon: const Icon(Icons.history_rounded, size: 20),
                    label: Text(tr('patient_records')),
                    onPressed: () =>
                        Navigator.pushNamed(context, '/records')
                            .then((_) => _loadStats()),
                  ).animate()
                      .slideY(begin: 0.3, delay: 80.ms, duration: 400.ms)
                      .fadeIn(delay: 80.ms),

                  const SizedBox(height: 28),

                  // ── Stats ─────────────────────────────────────────
                  Text('Overview',
                      style: Theme.of(context).textTheme.titleLarge)
                      .animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(child: _StatCard(
                        label: 'Total', value: _total,
                        color: AppTheme.accent,
                        icon: Icons.people_rounded)),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(
                        label: 'Emergency', value: _emergency,
                        color: AppTheme.emergency,
                        icon: Icons.emergency_rounded)),
                  ]).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 10),

                  Row(children: [
                    Expanded(child: _StatCard(
                        label: 'Urgent', value: _urgent,
                        color: AppTheme.urgent,
                        icon: Icons.warning_amber_rounded)),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(
                        label: 'Normal', value: _normal,
                        color: AppTheme.normal,
                        icon: Icons.check_circle_rounded)),
                  ]).animate().fadeIn(delay: 250.ms),

                  const SizedBox(height: 28),

                  // ── Features ──────────────────────────────────────
                  Text('Features',
                      style: Theme.of(context).textTheme.titleLarge)
                      .animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 10),
                  const Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _FeatureChip(icon: Icons.wifi_off_rounded,       label: '100% Offline'),
                      _FeatureChip(icon: Icons.mic_rounded,            label: 'Voice Input'),
                      _FeatureChip(icon: Icons.image_rounded,          label: 'Image Upload'),
                      _FeatureChip(icon: Icons.translate_rounded,      label: 'Multi-language'),
                      _FeatureChip(icon: Icons.picture_as_pdf_rounded, label: 'PDF Report'),
                      _FeatureChip(icon: Icons.storage_rounded,        label: 'Local Records'),
                    ],
                  ).animate().fadeIn(delay: 350.ms),

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _StatCard({required this.label, required this.value,
      required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 26),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value.toString(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ]),
    ]),
  );
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 16, color: AppTheme.primary),
    label: Text(label),
    backgroundColor: Colors.white,
    side: const BorderSide(color: Color(0xFFCCE5D0)),
  );
}
