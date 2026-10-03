import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/data/services/local_storage_service.dart';
import 'package:workout_tracker/main.dart';
import 'package:workout_tracker/ui/core/theme/app_theme.dart';
import 'package:workout_tracker/ui/core/theme/theme_controller.dart';
import 'package:workout_tracker/ui/core/widgets/theme_switch_button.dart';
import 'package:workout_tracker/ui/features/home/views/home_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeController.instance.reset();
  });

  group('ThemeController Unit Tests', () {
    test('default themeMode is system', () {
      final controller = ThemeController();
      expect(controller.themeMode, ThemeMode.system);
    });

    test('setThemeMode updates themeMode and notifies listeners', () async {
      final controller = ThemeController();
      var notificationCount = 0;
      controller.addListener(() {
        notificationCount++;
      });

      await controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, ThemeMode.dark);
      expect(notificationCount, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocalStorageService.keyThemeMode), 'dark');
    });

    test('loadThemeMode restores saved theme from storage', () async {
      SharedPreferences.setMockInitialValues({
        LocalStorageService.keyThemeMode: 'dark',
      });

      final controller = ThemeController();
      await controller.loadThemeMode();
      expect(controller.themeMode, ThemeMode.dark);

      SharedPreferences.setMockInitialValues({
        LocalStorageService.keyThemeMode: 'light',
      });
      await controller.loadThemeMode();
      expect(controller.themeMode, ThemeMode.light);
    });

    test('toggleTheme alternates between dark and light mode', () async {
      final controller = ThemeController();
      // Initially system, toggles to dark if not currently dark
      await controller.toggleTheme();
      expect(controller.themeMode, ThemeMode.dark);

      // Toggling again switches from dark to light
      await controller.toggleTheme();
      expect(controller.themeMode, ThemeMode.light);

      // Toggling again switches from light to dark
      await controller.toggleTheme();
      expect(controller.themeMode, ThemeMode.dark);
    });
  });

  group('ThemeSwitchButton Widget Tests', () {
    testWidgets('shows dark_mode icon and correct tooltip when in light mode', (tester) async {
      final controller = ThemeController();
      await controller.setThemeMode(ThemeMode.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: Scaffold(
            appBar: AppBar(
              actions: [
                ThemeSwitchButton(controller: controller),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('theme_switch_button')), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
      expect(find.byTooltip('Switch to dark mode'), findsOneWidget);
    });

    testWidgets('shows light_mode icon and correct tooltip when in dark mode', (tester) async {
      final controller = ThemeController();
      await controller.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Scaffold(
            appBar: AppBar(
              actions: [
                ThemeSwitchButton(controller: controller),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('theme_switch_button')), findsOneWidget);
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
      expect(find.byTooltip('Switch to light mode'), findsOneWidget);
    });

    testWidgets('tapping button toggles theme from light to dark and vice-versa', (tester) async {
      final controller = ThemeController();
      await controller.setThemeMode(ThemeMode.light);

      await tester.pumpWidget(
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: controller.themeMode,
            home: Scaffold(
              appBar: AppBar(
                actions: [
                  ThemeSwitchButton(controller: controller),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);

      // Tap to switch to dark mode
      await tester.tap(find.byKey(const Key('theme_switch_button')));
      await tester.pumpAndSettle();

      expect(controller.themeMode, ThemeMode.dark);
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
      expect(find.byTooltip('Switch to light mode'), findsOneWidget);

      // Tap to switch to light mode
      await tester.tap(find.byKey(const Key('theme_switch_button')));
      await tester.pumpAndSettle();

      expect(controller.themeMode, ThemeMode.light);
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
      expect(find.byTooltip('Switch to dark mode'), findsOneWidget);
    });
  });

  group('HomeScreen Landing Page Theme Switch Button Tests', () {
    testWidgets('main landing page has theme switch button in top right corner of AppBar', (tester) async {
      final controller = ThemeController();
      await controller.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: HomeScreen(themeController: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Theme switch button exists in the AppBar
      final buttonFinder = find.byKey(const Key('theme_switch_button'));
      expect(buttonFinder, findsOneWidget);

      // Check position is at the top right area
      final buttonTopRight = tester.getTopRight(buttonFinder);
      final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(buttonTopRight.dx, greaterThan(screenWidth - 70));
      expect(buttonTopRight.dy, lessThan(100)); // Within the AppBar area
    });

    testWidgets('tapping theme switch button on HomeScreen switches theme from dark to light', (tester) async {
      final controller = ThemeController();
      await controller.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: controller.themeMode,
            home: HomeScreen(themeController: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In dark mode initially: displays light_mode icon to switch to light mode
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

      // Tap the theme switch button
      await tester.tap(find.byKey(const Key('theme_switch_button')));
      await tester.pumpAndSettle();

      // Controller should now be light mode
      expect(controller.themeMode, ThemeMode.light);
      // Now displays dark_mode icon to switch to dark mode
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);

      // Verify preference was saved in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });
  });

  group('GymTrackerApp Theme Integration Tests', () {
    testWidgets('GymTrackerApp updates MaterialApp themeMode when ThemeController changes', (tester) async {
      final controller = ThemeController();
      await controller.setThemeMode(ThemeMode.light);

      await tester.pumpWidget(GymTrackerApp(themeController: controller));
      await tester.pump();

      var materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.light);

      await controller.setThemeMode(ThemeMode.dark);
      await tester.pump();

      materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.dark);
    });
  });
}
