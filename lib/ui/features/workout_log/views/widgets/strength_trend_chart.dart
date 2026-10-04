import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:workout_tracker/ui/core/theme/app_colors.dart';

enum ChartMetricType {
  estimated1RM('Est. 1RM', 'kg'),
  maxWeight('Max Weight', 'kg'),
  totalVolume('Total Volume', 'kg'),
  maxReps('Max Reps', 'reps');

  final String label;
  final String unit;
  const ChartMetricType(this.label, this.unit);
}

class StrengthChartPoint {
  final DateTime date;
  final double score;
  final int totalSets;
  final int totalReps;
  final double maxWeight;
  final double totalVolume;
  final int maxReps;

  const StrengthChartPoint({
    required this.date,
    required this.score,
    required this.totalSets,
    required this.totalReps,
    this.maxWeight = 0.0,
    this.totalVolume = 0.0,
    this.maxReps = 0,
  });

  double valueForMetric(ChartMetricType metric) {
    switch (metric) {
      case ChartMetricType.estimated1RM:
        return score;
      case ChartMetricType.maxWeight:
        return maxWeight;
      case ChartMetricType.totalVolume:
        return totalVolume;
      case ChartMetricType.maxReps:
        return maxReps.toDouble();
    }
  }
}

class StrengthTrendChart extends StatefulWidget {
  final List<StrengthChartPoint> points;
  final ChartMetricType metricType;

  const StrengthTrendChart({
    required this.points,
    this.metricType = ChartMetricType.estimated1RM,
    super.key,
  });

  @override
  State<StrengthTrendChart> createState() => _StrengthTrendChartState();
}

