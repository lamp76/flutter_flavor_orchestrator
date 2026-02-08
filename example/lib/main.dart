import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

/// Example Flutter app demonstrating flavor orchestrator usage.
class MyApp extends StatelessWidget {
  /// Creates the app widget.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Flavor Orchestrator Example',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const MyHomePage(title: 'Flavor Orchestrator Demo'),
      );
}

/// Home page widget.
class MyHomePage extends StatelessWidget {
  /// Creates the home page.
  const MyHomePage({required this.title, super.key});

  /// The title displayed in the app bar.
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(title),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.settings_applications,
                  size: 100,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Flutter Flavor Orchestrator',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This is an example app demonstrating flavor management.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                _buildInfoCard(
                  'Current Flavor',
                  'Check your native files to see which flavor is active',
                  Icons.info_outline,
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  'Next Steps',
                  'Run flutter_flavor_orchestrator commands to switch flavors',
                  Icons.arrow_forward,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildInfoCard(String title, String description, IconData icon) =>
      Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Colors.deepPurple),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
