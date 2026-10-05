import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:workout_tracker/domain/models/weight_record.dart';
import 'package:workout_tracker/domain/models/weekly_weight_average.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';

enum WeightGraphMode {
  daily('Everyday Weight', 'Daily readings'),
  weeklyAverage('Weekly Average', '7-day mean');

  final String title;
  final String subtitle;
  const WeightGraphMode(this.title, this.subtitle);
}

class WeightChartDataPoint {
  final DateTime date;
  final double value;
  final String label;
  final String detailedLabel;

  const WeightChartDataPoint({
    required this.date,
    required this.value,
    required this.label,
    required this.detailedLabel,
  });
}

class WeightTrendChart extends StatefulWidget {
  final List<WeightRecord> dailyRecords;
  final List<WeeklyWeightAverage> weeklyAverages;
  final WeightGraphMode mode;

  const WeightTrendChart({
    required this.dailyRecords,
    required this.weeklyAverages,
    required this.mode,
    super.key,
  });

  @override
  State<WeightTrendChart> createState() => _WeightTrendChartState();
}

class _WeightTrendChartState extends State<WeightTrendChart> with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late AnimationController _animController;
  late Animation<double> _animation;

  List<WeightChartDataPoint> _points = [];
  double _minVal = 0.0;
  double _maxVal = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _updatePoints();
    _animController.forward();
  }

  @override
  void didUpdateWidget(WeightTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.dailyRecords.length != widget.dailyRecords.length ||
        oldWidget.weeklyAverages.length != widget.weeklyAverages.length) {
      _updatePoints();
      _selectedIndex = null;
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _updatePoints() {
    if (widget.mode == WeightGraphMode.daily) {
      _points = widget.dailyRecords.map((r) {
        return WeightChartDataPoint(
          date: r.date,
          value: r.weight,
          label: DateFormat('M/d').format(r.date),
          detailedLabel: DateFormat('EEE, MMM d, yyyy').format(r.date),
        );
      }).toList();
    } else {
      _points = widget.weeklyAverages.map((w) {
        return WeightChartDataPoint(
          date: w.weekStart,
          value: w.averageWeight,
          label: w.shortLabel,
          detailedLabel: 'Week: ${w.formattedRange} (${w.entryCount} days)',
        );
      }).toList();
    }

    if (_points.isEmpty) {
      _minVal = 0.0;
      _maxVal = 0.0;
      return;
    }

    double minV = double.infinity;
    double maxV = -double.infinity;
    for (final p in _points) {
      if (p.value < minV) minV = p.value;
      if (p.value > maxV) maxV = p.value;
    }

    // Add visual breathing room
    final diff = maxV - minV;
    final padding = diff < 2.0 ? 1.5 : diff * 0.15;
    _minVal = max(0.0, minV - padding);
    _maxVal = maxV + padding;
  }

  void _handleTouch(Offset localPosition, double chartWidth) {
    if (_points.isEmpty || chartWidth <= 0) return;
    const leftPad = 48.0;
    const rightPad = 16.0;
    final usableWidth = chartWidth - leftPad - rightPad;
    if (usableWidth <= 0) return;

    final touchX = (localPosition.dx - leftPad).clamp(0.0, usableWidth);
    final ratio = touchX / usableWidth;

    if (_points.length == 1) {
      setState(() => _selectedIndex = 0);
      return;
    }

    final index = (ratio * (_points.length - 1)).round().clamp(0, _points.length - 1);
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_points.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monitor_weight_outlined, size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 8),
            Text(
              widget.mode == WeightGraphMode.daily
                  ? 'No weight records logged yet'
                  : 'No weekly average data available',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Photograph your scale to record today’s weight',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final selectedPoint = _selectedIndex != null && _selectedIndex! < _points.length
        ? _points[_selectedIndex!]
        : _points.last;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header preview of highlighted point
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedPoint.detailedLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${selectedPoint.value.toStringAsFixed(1)} ',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const Text(
                        'kg',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.mode.title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom Painted Interactive Chart
          LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onPanDown: (details) => _handleTouch(details.localPosition, constraints.maxWidth),
                onPanUpdate: (details) => _handleTouch(details.localPosition, constraints.maxWidth),
                onPanEnd: (_) {},
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(constraints.maxWidth, 180),
                      painter: _WeightChartPainter(
                        points: _points,
                        minVal: _minVal,
                        maxVal: _maxVal,
                        progress: _animation.value,
                        selectedIndex: _selectedIndex,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  final List<WeightChartDataPoint> points;
  final double minVal;
  final double maxVal;
  final double progress;
  final int? selectedIndex;
  final bool isDark;

  _WeightChartPainter({
    required this.points,
    required this.minVal,
    required this.maxVal,
    required this.progress,
    required this.selectedIndex,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 44.0;
    const rightPad = 14.0;
    const topPad = 12.0;
    const bottomPad = 26.0;

    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    if (points.isEmpty || chartWidth <= 0 || chartHeight <= 0) return;

    final range = (maxVal - minVal).abs();
    final effectiveRange = range == 0 ? 1.0 : range;

    // Draw Gridlines and Y-axis labels
    final gridPaint = Paint()
      ..color = (isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight).withValues(alpha: 0.5)
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    const gridLinesCount = 3;
    for (int i = 0; i <= gridLinesCount; i++) {
      final yRatio = i / gridLinesCount;
      final y = topPad + chartHeight * (1.0 - yRatio);
      final val = minVal + effectiveRange * yRatio;

      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);

      final textSpan = TextSpan(text: '${val.toStringAsFixed(1)}kg', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(leftPad - textPainter.width - 6, y - textPainter.height / 2));
    }

    // Compute point coordinates
    final List<Offset> offsets = [];
    for (int i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? leftPad + chartWidth / 2
          : leftPad + (i / (points.length - 1)) * chartWidth;

      final normalizedY = (points[i].value - minVal) / effectiveRange;
      final y = topPad + chartHeight * (1.0 - normalizedY * progress);
      offsets.add(Offset(x, y));
    }

    // Gradient Fill Under the Curve
    final fillPath = Path();
    fillPath.moveTo(offsets.first.dx, topPad + chartHeight);
    fillPath.lineTo(offsets.first.dx, offsets.first.dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      fillPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(offsets.last.dx, topPad + chartHeight);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.35),
          AppColors.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(leftPad, topPad, chartWidth, chartHeight));

    canvas.drawPath(fillPath, fillPaint);

    // Stroke Line
    final strokePath = Path();
    strokePath.moveTo(offsets.first.dx, offsets.first.dy);
    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      strokePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final strokePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(strokePath, strokePaint);

    // Data points & X-axis labels
    final pointPaint = Paint()..color = AppColors.primary;
    final innerPointPaint = Paint()..color = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    for (int i = 0; i < offsets.length; i++) {
      final offset = offsets[i];
      final isSelected = selectedIndex == i;

      // Draw point circle
      canvas.drawCircle(offset, isSelected ? 5.5 : 3.5, pointPaint);
      canvas.drawCircle(offset, isSelected ? 3.0 : 1.5, innerPointPaint);

      // Draw X-axis label for selective intervals
      final shouldDrawLabel = points.length <= 7 ||
          i == 0 ||
          i == points.length - 1 ||
          (points.length > 7 && i % (points.length ~/ 4) == 0);

      if (shouldDrawLabel) {
        final labelSpan = TextSpan(text: points[i].label, style: textStyle);
        final labelPainter = TextPainter(
          text: labelSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        final labelX = (offset.dx - labelPainter.width / 2).clamp(
          leftPad,
          size.width - rightPad - labelPainter.width,
        );
        labelPainter.paint(canvas, Offset(labelX, size.height - bottomPad + 6));
      }
    }

    // Touch Indicator Line
    if (selectedIndex != null && selectedIndex! < offsets.length) {
      final selectedOffset = offsets[selectedIndex!];
      final indicatorPaint = Paint()
        ..color = AppColors.primaryLight.withValues(alpha: 0.6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(selectedOffset.dx, topPad),
        Offset(selectedOffset.dx, topPad + chartHeight),
        indicatorPaint,
      );

      // Glow on selected point
      canvas.drawCircle(
        selectedOffset,
        8.0,
        Paint()..color = AppColors.primary.withValues(alpha: 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.points != points ||
        oldDelegate.isDark != isDark;
  }
}
