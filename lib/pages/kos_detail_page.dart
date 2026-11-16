import 'package:flutter/material.dart';

class KosDetailPage extends StatelessWidget {
  const KosDetailPage({super.key, required this.kosId});
  final String kosId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Kos')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.home_work, size: 64, color: Colors.indigo),
              const SizedBox(height: 16),
              const Text(
                'Dibuka dari Push Notification!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Target Kos ID: $kosId'),
            ],
          ),
        ),
      ),
    );
  }
}
