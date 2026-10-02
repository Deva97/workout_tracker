import 'package:flutter/material.dart';
import 'package:workout_tracker/ui/core/theme/app_colors.dart';

class AddExerciseModal extends StatefulWidget {
  final List<String> bodyParts;
  final Function(String name, String bodyPart) onAdd;

  const AddExerciseModal({
    required this.bodyParts,
    required this.onAdd,
    super.key,
  });

  @override
  State<AddExerciseModal> createState() => _AddExerciseModalState();
}

class _AddExerciseModalState extends State<AddExerciseModal> {
  final TextEditingController _nameController = TextEditingController();
  late String _selectedBodyPart;

  @override
  void initState() {
    super.initState();
    _selectedBodyPart = widget.bodyParts.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an exercise name')),
      );
      return;
    }
    widget.onAdd(name, _selectedBodyPart);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add New Exercise',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: isDark ? AppColors.textLight : AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 16),
          const SizedBox(height: 8),

          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Exercise Name',
              hintText: 'e.g. Incline Dumbbell Press',
              prefixIcon: Icon(Icons.fitness_center_rounded, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            initialValue: _selectedBodyPart,
            decoration: const InputDecoration(
              labelText: 'Target Body Part',
              prefixIcon: Icon(Icons.accessibility_new_rounded, color: AppColors.primary),
            ),
            items: widget.bodyParts.map((bodyPart) {
              return DropdownMenuItem(
                value: bodyPart,
                child: Text(bodyPart, style: const TextStyle(fontWeight: FontWeight.w600)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedBodyPart = value);
              }
            },
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Add Exercise', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
