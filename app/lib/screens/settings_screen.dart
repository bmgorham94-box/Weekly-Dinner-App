import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/catalog_widgets.dart';

/// Setup — coach server connection, a health-check, and local-data notes.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlController;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: context.read<AppState>().serverUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = context.read<AppState>();
    await app.setServerUrl(_urlController.text);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Saved')));
  }

  Future<void> _testConnection() async {
    if (_testing) return;
    setState(() => _testing = true);
    final url = _urlController.text.trim();
    String message = "Couldn't reach coach";
    try {
      final res = await http
          .get(Uri.parse('$url/health'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) message = 'Coach online ✓';
    } catch (_) {
      message = "Couldn't reach coach";
    }
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotion(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Setup', style: AppType.display(20, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
          children: [
            // ----- Coach server URL -----
            const SectionLabel(text: 'Coach server'),
            const SizedBox(height: AppSpacing.sm),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    style: AppType.body(15, weight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Server URL',
                      helperMaxLines: 4,
                      helperText:
                          "Point at your computer's LAN IP, e.g. http://192.168.1.20:8787 "
                          "(Android emulator: http://10.0.2.2:8787, iOS simulator: "
                          "http://localhost:8787)",
                      filled: true,
                      fillColor: AppColors.bone,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                            label: 'Save', icon: Icons.check_rounded, expand: true, onPressed: _save),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: PrimaryButton(
                          label: _testing ? 'Testing…' : 'Test connection',
                          style: 'tonal',
                          icon: Icons.wifi_tethering_rounded,
                          expand: true,
                          onPressed: _testing ? null : _testConnection,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ----- Daily nudge -----
            const SectionLabel(text: 'Daily nudge'),
            const SizedBox(height: AppSpacing.sm),
            SoftCard(
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined,
                      color: AppColors.clay, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Daily nudge scheduled for 8:30am',
                        style: AppType.body(14, weight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ----- About -----
            const SectionLabel(text: 'About'),
            const SizedBox(height: AppSpacing.sm),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('The Log · Phase 1 · Shape Back',
                      style: AppType.display(16, weight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Personal coach with an agentic AI coach (A2UI generative UI). '
                    'Data stored locally on this device.',
                    style: AppType.body(14, color: AppColors.sageGrey, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ----- Reduce-motion + storage notes -----
            const SectionLabel(text: 'On this device'),
            const SizedBox(height: AppSpacing.sm),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MetricRow(
                    label: 'Reduce motion',
                    value: reduce ? 'On' : 'Off',
                    color: reduce ? AppColors.sage : AppColors.sageGrey,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reduce
                        ? 'Animations are minimized to match your system accessibility setting.'
                        : 'Following your system accessibility setting for animations.',
                    style: AppType.body(12, color: AppColors.sageGrey, height: 1.35),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const HairlineDivider(),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          color: AppColors.sageGrey, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Meals, sets, weights, and check-in photos are stored locally on '
                          'this device only. Nothing syncs to the cloud.',
                          style: AppType.body(12, color: AppColors.sageGrey, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
