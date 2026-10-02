import 'package:flutter/material.dart';
import 'package:workout_tracker/ui/core/widgets/empty_state_widget.dart';

class PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderPage({
    required this.title,
    required this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: EmptyStateWidget(
          icon: icon,
          title: '$title Module',
          description: 'This feature module is under active development. Stay tuned for upcoming updates!',
          buttonText: 'Back to Home',
          onButtonPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

