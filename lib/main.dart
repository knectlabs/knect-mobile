import 'package:flutter/material.dart';

void main() => runApp(const KerjancokApp());

class KerjancokApp extends StatelessWidget {
  const KerjancokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kerjancok',
      home: Scaffold(
        appBar: AppBar(title: const Text('Kerjancok')),
        body: const Center(child: Text('Employee app bootstrap')),
      ),
    );
  }
}
