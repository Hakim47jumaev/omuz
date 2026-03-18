import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Courses'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => context.go('/course'),
          ),
          ListTile(
            title: const Text('Quizzes'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => context.go('/quiz'),
          ),
        ],
      ),
    );
  }
}
