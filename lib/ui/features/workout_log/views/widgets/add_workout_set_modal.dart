import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:workout_tracker/domain/models/daily_record.dart';
import 'package:workout_tracker/domain/models/exercise.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';
import 'package:workout_tracker/ui/core/widgets/status_badge.dart';

class AddWorkoutSetModal extends StatefulWidget {
  final List<Exercise> availableExercises;
  final Exercise? initialExercise;
  final int initialSetNumber;
  final Function(DailyRecord record, bool keepOpen) onSaveSet;
  final DailyRecord? editRecord;
  final DailyRecord? previousRecord;
  final DailyRecord? Function(String exerciseGuid)? getPreviousRecord;
  final DateTime? targetDate;

  const AddWorkoutSetModal({
    required this.availableExercises,
    required this.onSaveSet,
    this.initialExercise,
    this.initialSetNumber = 1,
    this.editRecord,
    this.previousRecord,
    this.getPreviousRecord,
    this.targetDate,
    super.key,
  });

  @override
  State<AddWorkoutSetModal> createState() => _AddWorkoutSetModalState();
}

class _AddWorkoutSetModalState extends State<AddWorkoutSetModal> {
  final _formKey = GlobalKey<FormState>();

  Exercise? _selectedExercise;
  DailyRecord? _activePreviousRecord;
  late TextEditingController _setController;
  late TextEditingController _repsController;
  late TextEditingController _weightController;
  late TextEditingController _notesController;
  String _executionType = 'bilateral'; // 'bilateral', 'unilateral-left', 'unilateral-right'
  double _rirValue = 2.0;

  @override
  void initState() {
    super.initState();
    if (widget.editRecord != null) {
      final record = widget.editRecord!;
      _selectedExercise = widget.availableExercises.firstWhere(
        (e) => e.guid == record.workoutId,
        orElse: () => widget.initialExercise ?? widget.availableExercises.first,
      );
      _setController = TextEditingController(text: record.set.toString());
      _repsController = TextEditingController(text: record.reps.toString());
      _weightController = TextEditingController(text: record.weight.toString());
      _notesController = TextEditingController(text: record.notes);
      _executionType = record.executionType;
      _rirValue = record.rir;
    } else {
      _selectedExercise = widget.initialExercise ??
          (widget.availableExercises.isNotEmpty ? widget.availableExercises.first : null);
      _setController = TextEditingController(text: widget.initialSetNumber.toString());
      _notesController = TextEditingController();
      _activePreviousRecord = widget.previousRecord ??
          (_selectedExercise != null ? widget.getPreviousRecord?.call(_selectedExercise!.guid) : null);
      if (_activePreviousRecord != null) {
        _repsController = TextEditingController(text: _activePreviousRecord!.reps.toString());
        _weightController = TextEditingController(text: _activePreviousRecord!.weight.toString());
        _executionType = _activePreviousRecord!.executionType;
        _rirValue = _activePreviousRecord!.rir;
      } else {
        _repsController = TextEditingController(text: '10');
        _weightController = TextEditingController(text: '60.0');
        _executionType = 'bilateral';
        _rirValue = 2.0;
      }
    }
  }

  @override
  void dispose() {
    _setController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitForm({required bool keepOpen}) {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedExercise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an exercise.')),
      );
      return;
    }

    final setNumber = int.parse(_setController.text.trim());
    final reps = int.parse(_repsController.text.trim());
    final weight = double.parse(_weightController.text.trim());
    final rir = _rirValue;
    final notes = _notesController.text.trim();

    final record = DailyRecord(
      id: widget.editRecord?.id ?? const Uuid().v4(),
      workoutId: _selectedExercise!.guid,
      workoutName: _selectedExercise!.name,
      date: widget.editRecord?.date ?? widget.targetDate ?? DateTime.now(),
      set: setNumber,
      reps: reps,
      rir: rir,
      weight: weight,
      executionType: _executionType,
      notes: notes,
    );

    widget.onSaveSet(record, keepOpen);