class _StrengthTrendChartState extends State<StrengthTrendChart> with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late AnimationController _animController;
  late Animation<double> _animation;

  List<String> _formattedDates = [];
  double _minVal = 0.0;
  double _maxVal = 0.0;

  void _precomputeMetrics() {
    if (widget.points.isEmpty) {
      _formattedDates = [];
      _minVal = 0.0;
      _maxVal = 0.0;
      return;
    }
    _formattedDates = widget.points.map((p) =>
      '${p.date.month.toString().padLeft(2, '0')}/${p.date.day.toString().padLeft(2, '0')}'
    ).toList();

    double minV = widget.points.first.valueForMetric(widget.metricType);
    double maxV = minV;
    for (int i = 1; i < widget.points.length; i++) {
      final v = widget.points[i].valueForMetric(widget.metricType);
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }

    if (minV == maxV) {
      _minVal = max(0, minV - 5.0);
      _maxVal = maxV + 5.0;
    } else {
      final padding = (maxV - minV) * 0.15;
      _minVal = max(0, minV - padding);
      _maxVal = maxV + padding;
    }
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _animation = CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic);
    _animController.forward();

    _precomputeMetrics();
    if (widget.points.isNotEmpty) {
      _selectedIndex = widget.points.length - 1; // Default to latest point
    }
  }

  @override
  void didUpdateWidget(StrengthTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points || oldWidget.metricType != widget.metricType) {
      _precomputeMetrics();
    }
    if (widget.points.isNotEmpty) {
      _selectedIndex = widget.points.length - 1;
    } else {
      _selectedIndex = null;
    }
    if (oldWidget.metricType != widget.metricType ||
        oldWidget.points.length != widget.points.length) {
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedPoint = _selectedIndex != null && _selectedIndex! < widget.points.length
        ? widget.points[_selectedIndex!]
        : widget.points.last;

    final selectedValue = selectedPoint.valueForMetric(widget.metricType);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Selected point summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.metricType.label} Trend Curve',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(selectedPoint.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${selectedValue.toStringAsFixed(1)} ${widget.metricType.unit}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Details bar for selected point
          Row(
            children: [
              _buildMiniStat('Sets', '${selectedPoint.totalSets}', isDark),
              const SizedBox(width: 16),
              _buildMiniStat('Total Reps', '${selectedPoint.totalReps}', isDark),
              if (selectedPoint.maxWeight > 0) ...[
                const SizedBox(width: 16),
                _buildMiniStat('Max Wt', '${selectedPoint.maxWeight} kg', isDark),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Horizontally Scrollable Custom Line Chart with drag scrubbing and animated draw-in
          LayoutBuilder(
            builder: (context, constraints) {
              const double minPointWidth = 65.0;
              final double chartWidth = max(constraints.maxWidth, widget.points.length * minPointWidth);

              return Semantics(
                label: 'Strength trend curve showing ${widget.points.length} data points for ${widget.metricType.label}. Current selected value: ${selectedValue.toStringAsFixed(1)} ${widget.metricType.unit}.',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    height: 180,
                    width: chartWidth,
                    child: GestureDetector(
                      onTapUp: (details) => _handleTouch(details.localPosition, chartWidth),
                      onHorizontalDragDown: (details) => _handleTouch(details.localPosition, chartWidth),
                      onHorizontalDragUpdate: (details) => _handleTouch(details.localPosition, chartWidth),
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return RepaintBoundary(
                            child: CustomPaint(
                              painter: _TrendChartPainter(
                                points: widget.points,
                                selectedIndex: _selectedIndex,
                                progress: _animation.value,
                                metricType: widget.metricType,
                                isDark: isDark,
                                formattedDates: _formattedDates,
                                minVal: _minVal,
                                maxVal: _maxVal,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleTouch(Offset localPosition, double chartWidth) {
    final pointIndex = _resolveNearestPointIndex(localPosition, chartWidth);
    if (pointIndex != null && pointIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = pointIndex;
      });
    }
  }

  Widget _buildMiniStat(String label, String val, bool isDark) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : AppColors.textSecondary),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  int? _resolveNearestPointIndex(Offset offset, double width) {
    if (widget.points.isEmpty) return null;
    if (widget.points.length == 1) return 0;

    const double leftMargin = 30.0;
    const double rightMargin = 20.0;
    final double chartWidth = width - leftMargin - rightMargin;

    final double clampedX = max(leftMargin, min(width - rightMargin, offset.dx));
    final double step = chartWidth / (widget.points.length - 1);
    final int index = ((clampedX - leftMargin) / step).round();

    return max(0, min(widget.points.length - 1, index));
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<StrengthChartPoint> points;
  final int? selectedIndex;
  final double progress;
  final ChartMetricType metricType;
  final bool isDark;
  final List<String> formattedDates;
  final double minVal;
  final double maxVal;

  _TrendChartPainter({
    required this.points,
    required this.selectedIndex,
    required this.progress,
    required this.metricType,
    required this.isDark,
    required this.formattedDates,
    required this.minVal,
    required this.maxVal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const double topMargin = 20.0;
    const double bottomMargin = 35.0;
    const double leftMargin = 30.0;
    const double rightMargin = 20.0;

    final double plotWidth = size.width - leftMargin - rightMargin;
    final double plotHeight = size.height - topMargin - bottomMargin;
    final double valRange = maxVal > minVal ? maxVal - minVal : 1.0;

    // Compute coordinate points
    final List<Offset> coordPoints = [];
    final double stepX = points.length == 1 ? 0 : plotWidth / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final double x = points.length == 1 ? leftMargin + plotWidth / 2 : leftMargin + (i * stepX);
      final double val = points[i].valueForMetric(metricType);
      final double normalizedY = (val - minVal) / valRange;
      final double targetY = topMargin + (plotHeight * (1.0 - normalizedY));
      // Animate from baseline
      final double baselineY = topMargin + plotHeight;
      final double animatedY = baselineY - (baselineY - targetY) * progress;
      coordPoints.add(Offset(x, animatedY));
    }

    // Draw horizontal grid lines & Y labels
    final Paint gridPaint = Paint()
      ..color = isDark ? Colors.white12 : Colors.grey.shade200
      ..strokeWidth = 1.0;

    const int gridDivisions = 3;
    for (int i = 0; i <= gridDivisions; i++) {
      final double y = topMargin + (plotHeight / gridDivisions * i);
      canvas.drawLine(Offset(leftMargin, y), Offset(size.width - rightMargin, y), gridPaint);

      final double labelVal = maxVal - (valRange / gridDivisions * i);
      final textSpan = TextSpan(
        text: labelVal.toStringAsFixed(0),
        style: TextStyle(
          color: isDark ? Colors.white38 : AppColors.textSecondary.withValues(alpha: 0.6),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(2, y - 6));
    }

    if (coordPoints.isEmpty) return;

    // Draw Smooth Bézier Curve & Area Gradient Fill
    if (coordPoints.length > 1) {
      final Path linePath = Path()..moveTo(coordPoints.first.dx, coordPoints.first.dy);
      final Path fillPath = Path()..moveTo(coordPoints.first.dx, topMargin + plotHeight);
      fillPath.lineTo(coordPoints.first.dx, coordPoints.first.dy);

      for (int i = 0; i < coordPoints.length - 1; i++) {
        final p0 = coordPoints[i];
        final p1 = coordPoints[i + 1];
        final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
        final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);

        linePath.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
        fillPath.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
      }

      fillPath.lineTo(coordPoints.last.dx, topMargin + plotHeight);
      fillPath.close();

      // Area Gradient Fill
      final Paint fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.25 * progress),
            AppColors.primary.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(leftMargin, topMargin, plotWidth, plotHeight))
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      // Line Stroke
      final Paint linePaint = Paint()
        ..color = AppColors.primary
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(linePath, linePaint);
    }

    // Draw Node Points and Selected Highlight
    final Paint nodeFillPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : Colors.white
      ..style = PaintingStyle.fill;

    final Paint nodeBorderPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < coordPoints.length; i++) {
      final p = coordPoints[i];
      final isSelected = selectedIndex == i;

      // Draw Selected Vertical Guide Line
      if (isSelected) {
        final Paint guidePaint = Paint()
          ..color = AppColors.primary.withValues(alpha: 0.4)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(p.dx, topMargin), Offset(p.dx, topMargin + plotHeight), guidePaint);

        // Halo circle around selected node
        final Paint haloPaint = Paint()
          ..color = AppColors.primary.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p, 10.0, haloPaint);
      }

      // Draw node circle
      canvas.drawCircle(p, isSelected ? 6.0 : 4.0, nodeFillPaint);
      canvas.drawCircle(p, isSelected ? 6.0 : 4.0, nodeBorderPaint);

      // Draw X-axis date labels using pre-formatted date strings
      final dateText = formattedDates.length > i ? formattedDates[i] : '';
      final textSpan = TextSpan(
        text: dateText,
        style: TextStyle(
          color: isSelected
              ? AppColors.primary
              : (isDark ? Colors.white54 : AppColors.textSecondary),
          fontSize: 10,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(p.dx - (textPainter.width / 2), size.height - bottomMargin + 10));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.progress != progress ||
        oldDelegate.metricType != metricType ||
        oldDelegate.isDark != isDark;
  }
}
