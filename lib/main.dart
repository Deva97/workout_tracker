import 'package:flutter/material.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/core/theme/theme_controller.dart';
import 'ui/features/auth/views/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.loadThemeMode();
  runApp(const GymTrackerApp());
}

class GymTrackerApp extends StatelessWidget {
  final ThemeController? themeController;

  const GymTrackerApp({super.key, this.themeController});

  @override
  Widget build(BuildContext context) {
    final controller = themeController ?? ThemeController.instance;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Gym Tracker',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: controller.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}