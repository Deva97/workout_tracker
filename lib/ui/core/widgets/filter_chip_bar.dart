import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FilterChipBar extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  const FilterChipBar({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;
          final color = category == 'All'
              ? AppColors.primary
              : AppColors.getMuscleColor(category);

          return FilterChip(
            selected: isSelected,
            label: Text(category),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.textLight : AppColors.textPrimary),
            ),
            backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
            selectedColor: color,
            checkmarkColor: Colors.white,
            side: BorderSide(
              color: isSelected
                  ? color
                  : (isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight),
              width: 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            onSelected: (_) => onSelected(category),
          );
        },
      ),
    );
  }
}