    if (keepOpen) {
      setState(() {
        _setController.text = (setNumber + 1).toString();
        _activePreviousRecord = record;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Color _getRirColor(double rir, bool isDark) {
    if (rir <= 1.0) {
      return AppColors.error;
    } else if (rir <= 2.5) {
      return AppColors.primary;
    } else {
      return isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBgColor = isDark ? AppColors.surfaceDarkElevated : Colors.grey.shade50;
    final cardBorderColor = isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 14),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag pill
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            widget.editRecord != null
                                ? Icons.edit_note_rounded
                                : Icons.fitness_center_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.editRecord != null ? 'Edit Workout Set' : 'Add Workout Set',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: isDark ? AppColors.textLight : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Exercise Selector Card
                if (widget.editRecord != null && _selectedExercise != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cardBorderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedExercise!.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                        if (_selectedExercise!.bodyPart.isNotEmpty)
                          StatusBadge.tag(
                            label: _selectedExercise!.bodyPart.toUpperCase(),
                            color: AppColors.getMuscleColor(_selectedExercise!.bodyPart),
                          ),
                      ],
                    ),
                  )
                else if (widget.availableExercises.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'No exercises found. Please add exercises in Exercise Directory first.',
                      style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  )
                else
                  DropdownButtonFormField<Exercise>(
                    initialValue: _selectedExercise,
                    decoration: InputDecoration(
                      labelText: 'Exercise',
                      filled: true,
                      fillColor: cardBgColor,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      prefixIcon: const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: cardBorderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: cardBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    isExpanded: true,
                    items: widget.availableExercises.map((exercise) {
                      return DropdownMenuItem<Exercise>(
                        value: exercise,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                exercise.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            if (exercise.bodyPart.isNotEmpty)
                              StatusBadge.tag(
                                label: exercise.bodyPart.toUpperCase(),
                                color: AppColors.getMuscleColor(exercise.bodyPart),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    validator: (val) {
                      if (val == null) return 'Exercise is required';
                      return null;
                    },
                    onChanged: (val) {
                      setState(() {
                        _selectedExercise = val;
                        if (val != null) {
                          final prev = widget.getPreviousRecord?.call(val.guid);
                          if (prev != null) {
                            _activePreviousRecord = prev;
                            _weightController.text = prev.weight.toString();
                            _repsController.text = prev.reps.toString();
                            _executionType = prev.executionType;
                            _rirValue = prev.rir;
                          }
                        }
                      });
                    },
                  ),

                // Previous session memory banner
                if (_activePreviousRecord != null && widget.editRecord == null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.history_rounded, size: 15, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Last logged: Set ${_activePreviousRecord!.set} • ${_activePreviousRecord!.weight} kg × ${_activePreviousRecord!.reps} reps (RIR ${_activePreviousRecord!.rir.toStringAsFixed(1)})${_activePreviousRecord!.executionType != 'bilateral' ? ' • ${_activePreviousRecord!.executionType == 'unilateral-left' ? 'Left' : 'Right'}' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // Execution Laterality Selector
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Row(
                    children: [
                      _buildLateralityTab(
                        label: 'Bilateral',
                        value: 'bilateral',
                        icon: Icons.sync_alt_rounded,
                        isDark: isDark,
                      ),
                      _buildLateralityTab(
                        label: 'Left',
                        value: 'unilateral-left',
                        icon: Icons.west_rounded,
                        isDark: isDark,
                      ),
                      _buildLateralityTab(
                        label: 'Right',
                        value: 'unilateral-right',
                        icon: Icons.east_rounded,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Core Metrics: Set Number & Reps
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Set Number Card
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cardBorderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Set Number',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                              ),
                            ),
                            TextFormField(
                              controller: _setController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 2),
                                border: InputBorder.none,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Required';
                                final n = int.tryParse(val.trim());
                                if (n == null || n <= 0) return 'Must be > 0';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Reps with Steppers Card
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cardBorderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                'Reps',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: AppColors.primary),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    final current = int.tryParse(_repsController.text) ?? 10;
                                    if (current > 1) {
                                      _repsController.text = (current - 1).toString();
                                    }
                                  },
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _repsController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 2),
                                      border: InputBorder.none,
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Required';
                                      final n = int.tryParse(val.trim());
                                      if (n == null || n <= 0) return 'Must be > 0';
                                      return null;
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.primary),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    final current = int.tryParse(_repsController.text) ?? 10;
                                    _repsController.text = (current + 1).toString();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Weight Card with Steppers
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Weight (kg)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                            ),
                          ),
                          Row(
                            children: [
                              _buildWeightChip(label: '+1.25', delta: 1.25, isDark: isDark),
                              const SizedBox(width: 4),
                              _buildWeightChip(label: '+2.5', delta: 2.5, isDark: isDark),
                              const SizedBox(width: 4),
                              _buildWeightChip(label: '+5', delta: 5.0, isDark: isDark),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, size: 22, color: AppColors.primary),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              final current = double.tryParse(_weightController.text) ?? 60.0;
                              if (current >= 2.5) {
                                _weightController.text = (current - 2.5).toString();
                              }
                            },
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _weightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 2),
                                border: InputBorder.none,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Required';
                                final n = double.tryParse(val.trim());
                                if (n == null || n < 0.0) return 'Must be >= 0';
                                return null;
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 22, color: AppColors.primary),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              final current = double.tryParse(_weightController.text) ?? 60.0;
                              _weightController.text = (current + 2.5).toString();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // RIR Slider Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Reps in Reserve (RIR)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRirColor(_rirValue, isDark).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_rirValue.toStringAsFixed(1)} RIR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _getRirColor(_rirValue, isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: _getRirColor(_rirValue, isDark),
                          inactiveTrackColor: isDark ? Colors.white12 : Colors.grey.shade200,
                          thumbColor: _getRirColor(_rirValue, isDark),
                          overlayColor: _getRirColor(_rirValue, isDark).withValues(alpha: 0.15),
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: _rirValue,
                          min: 0.0,
                          max: 10.0,
                          divisions: 20,
                          label: _rirValue.toStringAsFixed(1),
                          onChanged: (val) {
                            setState(() {
                              _rirValue = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Notes / Plan Details Section
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 16,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Notes / Plan Details (Optional)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        minLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textLight : AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. Form cues, tempo 3-0-1, drop set on last rep...',
                          hintStyle: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white30 : Colors.grey.shade400,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          border: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Action Buttons Row
                Row(
                  children: [
                    if (widget.editRecord == null) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.availableExercises.isEmpty
                              ? null
                              : () => _submitForm(keepOpen: true),
                          icon: const Icon(Icons.playlist_add_rounded, size: 16),
                          label: const Text('Add & Next', style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.availableExercises.isEmpty
                            ? null
                            : () => _submitForm(keepOpen: false),
                        icon: Icon(
                          widget.editRecord != null ? Icons.update_rounded : Icons.check_circle_rounded,
                          size: 16,
                        ),
                        label: Text(
                          widget.editRecord != null ? 'Update Set' : 'Save Set',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLateralityTab({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _executionType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _executionType = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeightChip({
    required String label,
    required double delta,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        final current = double.tryParse(_weightController.text) ?? 60.0;
        _weightController.text = (current + delta).toString();
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textLight : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
