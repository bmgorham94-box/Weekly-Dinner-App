import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../a2ui/a2ui_models.dart';
import '../a2ui/a2ui_renderer.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../data/seed_data.dart';
import '../services/image_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/catalog_widgets.dart';

/// Progress — streaks, the bodyweight trend, and check-in photos with a
/// coach-powered "analyze vs last" comparison.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<CheckinPhoto> _photos = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final photos = await AppDatabase.instance.allPhotos();
    if (!mounted) return;
    setState(() => _photos = photos);
  }

  Future<void> _capture() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      XFile? picked;
      try {
        picked = await picker.pickImage(source: ImageSource.camera);
      } catch (_) {
        // Camera unavailable (e.g. simulator) — fall back to gallery.
        picked = await picker.pickImage(source: ImageSource.gallery);
      }
      if (picked == null) return;
      final app = context.read<AppState>();
      final path = await ImageService.compressAndStore(File(picked.path));
      await AppDatabase.instance.addPhoto(CheckinPhoto(
        date: app.dateKey,
        path: path,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
      HapticFeedback.mediumImpact();
      await _loadPhotos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text("Couldn't capture photo")));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete(CheckinPhoto photo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Delete check-in?', style: AppType.display(18, weight: FontWeight.w700)),
        content: Text('This removes the photo from this device.',
            style: AppType.body(14, color: AppColors.sageGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppType.body(14, color: AppColors.sageGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: AppType.body(14, weight: FontWeight.w700, color: AppColors.rose)),
          ),
        ],
      ),
    );
    if (ok == true && photo.id != null) {
      await AppDatabase.instance.removePhoto(photo.id!);
      await _loadPhotos();
    }
  }

  void _openViewer(CheckinPhoto photo) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          systemOverlayStyle: const SystemUiOverlayStyle(statusBarBrightness: Brightness.dark),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.file(File(photo.path), fit: BoxFit.contain),
          ),
        ),
      ),
    ));
  }

  Future<void> _analyze() async {
    if (_photos.length < 2) return;
    final app = context.read<AppState>();
    final latest = _photos[0];
    final previous = _photos[1];

    final surface = A2Surface();
    HapticFeedback.mediumImpact();

    // Show the live surface immediately; trigger the coach call after.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bone,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (sheetCtx, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Check-in analysis', style: AppType.display(22, weight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.md),
              A2SurfaceView(
                surface: surface,
                imageResolver: () =>
                    (FileImage(File(previous.path)), FileImage(File(latest.path))),
                onEvent: (e) async {
                  final msg = await app.handleA2Event(e);
                  if (msg != null && sheetCtx.mounted) {
                    ScaffoldMessenger.of(sheetCtx)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(msg)));
                  }
                },
              ),
            ],
          );
        },
      ),
    );

    try {
      final latestB64 = await ImageService.toBase64(latest.path);
      final previousB64 = await ImageService.toBase64(previous.path);
      final ctx = await app.buildCoachContext();
      await app.coach.photoAnalysis(
        context: ctx,
        imagesBase64: [latestB64, previousB64],
        surface: surface,
      );
    } catch (e) {
      surface.markFailed(e.toString(),
          fallback: "Couldn't analyze the photos. Eyeball it: shoulders and back show first.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.clay,
          onRefresh: () async {
            await app.refresh();
            await _loadPhotos();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl + 60),
            children: [
              // ----- Header -----
              Text(Seed.phaseLabel.toUpperCase(), style: AppType.label(AppColors.clay)),
              const SizedBox(height: AppSpacing.xs),
              Text('Progress', style: AppType.display(34, weight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.md),

              // ----- Streaks -----
              SoftCard(child: _StreaksRow(app: app, photoCount: _photos.length)),
              const SizedBox(height: AppSpacing.lg),

              // ----- Bodyweight trend -----
              const SectionLabel(text: 'Bodyweight'),
              const SizedBox(height: AppSpacing.sm),
              FutureBuilder<List<WeightEntry>>(
                future: app.allWeights(),
                builder: (context, snap) {
                  final weights = snap.data ?? const <WeightEntry>[];
                  return SoftCard(
                    child: SizedBox(
                      height: 220,
                      child: weights.isEmpty
                          ? Center(
                              child: Text(
                                'Log your bodyweight on Today to see the trend.',
                                textAlign: TextAlign.center,
                                style:
                                    AppType.body(14, color: AppColors.sageGrey, weight: FontWeight.w500),
                              ),
                            )
                          : _WeightChart(weights: weights),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // ----- Check-in photos -----
              const SectionLabel(text: 'Check-ins'),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(
                label: _busy ? 'Capturing…' : 'Capture check-in',
                icon: Icons.photo_camera_rounded,
                expand: true,
                onPressed: _busy ? null : _capture,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_photos.isEmpty)
                SoftCard(
                  child: Row(
                    children: [
                      const Icon(Icons.photo_library_outlined,
                          color: AppColors.sageGrey, size: 22),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'No check-ins yet — capture one to start your visual log.',
                          style: AppType.body(14,
                              color: AppColors.sageGrey, weight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _PhotoGrid(
                  photos: _photos,
                  onTap: _openViewer,
                  onLongPress: _confirmDelete,
                ),
              const SizedBox(height: AppSpacing.md),

              // ----- Analyze vs last -----
              PrimaryButton(
                label: 'Analyze vs last check-in',
                icon: Icons.auto_awesome_rounded,
                style: 'tonal',
                expand: true,
                onPressed: _photos.length >= 2 ? _analyze : null,
              ),
              if (_photos.length < 2) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Capture at least two check-ins to compare.',
                    style: AppType.body(12, color: AppColors.sageGrey)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StreaksRow extends StatelessWidget {
  const _StreaksRow({required this.app, required this.photoCount});
  final AppState app;
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: Future.wait([app.trainingStreak(), app.proteinStreak()]),
      builder: (context, snap) {
        final training = snap.hasData ? '${snap.data![0]}' : '—';
        final protein = snap.hasData ? '${snap.data![1]}' : '—';
        return StatRow(blocks: [
          StatBlock(value: training, label: 'Train streak', accent: AppColors.clay),
          StatBlock(value: protein, label: 'Protein streak', accent: AppColors.sage),
          StatBlock(value: '$photoCount', label: 'Check-ins'),
        ]);
      },
    );
  }
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.weights});
  final List<WeightEntry> weights;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < weights.length; i++) FlSpot(i.toDouble(), weights[i].weight),
    ];

    final values = weights.map((w) => w.weight).toList()..add(Seed.phaseGoalWeight);
    final minY = (values.reduce((a, b) => a < b ? a : b)) - 3;
    final maxY = (values.reduce((a, b) => a > b ? a : b)) + 3;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (weights.length - 1).clamp(0, double.infinity).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 4).clamp(1, double.infinity).toDouble(),
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.hairline, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                value.round().toString(),
                style: AppType.body(10, color: AppColors.sageGrey, weight: FontWeight.w600),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: Seed.phaseGoalWeight,
              color: AppColors.clay,
              strokeWidth: 1.5,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: AppType.body(10, color: AppColors.clay, weight: FontWeight.w700),
                labelResolver: (_) => 'Phase 1 goal',
              ),
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.clay,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: AppColors.clay,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.clay.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.onTap,
    required this.onLongPress,
  });
  final List<CheckinPhoto> photos;
  final void Function(CheckinPhoto) onTap;
  final void Function(CheckinPhoto) onLongPress;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, i) {
        final photo = photos[i];
        return GestureDetector(
          onTap: () => onTap(photo),
          onLongPress: () => onLongPress(photo),
          child: Image.file(File(photo.path), fit: BoxFit.cover),
        );
      },
    );
  }
}
