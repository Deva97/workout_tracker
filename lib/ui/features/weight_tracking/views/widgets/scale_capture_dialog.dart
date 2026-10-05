import 'package:flutter/material.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';

class ScaleCaptureDialog extends StatefulWidget {
  final double initialWeight;

  const ScaleCaptureDialog({
    required this.initialWeight,
    super.key,
  });

  @override
  State<ScaleCaptureDialog> createState() => _ScaleCaptureDialogState();
}

class _ScaleCaptureDialogState extends State<ScaleCaptureDialog> {
  late double _currentWeight;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _currentWeight = widget.initialWeight;
    _controller = TextEditingController(text: _currentWeight.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _adjustWeight(double delta) {
    setState(() {
      _currentWeight = double.parse((_currentWeight + delta).clamp(0.5, 300.0).toStringAsFixed(1));
      _controller.text = _currentWeight.toStringAsFixed(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Scale Reading Verified',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'The number below was recognized from your weighing machine display. Confirm or fine-tune:',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Central Weight Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceLightElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.primary, size: 28),
                  onPressed: () => _adjustWeight(-0.1),
                ),
                const SizedBox(width: 8),
                IntrinsicWidth(
                  child: TextField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (text) {
                      final val = double.tryParse(text);
                      if (val != null) {
                        _currentWeight = val;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'kg',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 28),
                  onPressed: () => _adjustWeight(0.1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Quick adjustments row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ActionChip(
                label: const Text('-0.5'),
                onPressed: () => _adjustWeight(-0.5),
              ),
              const SizedBox(width: 8),
              ActionChip(
                label: const Text('+0.5'),
                onPressed: () => _adjustWeight(0.5),
              ),
              const SizedBox(width: 8),
              ActionChip(
                label: const Text('+1.0'),
                onPressed: () => _adjustWeight(1.0),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '🔒 Scale photo permanently deleted for privacy',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontStyle: FontStyle.italic),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Retake Photo'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _currentWeight),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Confirm & Log'),
        ),
      ],
    );
  }
}
