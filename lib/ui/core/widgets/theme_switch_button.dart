import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';

/// A button that switches between light and dark themes.
///
/// Typically placed in the top right actions of the [AppBar] on the landing page.
class ThemeSwitchButton extends StatelessWidget {
  final ThemeController? controller;

  const ThemeSwitchButton({
    super.key,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final themeController = controller ?? ThemeController.instance;

    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        final isDark = themeController.isDark(context);

        return IconButton(
          key: const Key('theme_switch_button'),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return RotationTransition(
                turns: animation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey<bool>(isDark),
            ),
          ),
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: () => themeController.toggleTheme(context),
        );
      },
    );
  }
}
