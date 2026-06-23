import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../a2ui/a2ui_models.dart';
import '../a2ui/a2ui_renderer.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/catalog_widgets.dart';

/// A turn in the coach conversation: either the user's text or a coach surface.
class _Turn {
  final bool isUser;
  final String? text;
  final A2Surface? surface;
  _Turn.user(this.text)
      : isUser = true,
        surface = null;
  _Turn.coach(this.surface)
      : isUser = false,
        text = null;
}

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final List<_Turn> _turns = [];
  final List<ChatMessage> _history = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _busy = false;

  @override
  void dispose() {
    for (final t in _turns) {
      t.surface?.dispose();
    }
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _onCoachEvent(A2Event e) async {
    final app = context.read<AppState>();
    final msg = await app.handleA2Event(e);
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    final app = context.read<AppState>();
    HapticFeedback.lightImpact();
    _input.clear();

    final surface = A2Surface();
    setState(() {
      _busy = true;
      _turns.add(_Turn.user(text));
      _turns.add(_Turn.coach(surface));
      _history.add(ChatMessage('user', text));
    });
    _scrollToEnd();

    final ctx = await app.buildCoachContext();
    await app.coach.chat(
      context: ctx,
      messages: _history.map((m) => m.toJson()).toList(),
      surface: surface,
    );
    // Record a short text echo into history so multi-turn keeps context.
    _history.add(ChatMessage('assistant', _summarize(surface)));
    if (mounted) setState(() => _busy = false);
    _scrollToEnd();
  }

  Future<void> _weeklyReview() async {
    if (_busy) return;
    final app = context.read<AppState>();
    HapticFeedback.mediumImpact();
    final surface = A2Surface();
    setState(() {
      _busy = true;
      _turns.add(_Turn.user('Weekly review'));
      _turns.add(_Turn.coach(surface));
    });
    _scrollToEnd();
    final ctx = await app.buildCoachContext();
    final logs = await app.buildLogsPayload(days: 14);
    await app.coach.weeklyReview(context: ctx, logs: logs, surface: surface);
    if (mounted) setState(() => _busy = false);
    _scrollToEnd();
  }

  String _summarize(A2Surface s) {
    for (final c in s.components.values) {
      if (c.type == 'CoachMessage') return c.props['text']?.toString() ?? '';
    }
    return '[coaching surface]';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bone,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(color: AppColors.clay, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('L', style: AppType.display(16, color: AppColors.bone)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Coach', style: AppType.display(17, weight: FontWeight.w800)),
                Text('Phase 1 · Shape Back', style: AppType.body(11, color: AppColors.sageGrey)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Weekly review action strip.
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 4, AppSpacing.md, 4),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Weekly review',
                    icon: Icons.insights_rounded,
                    style: 'tonal',
                    dense: true,
                    expand: true,
                    onPressed: _busy ? null : _weeklyReview,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _turns.isEmpty
                ? _emptyState()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
                    itemCount: _turns.length,
                    itemBuilder: (context, i) {
                      final turn = _turns[i];
                      if (turn.isUser) return _userBubble(turn.text!);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: A2SurfaceView(surface: turn.surface!, onEvent: _onCoachEvent),
                      );
                    },
                  ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final prompts = [
      'Knees feel off on leg press — sub?',
      'Missed protein yesterday, adjust today?',
      "I'm traveling this week, keep me on track",
      'How should I push incline this week?',
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: AppColors.clay.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.clay, size: 26),
          ),
        ),
        const SizedBox(height: 16),
        Text('Talk to your coach', textAlign: TextAlign.center, style: AppType.display(22, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Ask anything. The coach answers with live cards you can apply — swaps, target tweaks, a weekly read.',
          textAlign: TextAlign.center,
          style: AppType.body(14, color: AppColors.sageGrey, height: 1.4),
        ),
        const SizedBox(height: 24),
        ...prompts.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                onTap: () => _send(p),
                child: Row(
                  children: [
                    const Icon(Icons.north_east_rounded, size: 16, color: AppColors.clay),
                    const SizedBox(width: 12),
                    Expanded(child: Text(p, style: AppType.body(14, weight: FontWeight.w600))),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _userBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.clay,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(text, style: AppType.body(14, color: AppColors.bone, weight: FontWeight.w600, height: 1.3)),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 8),
        decoration: const BoxDecoration(
          color: AppColors.bone,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Message your coach…',
                  hintStyle: AppType.body(14, color: AppColors.sageGrey),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.pill), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _busy ? null : () => _send(),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _busy ? AppColors.sageGrey : AppColors.clay,
                  shape: BoxShape.circle,
                ),
                child: _busy
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bone),
                      )
                    : const Icon(Icons.arrow_upward_rounded, color: AppColors.bone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
